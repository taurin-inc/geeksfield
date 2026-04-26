import SwiftUI

struct ChatSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            inputBar
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            ChatModelSelector()
            Spacer()
            if appState.isChatBusy {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassEffect(.regular)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if appState.chatMessages.isEmpty {
                        ContentUnavailableView(
                            "대화를 시작하세요",
                            systemImage: "bubble.left.and.text.bubble.right",
                            description: Text("모델을 선택한 뒤 메시지를 입력하세요.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
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
            TextField("메시지", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            Button {
                submit()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(10)
    }

    private var canSubmit: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty
            && appState.selectedChatModel != nil
            && !appState.isChatBusy
    }

    private func submit() {
        guard let model = appState.selectedChatModel else {
            appState.errorBus.report(
                title: "채팅 모델 필요",
                message: appState.modelRegistry.chatModels.isEmpty
                    ? "설정 > API Keys에서 키를 먼저 입력하세요."
                    : "위 모델 메뉴에서 채팅 모델을 선택하세요."
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
            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
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
