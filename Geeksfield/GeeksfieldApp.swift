import AppKit
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
    @State private var isFullScreen = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            MainWorkspaceView(
                showsChatPanel: $showsChatPanel,
                isFullScreen: isFullScreen
            )
        }
        .toolbar(.visible, for: .windowToolbar)
        .background {
            WindowFullScreenObserver(isFullScreen: $isFullScreen)
                .frame(width: 0, height: 0)
        }
    }
}

private struct MainWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Binding var showsChatPanel: Bool
    let isFullScreen: Bool
    @AppStorage("geeksfield.chatPanel.width") private var storedChatPanelWidth = 360.0

    private let chatPanelWidthRange = CGFloat(280)...CGFloat(560)
    private let chatPanelDividerWidth = CGFloat(12)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            workspace

            if !showsChatPanel {
                Button {
                    showsChatPanel = true
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
                .padding(.top, 10)
                .padding(.trailing, 10)
                .help(appState.l10n.showChatPanel)
            }
        }
        .ignoresSafeArea(.container, edges: ignoredWorkspaceSafeAreaEdges)
        .animation(.smooth(duration: 0.18), value: showsChatPanel)
    }

    @ViewBuilder
    private var workspace: some View {
        if showsChatPanel {
            InvisibleDividerSplitView(
                minLeadingWidth: 480,
                minTrailingWidth: chatPanelWidthRange.lowerBound,
                idealTrailingWidth: CGFloat(storedChatPanelWidth).clamped(to: chatPanelWidthRange),
                maxTrailingWidth: chatPanelWidthRange.upperBound,
                dividerThickness: chatPanelDividerWidth
            ) {
                gallery
            } trailing: {
                rightChatPanel
            }
        } else {
            gallery
        }
    }

    private var gallery: some View {
        GalleryView()
            .frame(minWidth: 480, maxWidth: .infinity)
            .ignoresSafeArea(.container, edges: ignoredWorkspaceSafeAreaEdges)
    }

    private var rightChatPanel: some View {
        ChatSidebarView(isPresented: $showsChatPanel)
            .padding(.top, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .ignoresSafeArea(.container, edges: ignoredWorkspaceSafeAreaEdges)
    }

    private var ignoredWorkspaceSafeAreaEdges: Edge.Set {
        isFullScreen ? [.bottom] : [.top, .bottom]
    }
}

