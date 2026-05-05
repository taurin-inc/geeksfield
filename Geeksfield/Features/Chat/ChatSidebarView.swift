import SwiftUI

struct ChatSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if appState.chatMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.chatMessages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: appState.chatMessages.count) { _, _ in
                if let last = appState.chatMessages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField(appState.l10n.message, text: $input, axis: .vertical)
                .font(.callout)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            Button {
                submit()
            } label: {
                if appState.isChatBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)

            Text(appState.l10n.startConversation)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(appState.l10n.chatUsesCodex)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 60)
    }

    private var canSubmit: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty
            && appState.defaultChatModel != nil
            && !appState.isChatBusy
    }

    private func submit() {
        guard let model = appState.defaultChatModel else {
            appState.errorBus.report(
                title: appState.l10n.codexLoginRequired,
                message: appState.l10n.enterKeyInSettings
            )
            return
        }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.sendChat(text: text, model: model)
        input = ""
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 32) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubbleBody
                metaRow
            }

            if message.role == .assistant { Spacer(minLength: 32) }
        }
    }

    @ViewBuilder
    private var bubbleBody: some View {
        Text(message.content)
            .font(.body)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var bubbleBackground: AnyShapeStyle {
        if message.role == .user {
            AnyShapeStyle(Color.accentColor.opacity(0.22))
        } else {
            AnyShapeStyle(.regularMaterial)
        }
    }

    @ViewBuilder
    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(appState.l10n.time(message.createdAt))
            if message.role == .assistant, let model = message.modelID {
                Text("·")
                Text(model)
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
    }
}
