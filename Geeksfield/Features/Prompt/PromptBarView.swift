import AppKit
import SwiftUI

struct PromptBarView: View {
    @Environment(AppState.self) private var appState
    @State private var prompt: String = ""
    @State private var batchSize: Int = 1
    @State private var selectedSize: Size?
    @State private var selectedAspect: String?
    @State private var promptHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            referenceRow

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
        .onChange(of: appState.selectedImageModel) { _, newModel in
            guard let spec = newModel.flatMap({ imageSpec(for: $0) }) else { return }
            if selectedSize == nil { selectedSize = spec.sizes.first }
            if selectedAspect == nil { selectedAspect = spec.aspectRatios.first }
            if batchSize > spec.maxBatch { batchSize = spec.maxBatch }
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
                maxHeight: 140
            )
            .frame(height: promptHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - References

    private var referenceRow: some View {
        HStack(spacing: 8) {
            ForEach(appState.pendingReferenceIDs, id: \.self) { id in
                referenceThumb(id: id)
            }
            ReferencePicker(compact: true)
        }
    }

    private func referenceThumb(id: String) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let url = appState.referenceThumbnailURL(for: id) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.white.opacity(0.06)
                        }
                    }
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }

            Button {
                appState.removeReference(id: id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.black.opacity(0.75)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    // MARK: - Pills

    private var pillsRow: some View {
        HStack(spacing: 8) {
            modelPill

            if let spec = imageSpec {
                pillMenu(
                    icon: "rectangle.ratio.16.to.9",
                    label: selectedSize.map { $0.isAuto ? "auto" : $0.description } ?? appState.l10n.sizeLabel
                ) {
                    ForEach(spec.sizes, id: \.self) { size in
                        Button(size.isAuto ? "auto" : size.description) { selectedSize = size }
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

            Spacer(minLength: 0)

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
            Text("\(batchSize)/\(maxBatch)")
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .frame(minWidth: 28)
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
        .keyboardShortcut(.return, modifiers: .command)
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
        let request = GenerationRequest(
            projectID: projectID,
            prompt: trimmed,
            negativePrompt: nil,
            model: model,
            size: size,
            aspectRatio: selectedAspect,
            batchSize: batchSize,
            referenceIDs: appState.pendingReferenceIDs,
            seed: nil
        )
        appState.generate(request: request)
        prompt = ""
        appState.clearReferences()
    }
}
