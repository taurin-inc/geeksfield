import SwiftUI

struct ImageTileView: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @State private var hovered = false
    @State private var imageAspect = CGFloat(1)

    var body: some View {
        ZStack {
            content
                .clipped()

            statusOverlay
            variantOverlay
            hoverOverlay
        }
        .aspectRatio(ImageAspectReader.clamped(imageAspect), contentMode: .fit)
        .scaleEffect(hovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .onHover { hovered = $0 }
        .task(id: asset.fileURL?.path ?? asset.thumbnailURL?.path ?? asset.id) {
            imageAspect = await ImageAspectReader.aspectRatio(for: asset)
        }
        .draggable(transferableURL)
    }

    @ViewBuilder
    private var hoverOverlay: some View {
        if asset.hasFile && (hovered || asset.status == .picked) {
            VStack {
                HStack(spacing: 6) {
                    Spacer()
                    baseHoverButton
                    bookmarkHoverButton
                }
                Spacer()
            }
            .padding(8)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var variantOverlay: some View {
        if asset.hasFile, let variantIndex = asset.metadata.variantIndex {
            VStack {
                Spacer()
                HStack {
                    Text("#\(variantIndex)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 3, y: 1)
                    Spacer()
                }
            }
            .padding(8)
        }
    }

    private var baseHoverButton: some View {
        Button {
            appState.setBaseImage(asset)
        } label: {
            Image(systemName: "target")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appState.activeBaseImageID == asset.id ? Color.accentColor : Color.white)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(appState.l10n.useAsBase)
    }

    private var bookmarkHoverButton: some View {
        Button {
            appState.setStatus(asset, to: asset.status == .picked ? .draft : .picked)
        } label: {
            Image(systemName: asset.status == .picked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(asset.status == .picked ? Color.yellow : Color.white)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(asset.status == .picked ? appState.l10n.pickedClear : appState.l10n.pickedToggle)
    }

    @ViewBuilder
    private var content: some View {
        if let url = asset.thumbnailURL ?? asset.fileURL {
            LocalImage(url: url, contentMode: .fit)
        } else if asset.status == .failed {
            failedPlaceholder
        } else {
            skeleton
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if asset.status == .pending {
            VStack(spacing: 6) {
                ProgressView().controlSize(.small)
                    .frame(width: 18, height: 18)
                Text(appState.l10n.generating)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if asset.status == .failed {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(appState.l10n.failed)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(8)
                .background(.ultraThinMaterial)
            }
        } else if !asset.hasFile {
            ProgressView().controlSize(.small)
                .frame(width: 18, height: 18)
        }
    }

    private var skeleton: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.04), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallback: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.tertiary)
    }

    private var failedPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.red.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange.opacity(0.8))
        }
    }

    private var transferableURL: URL {
        asset.fileURL ?? URL(fileURLWithPath: "/dev/null")
    }
}
