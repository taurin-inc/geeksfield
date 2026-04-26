import SwiftUI

/// Full-screen overlay for inspecting one image. Tapping the dimmed backdrop or
/// pressing ESC closes; the inner content absorbs taps so they don't dismiss.
struct ImageDetailModal: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @State private var inpaintOpen = false

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()
            content
        }
        .background {
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
            Button("Export") { appState.exportAsset(asset) }
                .keyboardShortcut("s", modifiers: .command)
                .opacity(0)
                .disabled(!asset.hasFile)
        }
        .sheet(isPresented: $inpaintOpen) {
            InpaintSheet(asset: asset)
                .environment(appState)
        }
    }

    private var backdrop: some View {
        Rectangle()
            .fill(Color.black.opacity(0.78))
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 0) {
            imageColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ImageDetailInfo(
                asset: asset,
                onEdit: { inpaintOpen = true },
                onRegenerate: {
                    appState.regenerate(asset)
                    dismiss()
                },
                onUseAsReference: {
                    appState.useAsReference(asset)
                    dismiss()
                },
                onExport: { appState.exportAsset(asset) },
                onPick: {
                    appState.setStatus(asset, to: asset.status == .picked ? .draft : .picked)
                    dismiss()
                },
                onDelete: {
                    appState.deleteAsset(asset)
                    dismiss()
                }
            )
            .frame(width: 380)
            .padding(.vertical, 24)
            .padding(.trailing, 24)
        }
        .onTapGesture { /* absorb */ }
    }

    private var imageColumn: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            imagePane
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.55), radius: 30, x: 0, y: 18)
                .padding(.horizontal, 32)
            actionPills
            Spacer(minLength: 0)
        }
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private var imagePane: some View {
        if let url = asset.fileURL {
            LocalImage(url: url, contentMode: .fit)
        } else if asset.status == .pending {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text(appState.l10n.generating).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 480, maxHeight: 480)
        } else if asset.status == .failed {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text(asset.metadata.failureReason ?? appState.l10n.generationFailed)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 480, maxHeight: 480)
        } else {
            ProgressView()
                .frame(maxWidth: 480, maxHeight: 480)
        }
    }

    private var actionPills: some View {
        let l10n = appState.l10n
        return HStack(spacing: 4) {
            pill(l10n.overview, system: "rectangle.on.rectangle", isActive: true) {}
            pill(l10n.edit, system: "wand.and.stars") {
                if asset.hasFile { inpaintOpen = true }
            }
            .disabled(!asset.hasFile)
            pill(l10n.regenerate, system: "arrow.triangle.2.circlepath") {
                appState.regenerate(asset)
                dismiss()
            }
            pill(l10n.reference, system: "photo.on.rectangle") {
                appState.useAsReference(asset)
                dismiss()
            }
            .disabled(!asset.hasFile)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
        )
    }

    private func pill(
        _ title: String,
        system: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.white.opacity(0.10) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismiss() {
        appState.presentedAsset = nil
    }
}
