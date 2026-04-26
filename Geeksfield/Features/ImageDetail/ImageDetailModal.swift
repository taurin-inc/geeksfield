import SwiftUI

/// Full-screen overlay for inspecting one image. Tapping the dimmed backdrop or
/// pressing ESC closes; the inner card absorbs taps so they don't dismiss.
struct ImageDetailModal: View {
    let asset: ImageAsset
    @Environment(AppState.self) private var appState
    @State private var inpaintOpen = false

    var body: some View {
        ZStack {
            backdrop
            card
        }
        .ignoresSafeArea()
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
            .fill(.ultraThinMaterial)
            .overlay(Color.black.opacity(0.25))
            .contentShape(Rectangle())
            .onTapGesture {
                dismiss()
            }
    }

    private var card: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                imagePane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)

                ImageDetailInfo(metadata: asset.metadata)
                    .frame(width: 320)
            }
            .frame(maxHeight: .infinity)

            Divider()

            ImageActionsBar(
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: 1200, maxHeight: 760)
        .padding(40)
        .onTapGesture { /* absorb taps so backdrop isn't triggered */ }
    }

    @ViewBuilder
    private var imagePane: some View {
        if let url = asset.fileURL {
            LocalImage(url: url, contentMode: .fit)
        } else if asset.status == .pending {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("생성 중…").foregroundStyle(.secondary)
            }
        } else if asset.status == .failed {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                Text(asset.metadata.failureReason ?? "생성 실패")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else {
            ProgressView()
        }
    }

    private func dismiss() {
        appState.presentedAsset = nil
    }
}
