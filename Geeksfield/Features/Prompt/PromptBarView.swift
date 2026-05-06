import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PromptBarView: View {
    @Environment(AppState.self) private var appState
    @State private var prompt: String = ""
    @State private var batchSize: Int = 3
    @State private var selectedSize: Size?
    @State private var selectedAspect: String?
    @State private var promptHeight: CGFloat = 24
    @State private var isBaseBadgeHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            referenceStrip

            promptEditor

            pillsRow
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onAppear {
            syncControls(with: appState.selectedImageModel)
        }
        .onChange(of: appState.selectedImageModel) { _, newModel in
            syncControls(with: newModel)
        }
        .onPasteCommand(of: [.image]) { providers in
            loadPastedImages(from: providers, receive: addPastedReferences)
        }
    }

    // MARK: - Prompt editor

    private var promptEditor: some View {
        ZStack(alignment: .topLeading) {
            if prompt.isEmpty {
                Text(appState.l10n.promptPlaceholder)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
            MultilineTextEditor(
                text: $prompt,
                contentHeight: $promptHeight,
                font: .systemFont(ofSize: NSFont.systemFontSize(for: .regular) + 4),
                minHeight: 24,
                maxHeight: 140,
                onPasteImages: addPastedReferences,
                onCommandReturn: {
                    guard appState.focusedInput == .prompt else { return }
                    submit()
                },
                onFocusChange: { focused in
                    if focused {
                        appState.focusedInput = .prompt
                    } else if appState.focusedInput == .prompt {
                        appState.focusedInput = nil
                    }
                }
            )
            .frame(height: promptHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - References

    private var referenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            referenceControls
                .padding(.vertical, 1)
        }
        .frame(height: attachmentSize + 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var referenceControls: some View {
        HStack(spacing: 6) {
            if let base = appState.activeBaseAsset {
                baseThumb(base)
            }
            ForEach(appState.pendingReferenceIDs, id: \.self) { id in
                referenceThumb(id: id)
            }
            ReferencePicker(compact: true, compactSize: attachmentSize)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func baseThumb(_ asset: ImageAsset) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let url = asset.thumbnailURL ?? asset.fileURL {
                    LocalImage(url: url, contentMode: .fill)
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: attachmentSize, height: attachmentSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
            }

            VStack {
                Spacer()
                HStack {
                    baseBadge
                    Spacer()
                }
            }
            .padding(5)

            Button {
                appState.clearBaseImage()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.75)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .help(appState.l10n.baseImage)
    }

    private var baseBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isBaseBadgeHovered {
                Text(appState.l10n.baseImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
            }

            Image(systemName: "target")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
                .contentShape(Circle())
        }
        .onHover { isBaseBadgeHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isBaseBadgeHovered)
        .help(appState.l10n.baseImage)
    }

    private func referenceThumb(id: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let url = appState.referenceThumbnailURL(for: id) {
                    LocalImage(url: url, contentMode: .fill)
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: attachmentSize, height: attachmentSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }

            Button {
                appState.removeReference(id: id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.75)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    private var attachmentSize: CGFloat { 64 }

    // MARK: - Pills

    private var pillsRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    modelPill

                    if let spec = imageSpec {
                        if spec.sizes.contains(where: { !$0.isAuto }) {
                            pillMenu(
                                icon: "rectangle.ratio.16.to.9",
                                label: selectedSize.map { $0.isAuto ? "auto" : $0.description } ?? appState.l10n.sizeLabel
                            ) {
                                ForEach(spec.sizes, id: \.self) { size in
                                    Button(size.isAuto ? "auto" : size.description) { selectedSize = size }
                                }
                            }
                        }

                        pillMenu(
                            icon: "aspectratio",
                            label: selectedAspect ?? appState.l10n.aspectLabel
                        ) {
                            ForEach(spec.aspectRatios, id: \.self) { ratio in
                                Button(ratio) { selectedAspect = ratio }
                            }
                        }

                        batchStepperPill(maxBatch: spec.maxBatch)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(height: 46)
            .frame(maxWidth: .infinity, alignment: .leading)
            generateButton
        }
    }

    private var modelPill: some View {
        Menu {
            if appState.modelRegistry.imageModels.isEmpty {
                Text(appState.l10n.noAvailableModels).foregroundStyle(.secondary)
            } else {
                ForEach(groupedModelsByProvider, id: \.0) { provider, models in
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            Button {
                                appState.setImageModel(model)
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if appState.selectedImageModel?.id == model.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu").font(.caption)
                Text(appState.selectedImageModel?.displayName ?? appState.l10n.chooseModel)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1) }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var groupedModelsByProvider: [(Provider, [ModelDescriptor])] {
        let grouped = Dictionary(grouping: appState.modelRegistry.imageModels) { $0.provider }
        return Provider.allCases.compactMap { p in
            guard let items = grouped[p], !items.isEmpty else { return nil }
            return (p, items)
        }
    }

    private func batchStepperPill(maxBatch: Int) -> some View {
        HStack(spacing: 10) {
            stepperIcon("minus", enabled: batchSize > 1) {
                if batchSize > 1 { batchSize -= 1 }
            }
            HStack(spacing: 5) {
                Image(systemName: "square.stack.3d.up")
                    .font(.caption)
                Text(appState.l10n.imageCount(batchSize))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
            }
            .frame(minWidth: 50)
            stepperIcon("plus", enabled: batchSize < maxBatch) {
                if batchSize < maxBatch { batchSize += 1 }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1) }
    }

    private func stepperIcon(_ name: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    @ViewBuilder
    private func pillMenu<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay { Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1) }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Generate

    private var generateButton: some View {
        Button(action: submit) {
            HStack(spacing: 6) {
                Text(appState.l10n.generate)
                    .font(.callout.weight(.bold))
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(Color.white)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var imageSpec: ImageSpec? {
        guard let model = appState.selectedImageModel else { return nil }
        return imageSpec(for: model)
    }

    private func imageSpec(for model: ModelDescriptor) -> ImageSpec? {
        if case .image(let spec) = model.capability { return spec }
        return nil
    }

    private func syncControls(with model: ModelDescriptor?) {
        guard let spec = model.flatMap({ imageSpec(for: $0) }) else { return }
        if selectedSize.map({ !spec.sizes.contains($0) }) ?? true {
            selectedSize = spec.sizes.first
        }
        if selectedAspect.map({ !spec.aspectRatios.contains($0) }) ?? true {
            selectedAspect = spec.aspectRatios.first
        }
        if batchSize > spec.maxBatch {
            batchSize = spec.maxBatch
        }
    }

    private func submit() {
        let l10n = appState.l10n
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.errorBus.report(title: l10n.promptRequired, message: l10n.enterWhatToDraw)
            return
        }
        guard let projectID = appState.selectedProjectID else {
            appState.errorBus.report(
                title: l10n.projectRequired,
                message: l10n.pickProjectOrCreate
            )
            return
        }
        guard let model = appState.selectedImageModel else {
            let hint = appState.modelRegistry.imageModels.isEmpty
                ? l10n.enterKeyInSettings
                : l10n.pickImageModel
            appState.errorBus.report(title: l10n.imageModelRequired, message: hint)
            return
        }

        let size = selectedSize ?? .auto
        let referenceIDs = mergedReferenceIDs()
        let request = GenerationRequest(
            projectID: projectID,
            prompt: trimmed,
            negativePrompt: nil,
            model: model,
            size: size,
            aspectRatio: selectedAspect,
            batchSize: batchSize,
            referenceIDs: referenceIDs,
            parentImageID: appState.activeBaseAsset?.id ?? referenceIDs.first(where: { !$0.hasPrefix("ref_") }),
            seed: nil
        )
        appState.generate(request: request)
        prompt = ""
        appState.clearReferences()
    }

    private func mergedReferenceIDs() -> [String] {
        var result: [String] = []
        var seen: Set<String> = []
        if let baseID = appState.activeBaseAsset?.id {
            result.append(baseID)
            seen.insert(baseID)
        }
        for id in appState.pendingReferenceIDs where !seen.contains(id) {
            result.append(id)
            seen.insert(id)
        }
        return result
    }

    private func addPastedReferences(_ payloads: [PastedImagePayload]) {
        for payload in payloads {
            appState.attachExternalReference(
                data: payload.data,
                preferredExtension: payload.preferredExtension
            )
        }
    }

    private func loadPastedImages(
        from providers: [NSItemProvider],
        receive: @MainActor @Sendable @escaping ([PastedImagePayload]) -> Void
    ) {
        for provider in providers {
            guard let type = preferredImageType(for: provider) else { continue }
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                guard let data else { return }
                let payload = PastedImagePayload(
                    data: data,
                    preferredExtension: type.preferredFilenameExtension ?? "png"
                )
                Task { @MainActor in
                    receive([payload])
                }
            }
        }
    }

    private func preferredImageType(for provider: NSItemProvider) -> UTType? {
        [.png, .jpeg, .heic, .tiff, .image].first {
            provider.hasItemConformingToTypeIdentifier($0.identifier)
        }
    }
}
