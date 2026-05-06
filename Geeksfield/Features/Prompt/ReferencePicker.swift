import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ReferencePicker: View {
    @Environment(AppState.self) private var appState
    @State private var popoverOpen = false
    var compact: Bool = false
    var compactSize: CGFloat = 56

    var body: some View {
        Group {
            if compact {
                Button {
                    popoverOpen.toggle()
                } label: {
                    compactLabel
                }
                .buttonStyle(.plain)
            } else {
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
            }
        }
        .popover(isPresented: $popoverOpen, arrowEdge: .top) {
            content
                .frame(width: 360, height: 420)
        }
    }

    private var compactLabel: some View {
        Image(systemName: "photo.badge.plus")
            .font(.system(size: compactSize > 48 ? 18 : 15, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: compactSize, height: compactSize)
            .background(
                RoundedRectangle(cornerRadius: compactSize > 48 ? 12 : 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: compactSize > 48 ? 12 : 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
            .contentShape(Rectangle())
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
        let l10n = appState.l10n
        return HStack {
            Text(l10n.reference).font(.headline)
            Spacer()
            Button(l10n.addExternal) { pickExternalFile() }
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
            Text(appState.l10n.attachedCount(appState.pendingReferenceIDs.count))
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
            Text(appState.l10n.pickFromProjectImages)
                .font(.caption)
                .foregroundStyle(.secondary)

            let assets = projectAssets
            if assets.isEmpty {
                Text(appState.l10n.noImagesYetSentence).font(.callout).foregroundStyle(.tertiary)
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
            LocalImage(url: url, contentMode: .fill)
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
