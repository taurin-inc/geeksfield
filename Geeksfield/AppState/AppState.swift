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
    let autoUpdater: any AutoUpdater = SparkleAutoUpdater()

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
    var activeBaseImageID: String?
    var focusedInput: FocusedInput?
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "geeksfield.onboarding.completed")
    var language: Language = {
        let raw = UserDefaults.standard.string(forKey: "geeksfield.language") ?? Language.korean.rawValue
        return Language(rawValue: raw) ?? .korean
    }()

    var l10n: L10n { L10n(lang: language) }

    func setLanguage(_ language: Language) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: "geeksfield.language")
    }

    private let lastImageProviderKey = "geeksfield.lastImage.provider"
    private let lastImageIDKey = "geeksfield.lastImage.id"
    private let lastChatProviderKey = "geeksfield.lastChat.provider"
    private let lastChatIDKey = "geeksfield.lastChat.id"
    private let stalePendingInterval: TimeInterval = 20 * 60

    var connectedProviders: Set<Provider> {
        var set: Set<Provider> = []
        for p in Provider.allCases {
            if p == .codex, CodexAuthStore().isSignedIn() {
                set.insert(p)
            } else if let key = keychain.apiKey(for: p), !key.isEmpty {
                set.insert(p)
            }
        }
        return set
    }

    var selectedProjectAssets: [ImageAsset] {
        guard let id = selectedProjectID else { return [] }
        return assetsByProject[id] ?? []
    }

    var selectedProjectRuns: [IterationRun] {
        IterationRun.group(selectedProjectAssets)
    }

    var defaultChatModel: ModelDescriptor? {
        selectedChatModel ?? selectedImageModel ?? modelRegistry.imageModels.first
    }

    var activeBaseAsset: ImageAsset? {
        guard let activeBaseImageID else { return nil }
        return selectedProjectAssets.first { $0.id == activeBaseImageID }
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

    func reloadProjects(recoverInterruptedPending: Bool = true) {
        do {
            projects = try projectStore.listProjects()
            if projects.isEmpty {
                let project = try projectStore.createProject(name: l10n.defaultProjectName)
                projects = [project]
            }
            for p in projects {
                refreshAssets(for: p.id, recoverInterruptedPending: recoverInterruptedPending)
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

    func renameProject(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let updated = try projectStore.renameProject(id: project.id, to: trimmed)
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = updated
            }
        } catch {
            errorBus.report(error, title: "Failed to rename project")
        }
    }

    func moveProjects(from source: IndexSet, to destination: Int) {
        guard !source.isEmpty else { return }
        var reordered = projects
        reordered.move(fromOffsets: source, toOffset: destination)
        projects = reordered
        persistProjectOrder(reordered.map(\.id))
    }

    func moveProject(id: String, relativeTo targetID: String, after: Bool) {
        guard id != targetID,
              let source = projects.firstIndex(where: { $0.id == id }),
              let target = projects.firstIndex(where: { $0.id == targetID }) else { return }
        var reordered = projects
        let moved = reordered.remove(at: source)
        let adjustedTarget = source < target ? target - 1 : target
        let insertion = after ? adjustedTarget + 1 : adjustedTarget
        reordered.insert(moved, at: min(max(0, insertion), reordered.count))
        projects = reordered
        persistProjectOrder(reordered.map(\.id))
    }

    func moveProject(id: String, toInsertionIndex insertionIndex: Int) {
        previewMoveProject(id: id, toInsertionIndex: insertionIndex)
        persistProjectOrder(projects.map(\.id))
    }

    func previewMoveProject(id: String, toInsertionIndex insertionIndex: Int) {
        guard let source = projects.firstIndex(where: { $0.id == id }) else { return }
        var reordered = projects
        let moved = reordered.remove(at: source)
        let adjustedIndex = source < insertionIndex ? insertionIndex - 1 : insertionIndex
        let boundedIndex = min(max(0, adjustedIndex), reordered.count)
        guard boundedIndex != source else { return }
        reordered.insert(moved, at: boundedIndex)
        projects = reordered
    }

    func persistCurrentProjectOrder() {
        persistProjectOrder(projects.map(\.id))
    }

    private func persistProjectOrder(_ ids: [String]) {
        let store = projectStore
        Task {
            do {
                try await Task.detached {
                    try store.reorderProjects(ids: ids)
                }.value
            } catch {
                errorBus.report(error, title: "Failed to reorder projects")
                reloadProjects(recoverInterruptedPending: false)
            }
        }
    }

    // MARK: - Assets

    func refreshAssets(for projectID: String, recoverInterruptedPending: Bool = false) {
        var metas = (try? metadataStore.list(projectID: projectID)) ?? []
        recoverPendingAssets(
            projectID: projectID,
            metas: &metas,
            recoverInterruptedPending: recoverInterruptedPending
        )
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

    private func recoverPendingAssets(
        projectID: String,
        metas: inout [ImageMetadata],
        recoverInterruptedPending: Bool
    ) {
        let staleCutoff = Date().addingTimeInterval(-stalePendingInterval)
        for index in metas.indices where metas[index].status == .pending {
            let isInterrupted = recoverInterruptedPending
            let isStale = metas[index].createdAt < staleCutoff
            guard isInterrupted || isStale else { continue }

            if let _ = try? imageStore.locate(projectID: projectID, imageID: metas[index].id) {
                metas[index].status = .draft
                metas[index].failureReason = nil
            } else {
                metas[index].status = .failed
                metas[index].failureReason = isInterrupted
                    ? l10n.interruptedGenerationReason
                    : l10n.staleGenerationReason
            }
            try? metadataStore.write(metas[index])
        }
    }

    func deleteAsset(_ asset: ImageAsset) {
        let pid = asset.metadata.projectID
        do {
            if activeBaseImageID == asset.id {
                activeBaseImageID = nil
            }
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
                errorBus.report(error, title: l10n.imageGenerationFailed)
            }
        }
    }

    // MARK: - References

    func attachReference(imageID: String) {
        if pendingReferenceIDs.contains(imageID) {
            removeReference(id: imageID)
        } else {
            pendingReferenceIDs.append(imageID)
        }
    }

    func setBaseImage(_ asset: ImageAsset) {
        guard asset.hasFile else { return }
        activeBaseImageID = asset.id
        pendingReferenceIDs.removeAll { $0 == asset.id }
    }

    func clearBaseImage() {
        activeBaseImageID = nil
    }

    func attachExternalReference(url: URL) {
        guard let pid = selectedProjectID else { return }
        do {
            let refID = try referenceStore.ingestExternal(projectID: pid, sourceURL: url)
            pendingReferenceIDs.append(refID)
        } catch {
            errorBus.report(error, title: l10n.referenceAddFailed)
        }
    }

    func attachExternalReference(data: Data, preferredExtension: String = "png") {
        guard let pid = selectedProjectID else { return }
        do {
            let refID = try referenceStore.ingestData(
                projectID: pid,
                data: data,
                preferredExtension: preferredExtension
            )
            pendingReferenceIDs.append(refID)
        } catch {
            errorBus.report(error, title: l10n.referenceAddFailed)
        }
    }

    func makeChatAttachment(data: Data, preferredExtension: String = "png") -> ChatAttachment? {
        do {
            try AppPaths.shared.ensureSkeleton()
            let id = "chat_" + UUID().uuidString.lowercased()
            let ext = preferredExtension.isEmpty ? "png" : preferredExtension
            let url = AppPaths.shared.chatAttachmentsDir.appendingPathComponent("\(id).\(ext)")
            try data.write(to: url, options: .atomic)
            return ChatAttachment(id: id, mimeType: "image/\(ext == "jpg" ? "jpeg" : ext)", path: url.path)
        } catch {
            errorBus.report(error, title: l10n.referenceAddFailed)
            return nil
        }
    }

    func removeReference(id: String) {
        pendingReferenceIDs.removeAll { $0 == id }
    }

    func clearReferences() {
        pendingReferenceIDs.removeAll()
    }

    func asset(withID id: String, in projectID: String? = nil) -> ImageAsset? {
        let assets = projectID.flatMap { assetsByProject[$0] } ?? selectedProjectAssets
        return assets.first { $0.id == id }
    }

    func parentAsset(for asset: ImageAsset) -> ImageAsset? {
        guard let parentID = asset.metadata.parentImageID else { return nil }
        return self.asset(withID: parentID, in: asset.metadata.projectID)
    }

    func childAssets(of asset: ImageAsset) -> [ImageAsset] {
        (assetsByProject[asset.metadata.projectID] ?? [])
            .filter { $0.metadata.parentImageID == asset.id }
            .sorted(by: sortRelatedAssets)
    }

    func runAssets(for asset: ImageAsset) -> [ImageAsset] {
        let runID = asset.metadata.runID ?? asset.id
        return (assetsByProject[asset.metadata.projectID] ?? [])
            .filter { ($0.metadata.runID ?? $0.id) == runID }
            .sorted(by: sortRelatedAssets)
    }

    func threadRuns(for asset: ImageAsset) -> [IterationRun] {
        let assets = assetsByProject[asset.metadata.projectID] ?? []
        let runs = IterationRun.group(assets).sorted {
            if $0.createdAt == $1.createdAt { return $0.id < $1.id }
            return $0.createdAt < $1.createdAt
        }
        let runsByID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        let currentRunID = asset.metadata.runID ?? asset.id

        var ancestors: [IterationRun] = []
        var visited: Set<String> = []
        var cursor = runsByID[currentRunID]
        while let run = cursor, !visited.contains(run.id) {
            ancestors.insert(run, at: 0)
            visited.insert(run.id)
            guard let parentID = run.parentImageID,
                  let parent = self.asset(withID: parentID, in: asset.metadata.projectID) else {
                break
            }
            cursor = runsByID[parent.metadata.runID ?? parent.id]
        }

        var result: [IterationRun] = []
        var included: Set<String> = []
        for run in ancestors {
            let siblingRuns: [IterationRun]
            if let parentID = run.parentImageID {
                siblingRuns = runs.filter { $0.parentImageID == parentID }
            } else {
                siblingRuns = [run]
            }
            for sibling in siblingRuns where !included.contains(sibling.id) {
                result.append(sibling)
                included.insert(sibling.id)
            }
        }

        func appendDescendants(of imageID: String) {
            let childRuns = runs.filter { $0.parentImageID == imageID }
            for run in childRuns where !included.contains(run.id) {
                result.append(run)
                included.insert(run.id)
                for child in run.assets {
                    appendDescendants(of: child.id)
                }
            }
        }
        appendDescendants(of: asset.id)
        return result
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
            errorBus.report(title: l10n.inpaintFailed, message: l10n.cannotReadOriginal)
            return
        }
        let pid = asset.metadata.projectID
        let outputID = UUID().uuidString.lowercased()
        let request = InpaintRequest(
            projectID: pid,
            sourceImageID: asset.id,
            outputImageID: outputID,
            maskPNGData: maskPNG,
            prompt: prompt,
            model: model,
            size: asset.metadata.size
        )
        Task {
            var selectedPending = false
            do {
                try await generationOrchestrator.executeInpaint(
                    request: request,
                    originalPNG: originalPNG,
                    maskPNG: maskPNG
                ) { [weak self] in
                    self?.refreshAssets(for: pid)
                    if !selectedPending,
                       let created = self?.asset(withID: outputID, in: pid) {
                        self?.presentedAsset = created
                        selectedPending = true
                    }
                }
            } catch {
                errorBus.report(error, title: l10n.inpaintFailed)
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
                errorBus.report(error, title: l10n.exportFailed)
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
                errorBus.report(error, title: l10n.exportFailed)
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
                errorBus.report(error, title: l10n.projectExportFailed)
            }
        }
    }

    // MARK: - Regenerate / use-as-reference

    func regenerate(_ asset: ImageAsset) {
        let meta = asset.metadata
        guard let model = modelRegistry.imageModels.first(where: { $0.id == meta.modelID && $0.provider == meta.provider })
                ?? modelRegistry.imageModels.first(where: { $0.provider == meta.provider }) else {
            errorBus.report(title: l10n.regenerateFailed, message: l10n.modelNotFound)
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
            parentImageID: meta.parentImageID,
            seed: meta.seed
        )
        generate(request: request)
    }

    func useAsReference(_ asset: ImageAsset) {
        attachReference(imageID: asset.id)
    }

    private func sortRelatedAssets(_ lhs: ImageAsset, _ rhs: ImageAsset) -> Bool {
        let leftIndex = lhs.metadata.variantIndex ?? Int.max
        let rightIndex = rhs.metadata.variantIndex ?? Int.max
        if leftIndex != rightIndex { return leftIndex < rightIndex }
        if lhs.metadata.createdAt != rhs.metadata.createdAt {
            return lhs.metadata.createdAt < rhs.metadata.createdAt
        }
        return lhs.id < rhs.id
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

enum FocusedInput: Hashable {
    case prompt
    case chat
}
