import Foundation

private enum SlotGenerationResult: Sendable {
    case success(slot: Int, id: String, data: Data)
    case failure(slot: Int, id: String, reason: String)
}

/// Coordinates a batch image generation:
///   1. Writes N placeholder metadata entries (status .pending) so the UI can
///      show inflight tiles immediately.
///   2. Fires N parallel provider calls. Each success overwrites the placeholder
///      with a .draft entry + saved PNG + thumbnail; each failure leaves the
///      placeholder with a filled-in failureReason so the user can delete it.
///   3. Invokes `onUpdate` after each slot completes so the caller can refresh
///      its in-memory view.
@MainActor
final class GenerationOrchestrator {
    let providers: [Provider: any ImageProvider]
    let imageStore: ImageStore
    let metadataStore: MetadataStore
    let thumbnailStore: ThumbnailStore
    let referenceStore: ReferenceStore
    let keychain: KeychainStore
    let generationQueue: GenerationQueue

    init(
        providers: [Provider: any ImageProvider] = [
            .codex: CodexImageProvider()
        ],
        imageStore: ImageStore = ImageStore(),
        metadataStore: MetadataStore = MetadataStore(),
        thumbnailStore: ThumbnailStore = ThumbnailStore(),
        referenceStore: ReferenceStore = ReferenceStore(),
        keychain: KeychainStore = KeychainStore(),
        generationQueue: GenerationQueue = GenerationQueue()
    ) {
        self.providers = providers
        self.imageStore = imageStore
        self.metadataStore = metadataStore
        self.thumbnailStore = thumbnailStore
        self.referenceStore = referenceStore
        self.keychain = keychain
        self.generationQueue = generationQueue
    }

    private func resolveReferences(projectID: String, ids: [String]) -> [Data] {
        ids.compactMap { id in
            let url: URL?
            if id.hasPrefix("ref_") {
                url = referenceStore.url(projectID: projectID, refID: id)
            } else {
                url = (try? imageStore.locate(projectID: projectID, imageID: id)) ?? nil
            }
            guard let url else { return nil }
            return try? Data(contentsOf: url)
        }
    }

    func execute(
        request: GenerationRequest,
        onUpdate: @MainActor @Sendable @escaping () -> Void
    ) async throws {
        guard let provider = providers[request.model.provider] else {
            throw ImageProviderError.unsupportedOperation("No provider for \(request.model.provider)")
        }
        let apiKey = keychain.apiKey(for: request.model.provider) ?? ""
        if request.model.provider.usesAPIKey && apiKey.isEmpty {
            throw ImageProviderError.unsupportedOperation("Missing credentials for \(request.model.provider.displayName)")
        }

        // Placeholder metadata up front so tiles appear immediately. Status is
        // .pending so the UI knows to render a spinner and *not* a failure tile.
        let batchSize = max(1, request.batchSize)
        let slotIDs: [String] = (0..<batchSize).map { _ in
            UUID().uuidString.lowercased()
        }
        let runID = UUID().uuidString.lowercased()
        let now = Date()
        let operation: ImageOperation = request.parentImageID == nil && request.referenceIDs.isEmpty
            ? .generate
            : .reference
        for (slot, id) in slotIDs.enumerated() {
            let placeholder = ImageMetadata(
                id: id,
                projectID: request.projectID,
                status: .pending,
                createdAt: now,
                provider: request.model.provider,
                modelID: request.model.id,
                prompt: request.prompt,
                negativePrompt: request.negativePrompt,
                size: request.size.isAuto ? nil : request.size,
                aspectRatio: request.aspectRatio,
                seed: request.seed,
                referenceIDs: request.referenceIDs,
                runID: runID,
                parentImageID: request.parentImageID,
                variantIndex: slot + 1,
                operation: operation,
                failureReason: nil
            )
            try metadataStore.write(placeholder)
        }
        onUpdate()

        let refs = resolveReferences(projectID: request.projectID, ids: request.referenceIDs)
        let generationQueue = self.generationQueue
        func makeSlotRequest() -> GenerationRequest {
            GenerationRequest(
                projectID: request.projectID,
                prompt: request.prompt,
                negativePrompt: request.negativePrompt,
                model: request.model,
                size: request.size,
                aspectRatio: request.aspectRatio,
                batchSize: 1,
                referenceIDs: request.referenceIDs,
                parentImageID: request.parentImageID,
                seed: request.seed
            )
        }

        func apply(_ result: SlotGenerationResult) {
            switch result {
            case .success(_, let id, let data):
                do {
                    let fileURL = try imageStore.savePNG(
                        data: data,
                        projectID: request.projectID,
                        imageID: id,
                        status: .draft,
                        createdAt: now
                    )
                    _ = try? thumbnailStore.generate(
                        for: fileURL,
                        projectID: request.projectID,
                        imageID: id
                    )
                    if var meta = try? metadataStore.read(projectID: request.projectID, imageID: id) {
                        meta.status = .draft
                        meta.failureReason = nil
                        try? metadataStore.write(meta)
                    }
                } catch {
                    let reason = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                    markFailed(projectID: request.projectID, imageID: id, reason: reason)
                }
            case .failure(_, let id, let reason):
                markFailed(projectID: request.projectID, imageID: id, reason: reason)
            }
            onUpdate()
        }

        try await withThrowingTaskGroup(of: SlotGenerationResult.self) { group in
            for (slot, id) in slotIDs.enumerated() {
                let slotRequest = makeSlotRequest()
                group.addTask {
                    do {
                        let images = try await generationQueue.withPermit {
                            try await provider.generate(
                                request: slotRequest,
                                referenceImages: refs,
                                apiKey: apiKey
                            )
                        }
                        guard let image = images.first else {
                            return .failure(slot: slot, id: id, reason: "No image returned for slot \(slot + 1).")
                        }
                        return .success(slot: slot, id: id, data: image)
                    } catch {
                        let reason = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                        return .failure(slot: slot, id: id, reason: reason)
                    }
                }
            }

            for try await result in group {
                apply(result)
            }
        }
    }

