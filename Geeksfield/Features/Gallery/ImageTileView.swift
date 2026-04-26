import SwiftUI

struct ImageTileView: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @State private var hovered = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)

            content
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            statusOverlay
            hoverOverlay
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    asset.status == .picked
                        ? Color.accentColor.opacity(0.7)
                        : Color.clear,
                    lineWidth: 1.5
                )
        }
        .scaleEffect(hovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(hovered ? 0.25 : 0), radius: hovered ? 12 : 0, y: hovered ? 4 : 0)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .onHover { hovered = $0 }
        .draggable(transferableURL)
    }

    @ViewBuilder
    private var hoverOverlay: some View {
        if asset.hasFile && (hovered || asset.status == .picked) {
            VStack {
                HStack {
                    Spacer()
                    bookmarkHoverButton
                }
                Spacer()
            }
            .padding(8)
            .transition(.opacity)
        }
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
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(asset.status == .picked ? appState.l10n.pickedClear : appState.l10n.pickedToggle)
    }

    @ViewBuilder
    private var content: some View {
        if let url = asset.thumbnailURL ?? asset.fileURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    skeleton
                case .failure:
                    fallback
                @unknown default:
                    EmptyView()
                }
            }
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
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if !asset.hasFile {
            ProgressView().controlSize(.small)
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
