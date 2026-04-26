import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    let keychain = KeychainStore()
    let modelRegistry = ModelRegistry()
    let errorBus = ErrorBus()
    let projectStore = ProjectStore()
    let imageStore = ImageStore()
    let metadataStore = MetadataStore()
    let thumbnailStore = ThumbnailStore()
    let referenceStore = ReferenceStore()
    let chatLog = ChatLogStore()
    let autoUpdater: any AutoUpdater = NoOpAutoUpdater()

    @ObservationIgnored
    private lazy var generationOrchestrator = GenerationOrchestrator(
        imageStore: imageStore,
        metadataStore: metadataStore,
        thumbnailStore: thumbnailStore,
        referenceStore: referenceStore,
        keychain: keychain
    )

    @ObservationIgnored
    private lazy var chatOrchestrator = ChatOrchestrator(
        log: chatLog,
        keychain: keychain
    )

    var projects: [Project] = []
    var selectedProjectID: String?
    var assetsByProject: [String: [ImageAsset]] = [:]
    var chatMessages: [ChatMessage] = []
    var isChatBusy: Bool = false
    var pendingReferenceIDs: [String] = []
    var presentedAsset: ImageAsset?
    var selectedImageModel: ModelDescriptor?
    var selectedChatModel: ModelDescriptor?
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "geeksfield.onboarding.completed")

    private let lastImageProviderKey = "geeksfield.lastImage.provider"
    private let lastImageIDKey = "geeksfield.lastImage.id"
    private let lastChatProviderKey = "geeksfield.lastChat.provider"
    private let lastChatIDKey = "geeksfield.lastChat.id"

    var connectedProviders: Set<Provider> {
        var set: Set<Provider> = []
        for p in Provider.allCases {
            if let key = keychain.apiKey(for: p), !key.isEmpty {
                set.insert(p)
            }
        }
        return set
    }

    var selectedProjectAssets: [ImageAsset] {
        guard let id = selectedProjectID else { return [] }
        return assetsByProject[id] ?? []
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        reloadProjects()
        chatMessages = (try? chatLog.readAll()) ?? []
        autoUpdater.checkForUpdatesInBackground()
        await modelRegistry.refresh()
        restoreModelSelections()
    }

    /// Resolves the last-used model from UserDefaults. Falls back to the first
    /// model in each pool. Called after the registry refreshes.
    func restoreModelSelections() {
        let defaults = UserDefaults.standard
        if selectedImageModel == nil
            || !modelRegistry.imageModels.contains(where: { $0.id == selectedImageModel?.id }) {
            selectedImageModel = resolveStored(
                providerKey: lastImageProviderKey,
                idKey: lastImageIDKey,
                pool: modelRegistry.imageModels
            ) ?? modelRegistry.imageModels.first
        }
        if selectedChatModel == nil
            || !modelRegistry.chatModels.contains(where: { $0.id == selectedChatModel?.id }) {
            selectedChatModel = resolveStored(
                providerKey: lastChatProviderKey,
                idKey: lastChatIDKey,
                pool: modelRegistry.chatModels
            ) ?? modelRegistry.chatModels.first
        }
        _ = defaults
    }

    private func resolveStored(
        providerKey: String,
        idKey: String,
        pool: [ModelDescriptor]
    ) -> ModelDescriptor? {
        let defaults = UserDefaults.standard
        guard let providerRaw = defaults.string(forKey: providerKey),
              let provider = Provider(rawValue: providerRaw),
              let id = defaults.string(forKey: idKey) else { return nil }
        return pool.first { $0.id == id && $0.provider == provider }
    }

    func setImageModel(_ model: ModelDescriptor?) {
        selectedImageModel = model
        let defaults = UserDefaults.standard
        if let model {
            defaults.set(model.provider.rawValue, forKey: lastImageProviderKey)
            defaults.set(model.id, forKey: lastImageIDKey)
        } else {
            defaults.removeObject(forKey: lastImageProviderKey)
            defaults.removeObject(forKey: lastImageIDKey)
        }
    }

    func setChatModel(_ model: ModelDescriptor?) {
        selectedChatModel = model
        let defaults = UserDefaults.standard
        if let model {
            defaults.set(model.provider.rawValue, forKey: lastChatProviderKey)
            defaults.set(model.id, forKey: lastChatIDKey)
        } else {
            defaults.removeObject(forKey: lastChatProviderKey)
            defaults.removeObject(forKey: lastChatIDKey)
        }
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "geeksfield.onboarding.completed")
    }

    // MARK: - Projects

    func reloadProjects() {
        do {
            projects = try projectStore.listProjects()
            for p in projects {
                refreshAssets(for: p.id)
            }
            // Always keep a project selected when at least one exists.
            if let current = selectedProjectID,
               !projects.contains(where: { $0.id == current }) {
                selectedProjectID = nil
            }
            if selectedProjectID == nil, let first = projects.first {
                selectedProjectID = first.id
            }
        } catch {
            errorBus.report(error, title: "Failed to load projects")
        }
    }

    func createProject(name: String) {
        do {
            let project = try projectStore.createProject(name: name)
            projects.insert(project, at: 0)
            selectedProjectID = project.id
            refreshAssets(for: project.id)
        } catch {
            errorBus.report(error, title: "Failed to create project")
        }
    }

    // MARK: - Assets

    func refreshAssets(for projectID: String) {
        let metas = (try? metadataStore.list(projectID: projectID)) ?? []
        let fm = FileManager.default
        let assets: [ImageAsset] = metas.map { meta in
            let file = (try? imageStore.locate(projectID: projectID, imageID: meta.id)) ?? nil
            let thumbURL = thumbnailStore.thumbnailURL(projectID: projectID, imageID: meta.id)
            let thumb = fm.fileExists(atPath: thumbURL.path) ? thumbURL : nil
            return ImageAsset(metadata: meta, fileURL: file, thumbnailURL: thumb)
        }
        .sorted { $0.metadata.createdAt > $1.metadata.createdAt }
        assetsByProject[projectID] = assets
    }

    func deleteAsset(_ asset: ImageAsset) {
        let pid = asset.metadata.projectID
        do {
            if asset.fileURL == nil {
                // pending or failed placeholders have no file yet.
                try metadataStore.delete(projectID: pid, imageID: asset.id)
            } else {
                try imageStore.trash(projectID: pid, imageID: asset.id)
                try metadataStore.delete(projectID: pid, imageID: asset.id)
            }
            refreshAssets(for: pid)
        } catch {
            errorBus.report(error, title: "Failed to delete image")
        }
    }

    func setStatus(_ asset: ImageAsset, to status: ImageStatus) {
        guard status != .failed && status != .pending else { return }
        let pid = asset.metadata.projectID
        do {
            _ = try imageStore.move(projectID: pid, imageID: asset.id, to: status)
            if var meta = try? metadataStore.read(projectID: pid, imageID: asset.id) {
                meta.status = status
                try metadataStore.write(meta)
            }
            refreshAssets(for: pid)
        } catch {
            errorBus.report(error, title: "Failed to update status")
        }
    }

    // MARK: - Generation

    func generate(request: GenerationRequest) {
        let pid = request.projectID
        Task {
            do {
                try await generationOrchestrator.execute(request: request) { [weak self] in
                    self?.refreshAssets(for: pid)
                }
            } catch {
                errorBus.report(error, title: "이미지 생성 실패")
            }
        }
    }

    // MARK: - References

    func attachReference(imageID: String) {
        if !pendingReferenceIDs.contains(imageID) {
            pendingReferenceIDs.append(imageID)
        }
    }

    func attachExternalReference(url: URL) {
        guard let pid = selectedProjectID else { return }
        do {
            let refID = try referenceStore.ingestExternal(projectID: pid, sourceURL: url)
            pendingReferenceIDs.append(refID)
        } catch {
            errorBus.report(error, title: "레퍼런스 추가 실패")
        }
    }

    func removeReference(id: String) {
        pendingReferenceIDs.removeAll { $0 == id }
    }

    func clearReferences() {
        pendingReferenceIDs.removeAll()
    }

    func referenceThumbnailURL(for id: String) -> URL? {
        guard let pid = selectedProjectID else { return nil }
        if id.hasPrefix("ref_") {
            return referenceStore.url(projectID: pid, refID: id)
        }
        let thumb = thumbnailStore.thumbnailURL(projectID: pid, imageID: id)
        if FileManager.default.fileExists(atPath: thumb.path) {
            return thumb
        }
        return try? imageStore.locate(projectID: pid, imageID: id)
    }

    // MARK: - Inpaint

    func inpaint(
        asset: ImageAsset,
        prompt: String,
        model: ModelDescriptor,
        maskPNG: Data
    ) {
        guard let src = asset.fileURL,
              let originalPNG = try? Data(contentsOf: src) else {
            errorBus.report(title: "인페인트 실패", message: "원본 이미지를 읽을 수 없습니다.")
            return
        }
        let pid = asset.metadata.projectID
        let request = InpaintRequest(
            projectID: pid,
            sourceImageID: asset.id,
            maskPNGData: maskPNG,
            prompt: prompt,
            model: model,
            size: asset.metadata.size
        )
        Task {
            do {
                try await generationOrchestrator.executeInpaint(
                    request: request,
                    originalPNG: originalPNG,
                    maskPNG: maskPNG
                ) { [weak self] in
                    self?.refreshAssets(for: pid)
                }
            } catch {
                errorBus.report(error, title: "인페인트 실패")
            }
        }
    }

    // MARK: - Export

    func exportAsset(_ asset: ImageAsset) {
        guard let source = asset.fileURL else { return }
        Task {
            do {
                _ = try await ExportService.exportSingle(source: source)
            } catch ExportError.userCancelled {
                // ignore
            } catch {
                errorBus.report(error, title: "내보내기 실패")
            }
        }
    }

    func exportAssets(_ assets: [ImageAsset]) {
        let sources = assets.compactMap(\.fileURL)
        guard !sources.isEmpty else { return }
        Task {
            do {
                _ = try await ExportService.exportMany(sources: sources)
            } catch ExportError.userCancelled {
                // ignore
            } catch {
                errorBus.report(error, title: "내보내기 실패")
            }
        }
    }

    func exportSelectedProject() {
        guard let pid = selectedProjectID,
              let project = projects.first(where: { $0.id == pid }) else { return }
        let paths = AppPaths.shared
        Task {
            do {
                _ = try await ExportService.exportProject(
                    draftsDir: paths.draftsDir(pid),
                    pickedDir: paths.pickedDir(pid),
                    projectName: project.name
                )
            } catch ExportError.userCancelled {
                // ignore
            } catch {
                errorBus.report(error, title: "프로젝트 내보내기 실패")
            }
        }
    }

    // MARK: - Regenerate / use-as-reference

    func regenerate(_ asset: ImageAsset) {
        let meta = asset.metadata
        guard let model = modelRegistry.imageModels.first(where: { $0.id == meta.modelID && $0.provider == meta.provider })
                ?? modelRegistry.imageModels.first(where: { $0.provider == meta.provider }) else {
            errorBus.report(title: "다시 만들기 실패", message: "모델을 찾을 수 없습니다.")
            return
        }
        let request = GenerationRequest(
            projectID: meta.projectID,
            prompt: meta.prompt,
            negativePrompt: meta.negativePrompt,
            model: model,
            size: meta.size ?? .auto,
            aspectRatio: meta.aspectRatio,
            batchSize: 1,
            referenceIDs: meta.referenceIDs,
            seed: meta.seed
        )
        generate(request: request)
    }

    func useAsReference(_ asset: ImageAsset) {
        attachReference(imageID: asset.id)
    }

    // MARK: - Chat

    func sendChat(text: String, model: ModelDescriptor, attachments: [ChatAttachment] = []) {
        let userMessage = ChatMessage(
            id: UUID().uuidString.lowercased(),
            role: .user,
            content: text,
            createdAt: Date(),
            provider: model.provider,
            modelID: model.id,
            attachments: attachments
        )
        chatMessages.append(userMessage)
        isChatBusy = true

        let history = chatMessages.dropLast().filter { $0.role != .system }
        let historyArray = Array(history)

        Task {
            do {
                let reply = try await chatOrchestrator.send(
                    history: historyArray,
                    userMessage: userMessage,
                    model: model
                )
                chatMessages.append(reply)
            } catch {
                errorBus.report(error, title: "Chat failed")
            }
            isChatBusy = false
        }
    }
}
