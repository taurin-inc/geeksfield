import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ReferencePicker: View {
    @Environment(AppState.self) private var appState
    @State private var popoverOpen = false

    var body: some View {
        Button {
            popoverOpen.toggle()
        } label: {
            Label(
                "\(appState.pendingReferenceIDs.count)",
                systemImage: appState.pendingReferenceIDs.isEmpty
                    ? "photo.on.rectangle"
                    : "photo.on.rectangle.fill"
            )
        }
        .buttonStyle(.glass)
        .popover(isPresented: $popoverOpen, arrowEdge: .top) {
            content
                .frame(width: 360, height: 420)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !appState.pendingReferenceIDs.isEmpty {
                attachedSection
                Divider()
            }

            projectPickerSection
        }
        .padding(12)
    }

    private var header: some View {
        HStack {
            Text("레퍼런스").font(.headline)
            Spacer()
            Button("외부 추가…") { pickExternalFile() }
                .buttonStyle(.glass)
            if !appState.pendingReferenceIDs.isEmpty {
                Button(role: .destructive) { appState.clearReferences() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var attachedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("첨부됨 (\(appState.pendingReferenceIDs.count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.pendingReferenceIDs, id: \.self) { id in
                        attachedThumb(id: id)
                    }
                }
            }
        }
    }

    private func attachedThumb(id: String) -> some View {
        ZStack(alignment: .topTrailing) {
            thumbImage(url: appState.referenceThumbnailURL(for: id))
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button {
                appState.removeReference(id: id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.white, .black.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(2)
        }
    }

    private var projectPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("프로젝트 내 이미지에서 선택")
                .font(.caption)
                .foregroundStyle(.secondary)

            let assets = projectAssets
            if assets.isEmpty {
                Text("아직 이미지가 없습니다.").font(.callout).foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(assets) { asset in
                            Button {
                                appState.attachReference(imageID: asset.id)
                            } label: {
                                thumbImage(url: asset.thumbnailURL ?? asset.fileURL)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                appState.pendingReferenceIDs.contains(asset.id)
                                                    ? Color.accentColor
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var projectAssets: [ImageAsset] {
        appState.selectedProjectAssets.filter { $0.hasFile }
    }

    @ViewBuilder
    private func thumbImage(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
        } else {
            Color.secondary.opacity(0.1)
        }
    }

    private func pickExternalFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appState.attachExternalReference(url: url)
    }
}
