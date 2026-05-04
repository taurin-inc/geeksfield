import SwiftUI

extension View {
    func failedImageAlert(
        asset: Binding<ImageAsset?>,
        dismissPresentedAsset: Bool = false
    ) -> some View {
        modifier(
            FailedImageAlertModifier(
                failedAsset: asset,
                dismissPresentedAsset: dismissPresentedAsset
            )
        )
    }
}

private struct FailedImageAlertModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var failedAsset: ImageAsset?
    let dismissPresentedAsset: Bool

    func body(content: Content) -> some View {
        content.alert(
            appState.l10n.generationFailed,
            isPresented: isPresented,
            presenting: failedAsset
        ) { asset in
            Button(appState.l10n.retryGeneration) {
                appState.regenerate(asset)
                clearPresentedAssetIfNeeded(asset)
                failedAsset = nil
            }
            Button(appState.l10n.deleteImage, role: .destructive) {
                clearPresentedAssetIfNeeded(asset)
                appState.deleteAsset(asset)
                failedAsset = nil
            }
        } message: { asset in
            Text(asset.metadata.failureReason ?? appState.l10n.unknownFailureReason)
        }
    }

    private var isPresented: Binding<Bool> {
        Binding {
            failedAsset != nil
        } set: { presented in
            if !presented {
                failedAsset = nil
            }
        }
    }

    private func clearPresentedAssetIfNeeded(_ asset: ImageAsset) {
        guard dismissPresentedAsset, appState.presentedAsset?.id == asset.id else { return }
        appState.presentedAsset = nil
    }
}
