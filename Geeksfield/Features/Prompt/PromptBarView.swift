import SwiftUI

struct PromptBarView: View {
    @Environment(AppState.self) private var appState
    @State private var prompt: String = ""
    @State private var batchSize: Int = 1
    @State private var selectedSize: Size?
    @State private var selectedAspect: String?

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                TextField("무엇을 그릴까요?", text: $prompt, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding(.bottom, 4)

                HStack(alignment: .center, spacing: 6) {
                    ModelSelector()

                    if let spec = imageSpec {
                        pillMenu(
                            icon: "rectangle.ratio.16.to.9",
                            label: selectedSize.map { $0.isAuto ? "auto" : $0.description } ?? "크기"
                        ) {
                            ForEach(spec.sizes, id: \.self) { size in
                                Button(size.isAuto ? "auto" : size.description) { selectedSize = size }
                            }
                        }

                        pillMenu(
                            icon: "aspectratio",
                            label: selectedAspect ?? "비율"
                        ) {
                            ForEach(spec.aspectRatios, id: \.self) { ratio in
                                Button(ratio) { selectedAspect = ratio }
                            }
                        }

                        pillMenu(
                            icon: "square.grid.2x2",
                            label: "×\(batchSize)"
                        ) {
                            ForEach(1...spec.maxBatch, id: \.self) { n in
                                Button("\(n)") { batchSize = n }
                            }
                        }
                    }

                    ReferencePicker()

                    Spacer()

                    Button {
                        submit()
                    } label: {
                        Label("생성", systemImage: "wand.and.sparkles")
                            .font(.body.weight(.medium))
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .controlSize(.large)
            }
            .padding(16)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onChange(of: appState.selectedImageModel) { _, newModel in
            guard let spec = newModel.flatMap({ imageSpec(for: $0) }) else { return }
            if selectedSize == nil { selectedSize = spec.sizes.first }
            if selectedAspect == nil { selectedAspect = spec.aspectRatios.first }
            if batchSize > spec.maxBatch { batchSize = spec.maxBatch }
        }
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
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.callout)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var imageSpec: ImageSpec? {
        guard let model = appState.selectedImageModel else { return nil }
        return imageSpec(for: model)
    }

    private func imageSpec(for model: ModelDescriptor) -> ImageSpec? {
        if case .image(let spec) = model.capability { return spec }
        return nil
    }

    private func submit() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appState.errorBus.report(title: "프롬프트 필요", message: "무엇을 그릴지 입력하세요.")
            return
        }
        guard let projectID = appState.selectedProjectID else {
            appState.errorBus.report(
                title: "프로젝트 선택 필요",
                message: "왼쪽 사이드바에서 프로젝트를 선택하거나 + 버튼으로 새로 만드세요."
            )
            return
        }
        guard let model = appState.selectedImageModel else {
            let hint = appState.modelRegistry.imageModels.isEmpty
                ? "설정 > API Keys에서 키를 먼저 입력하세요."
                : "왼쪽 모델 메뉴에서 모델을 선택하세요."
            appState.errorBus.report(title: "이미지 모델 필요", message: hint)
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