private struct WindowFullScreenObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullScreen: $isFullScreen)
    }

    func makeNSView(context: Context) -> WindowTrackingView {
        let view = WindowTrackingView(frame: .zero)
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ view: WindowTrackingView, context: Context) {
        context.coordinator.isFullScreen = $isFullScreen
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.attach(to: view.window)
    }

    @MainActor
    final class Coordinator: NSObject {
        var isFullScreen: Binding<Bool>
        private weak var window: NSWindow?

        init(isFullScreen: Binding<Bool>) {
            self.isFullScreen = isFullScreen
            super.init()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to window: NSWindow?) {
            if self.window !== window {
                NotificationCenter.default.removeObserver(self)
                self.window = window
                if let window {
                    addObservers(for: window)
                }
            }
            update(from: window)
        }

        private func addObservers(for window: NSWindow) {
            let center = NotificationCenter.default
            center.addObserver(
                self,
                selector: #selector(windowFullScreenStateChanged(_:)),
                name: NSWindow.didEnterFullScreenNotification,
                object: window
            )
            center.addObserver(
                self,
                selector: #selector(windowFullScreenStateChanged(_:)),
                name: NSWindow.didExitFullScreenNotification,
                object: window
            )
        }

        @objc private func windowFullScreenStateChanged(_ notification: Notification) {
            update(from: notification.object as? NSWindow)
        }

        private func update(from window: NSWindow?) {
            let nextValue = window?.styleMask.contains(.fullScreen) ?? false
            if isFullScreen.wrappedValue != nextValue {
                isFullScreen.wrappedValue = nextValue
            }
        }
    }

    final class WindowTrackingView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct InvisibleDividerSplitView<Leading: View, Trailing: View>: NSViewRepresentable {
    let minLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let idealTrailingWidth: CGFloat
    let maxTrailingWidth: CGFloat
    let dividerThickness: CGFloat
    let leading: Leading
    let trailing: Trailing

    init(
        minLeadingWidth: CGFloat,
        minTrailingWidth: CGFloat,
        idealTrailingWidth: CGFloat,
        maxTrailingWidth: CGFloat,
        dividerThickness: CGFloat,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.minLeadingWidth = minLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.idealTrailingWidth = idealTrailingWidth
        self.maxTrailingWidth = maxTrailingWidth
        self.dividerThickness = dividerThickness
        self.leading = leading()
        self.trailing = trailing()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NoDividerNSSplitView {
        let splitView = NoDividerNSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.invisibleDividerThickness = dividerThickness
        splitView.delegate = context.coordinator

        splitView.addArrangedSubview(context.coordinator.leadingHost)
        splitView.addArrangedSubview(context.coordinator.trailingHost)
        return splitView
    }

    func updateNSView(_ splitView: NoDividerNSSplitView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.leadingHost.rootView = leading
        context.coordinator.trailingHost.rootView = trailing
        splitView.invisibleDividerThickness = dividerThickness

        DispatchQueue.main.async {
            context.coordinator.applyInitialTrailingWidth(in: splitView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: InvisibleDividerSplitView
        let leadingHost: NSHostingView<Leading>
        let trailingHost: NSHostingView<Trailing>
        private var didApplyInitialWidth = false

        init(parent: InvisibleDividerSplitView) {
            self.parent = parent
            self.leadingHost = NSHostingView(rootView: parent.leading)
            self.trailingHost = NSHostingView(rootView: parent.trailing)
            super.init()
            leadingHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
            trailingHost.setContentHuggingPriority(.required, for: .horizontal)
        }

        func applyInitialTrailingWidth(in splitView: NSSplitView) {
            guard !didApplyInitialWidth,
                  splitView.arrangedSubviews.count == 2,
                  splitView.bounds.width > 0 else {
                return
            }
            didApplyInitialWidth = true
            let available = max(0, splitView.bounds.width - splitView.dividerThickness)
            let maxInitialTrailingWidth = max(
                parent.minTrailingWidth,
                min(parent.maxTrailingWidth, available)
            )
            let trailingWidth = parent.idealTrailingWidth.clamped(
                to: parent.minTrailingWidth...maxInitialTrailingWidth
            )
            let dividerPosition = (available - trailingWidth).clamped(to: allowedDividerRange(in: splitView))
            splitView.setPosition(dividerPosition, ofDividerAt: 0)
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            allowedDividerRange(in: splitView).lowerBound
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            allowedDividerRange(in: splitView).upperBound
        }

        func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
            view == leadingHost
        }

        private func allowedDividerRange(in splitView: NSSplitView) -> ClosedRange<CGFloat> {
            let available = max(0, splitView.bounds.width - splitView.dividerThickness)
            let maxPosition = max(0, available - parent.minTrailingWidth)
            let minPosition = min(
                maxPosition,
                max(parent.minLeadingWidth, available - parent.maxTrailingWidth)
            )
            return minPosition...maxPosition
        }
    }
}

private final class NoDividerNSSplitView: NSSplitView {
    var invisibleDividerThickness: CGFloat = 12

    override var dividerThickness: CGFloat {
        invisibleDividerThickness
    }

    override var dividerColor: NSColor {
        .clear
    }

    override func drawDivider(in rect: NSRect) {}

    override func resetCursorRects() {
        super.resetCursorRects()
        guard isVertical, arrangedSubviews.count > 1 else { return }
        let leadingFrame = arrangedSubviews[0].frame
        let dividerFrame = NSRect(
            x: leadingFrame.maxX,
            y: bounds.minY,
            width: dividerThickness,
            height: bounds.height
        )
        addCursorRect(dividerFrame, cursor: .resizeLeftRight)
    }
}
