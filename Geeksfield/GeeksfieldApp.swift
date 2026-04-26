import SwiftUI

@main
struct GeeksfieldApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .task {
                    await appState.bootstrap()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(appState.l10n.checkForUpdates) {
                    appState.autoUpdater.checkForUpdates()
                }
                .disabled(!appState.autoUpdater.isEnabled)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
    }
}

private struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                MainSplitView()
            } else {
                OnboardingView()
            }

            if let asset = appState.presentedAsset {
                ImageDetailModal(asset: asset)
                    .environment(appState)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.22)),
                        removal: .opacity.animation(.easeIn(duration: 0.15))
                    ))
                    .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.22), value: appState.presentedAsset?.id)
        .alert(
            appState.errorBus.latest?.title ?? appState.l10n.error,
            isPresented: errorBinding
        ) {
            Button(appState.l10n.ok) { appState.errorBus.dismiss() }
        } message: {
            Text(appState.errorBus.latest?.message ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appState.errorBus.latest != nil },
            set: { if !$0 { appState.errorBus.dismiss() } }
        )
    }
}

private struct MainSplitView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } content: {
            GalleryView()
        } detail: {
            ChatSidebarView()
        }
        .toolbar(appState.presentedAsset == nil ? .visible : .hidden, for: .windowToolbar)
    }
}