    func retry(
        asset: ImageAsset,
        request: GenerationRequest,
        onUpdate: @MainActor @Sendable @escaping () -> Void
    ) async throws {
        guard let provider = providers[request.model.provider] else {
            throw ImageProviderError.unsupportedOperation("No provider for \(request.model.provider)")
        }
        let apiKey = keychain.apiKey(for: request.model.provider) ?? ""
        if request.model.provider.usesAPIKey && apiKey.isEmpty {
            throw ImageProviderError.unsupportedOperation("Missing credentials for \(request.model.provider.displayName)")
        }

        var pending = asset.metadata
        pending.status = .pending
        pending.failureReason = nil
        try metadataStore.write(pending)
        onUpdate()

        let slotRequest = GenerationRequest(
            projectID: request.projectID,
            prompt: request.prompt,
            negativePrompt: request.negativePrompt,
            model: request.model,
            size: request.size,
            aspectRatio: request.aspectRatio,
            batchSize: 1,
            referenceIDs: request.referenceIDs,
            parentImageID: request.parentImageID,
            seed: request.seed
        )
        let refs = resolveReferences(projectID: request.projectID, ids: request.referenceIDs)

        do {
            let images = try await provider.generate(
                request: slotRequest,
                referenceImages: refs,
                apiKey: apiKey
            )
            guard let image = images.first else {
                markFailed(
                    projectID: request.projectID,
                    imageID: asset.id,
                    reason: "No image returned for retry."
                )
                onUpdate()
                return
            }
            let fileURL = try imageStore.savePNG(
                data: image,
                projectID: request.projectID,
                imageID: asset.id,
                status: .draft
            )
            _ = try? thumbnailStore.generate(
                for: fileURL,
                projectID: request.projectID,
                imageID: asset.id
            )
            if var meta = try? metadataStore.read(projectID: request.projectID, imageID: asset.id) {
                meta.status = .draft
                meta.failureReason = nil
                try? metadataStore.write(meta)
            }
            onUpdate()
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            markFailed(projectID: request.projectID, imageID: asset.id, reason: reason)
            onUpdate()
        }
    }

    private func markFailed(projectID: String, imageID: String, reason: String) {
        if var meta = try? metadataStore.read(projectID: projectID, imageID: imageID) {
            meta.status = .failed
            meta.failureReason = reason
            try? metadataStore.write(meta)
        }
    }

    // MARK: - Inpaint

    func executeInpaint(
        request: InpaintRequest,
        originalPNG: Data,
        maskPNG: Data,
        onUpdate: @MainActor @Sendable @escaping () -> Void
    ) async throws {
        guard let provider = providers[request.model.provider] else {
            throw ImageProviderError.unsupportedOperation("No provider for \(request.model.provider)")
        }
        let apiKey = keychain.apiKey(for: request.model.provider) ?? ""
        if request.model.provider.usesAPIKey && apiKey.isEmpty {
            throw ImageProviderError.unsupportedOperation("Missing credentials for \(request.model.provider.displayName)")
        }

        let id = request.outputImageID
        let runID = UUID().uuidString.lowercased()
        let now = Date()
        let placeholder = ImageMetadata(
            id: id,
            projectID: request.projectID,
            status: .pending,
            createdAt: now,
            provider: request.model.provider,
            modelID: request.model.id,
            prompt: request.prompt,
            negativePrompt: nil,
            size: request.size,
            aspectRatio: nil,
            seed: nil,
            referenceIDs: [request.sourceImageID],
            runID: runID,
            parentImageID: request.sourceImageID,
            variantIndex: 1,
            operation: .inpaint,
            failureReason: nil
        )
        try metadataStore.write(placeholder)
        onUpdate()

        do {
            let image = try await generationQueue.withPermit {
                try await provider.edit(
                    request: request,
                    originalPNG: originalPNG,
                    maskPNG: maskPNG,
                    apiKey: apiKey
                )
            }
            let fileURL = try imageStore.savePNG(
                data: image,
                projectID: request.projectID,
                imageID: id,
                status: .draft,
                createdAt: now
            )
            _ = try? thumbnailStore.generate(
                for: fileURL,
                projectID: request.projectID,
                imageID: id
            )
            if var meta = try? metadataStore.read(projectID: request.projectID, imageID: id) {
                meta.status = .draft
                meta.failureReason = nil
                try? metadataStore.write(meta)
            }
            onUpdate()
        } catch {
            let reason = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            if var meta = try? metadataStore.read(projectID: request.projectID, imageID: id) {
                meta.status = .failed
                meta.failureReason = reason
                try? metadataStore.write(meta)
            }
            onUpdate()
            throw error
        }
    }
}
