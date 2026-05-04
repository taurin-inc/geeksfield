import AppKit
import SwiftUI

struct InpaintSheet: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editor = InpaintEditorState()
    @State private var selectedModel: ModelDescriptor?
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasArea
            Divider()
            bottomBar
        }
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            selectedModel = appState.modelRegistry.imageModels
                .first(where: { inpaintCapable($0) && $0.id == asset.metadata.modelID })
                ?? appState.modelRegistry.imageModels.first(where: inpaintCapable)
        }
    }

    private var toolbar: some View {
        let l10n = appState.l10n
        return HStack(spacing: 12) {
            Text(l10n.inpaint).font(.headline)
            Spacer()
            Picker("", selection: $editor.tool) {
                Image(systemName: "paintbrush").tag(InpaintTool.brush)
                Image(systemName: "eraser").tag(InpaintTool.eraser)
            }
            .pickerStyle(.segmented)
            .frame(width: 92)
            Text(l10n.brush).font(.caption).foregroundStyle(.secondary)
            Slider(value: $editor.brushSize, in: 8...120)
                .frame(width: 180)
            Text("\(Int(editor.brushSize))px").monospacedDigit().font(.caption)
            Text("Zoom").font(.caption).foregroundStyle(.secondary)
            Slider(value: $editor.zoom, in: 1...4)
                .frame(width: 120)
            Text("\(Int(editor.zoom * 100))%").monospacedDigit().font(.caption)
                .frame(width: 44, alignment: .trailing)

            Button { editor.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!editor.canUndo)
            Button { editor.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!editor.canRedo)
            Button(l10n.reset) { editor.clear() }.disabled(!editor.canUndo)
        }
        .buttonStyle(.glass)
        .padding(12)
        .glassEffect(.regular)
    }

    private var canvasArea: some View {
        GeometryReader { geo in
            if let url = asset.fileURL {
                let size = CGSize(
                    width: max(geo.size.width, geo.size.width * editor.zoom),
                    height: max(geo.size.height, geo.size.height * editor.zoom)
                )
                ScrollView([.horizontal, .vertical]) {
                    InpaintCanvas(imageURL: url, state: editor)
                        .frame(width: size.width, height: size.height)
                }
                .onAppear { canvasSize = size }
                .onChange(of: geo.size) { _, _ in canvasSize = size }
                .onChange(of: editor.zoom) { _, _ in canvasSize = size }
            } else {
                ContentUnavailableView(appState.l10n.originalImageNotFound, systemImage: "photo.badge.exclamationmark")
            }
        }
    }

    private var bottomBar: some View {
        let l10n = appState.l10n
        return HStack(spacing: 10) {
            inpaintModelMenu
            TextField(l10n.editInstruction, text: $editor.prompt, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            Spacer(minLength: 8)
            Button(l10n.cancel) { dismiss() }.buttonStyle(.glass)
            Button {
                submit()
            } label: {
                Label(l10n.edit, systemImage: "wand.and.sparkles")
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSubmit)
        }
        .padding(12)
        .glassEffect(.regular)
    }

    private var inpaintModelMenu: some View {
        Menu {
            ForEach(Provider.allCases, id: \.self) { provider in
                let models = appState.modelRegistry.imageModels(for: provider).filter(inpaintCapable)
                if !models.isEmpty {
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            Button {
                                selectedModel = model
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if selectedModel?.id == model.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Text(selectedModel?.displayName ?? appState.l10n.modelLabel)
        }
        .menuStyle(.borderlessButton)
    }

    private var canSubmit: Bool {
        selectedModel != nil
            && editor.hasMask
            && !editor.prompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func inpaintCapable(_ model: ModelDescriptor) -> Bool {
        if case .image(let spec) = model.capability { return spec.supportsInpaint }
        return false
    }

    private func submit() {
        guard let model = selectedModel,
              let fileURL = asset.fileURL,
              let nsImage = NSImage(contentsOf: fileURL) else { return }
        let imageSize = nsImage.nativePixelSize
        let imageFrame = InpaintMaskEncoder.fittedImageFrame(imageSize: imageSize, containerSize: canvasSize)
        let style: MaskStyle = .whiteOnBlack

        guard let mask = InpaintMaskEncoder.encode(
            strokes: editor.strokes,
            viewSize: canvasSize,
            imageSize: imageSize,
            imageFrame: imageFrame,
            style: style
        ) else {
            appState.errorBus.report(title: appState.l10n.maskCreationFailed, message: "")
            return
        }

        appState.inpaint(
            asset: asset,
            prompt: editor.prompt,
            model: model,
            maskPNG: mask
        )
        dismiss()
    }
}

private extension NSImage {
    var nativePixelSize: CGSize {
        if let rep = representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return size
    }
}
