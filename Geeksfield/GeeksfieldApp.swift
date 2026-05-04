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
        }
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
    @AppStorage("geeksfield.chatPanel.visible") private var showsChatPanel = true

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            MainWorkspaceView(showsChatPanel: $showsChatPanel)
        }
        .toolbar(.visible, for: .windowToolbar)
    }
}

private struct MainWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Binding var showsChatPanel: Bool

    private let chatPanelWidth = CGFloat(320)

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                GalleryView()
                    .frame(minWidth: 480, maxWidth: .infinity)

                if showsChatPanel {
                    Divider().opacity(0.5)
                    ChatSidebarView()
                        .frame(width: chatPanelWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            chatHandle
                .padding(.trailing, showsChatPanel ? chatPanelWidth - 17 : 10)
                .zIndex(2)
        }
        .animation(.smooth(duration: 0.2), value: showsChatPanel)
    }

    private var chatHandle: some View {
        Button {
            showsChatPanel.toggle()
        } label: {
            Image(systemName: showsChatPanel ? "chevron.right" : "bubble.left.and.text.bubble.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 58)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
        .help(showsChatPanel ? appState.l10n.hideChatPanel : appState.l10n.showChatPanel)
    }
}
