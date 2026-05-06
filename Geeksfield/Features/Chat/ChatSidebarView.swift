import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ChatSidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var input: String = ""
    @State private var inputHeight: CGFloat = 22
    @State private var attachments: [ChatAttachment] = []
    @State private var commandReturnMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            inputBar
        }
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .onPasteCommand(of: [.image]) { providers in
                loadPastedImages(from: providers, receive: addPastedAttachments)
            }
            .onAppear {
                installCommandReturnMonitor()
            }
            .onDisappear {
                removeCommandReturnMonitor()
            }
    }

    private var header: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(appState.l10n.hideChatPanel)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
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
        VStack(alignment: .leading, spacing: 8) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachments) { attachment in
                            attachmentThumb(attachment)
                        }
                    }
                }
                .frame(height: 50)
            }

            HStack(alignment: .bottom, spacing: 8) {
                MultilineTextEditor(
                    text: $input,
                    contentHeight: $inputHeight,
                    font: chatInputFont,
                    minHeight: 22,
                    maxHeight: 110,
                    placeholder: appState.l10n.message,
                    onPasteImages: addPastedAttachments,
                    onCommandReturn: submit,
                    onFocusChange: { focused in
                        if focused {
                            appState.focusedInput = .chat
                        } else if appState.focusedInput == .chat {
                            appState.focusedInput = nil
                        }
                    }
                )
                .frame(height: inputHeight)
                .frame(minHeight: 38)
                .padding(.leading, 14)
                .padding(.vertical, 5)

                Button {
                    submit()
                } label: {
                    ZStack {
                        if appState.isChatBusy {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .frame(width: 34, height: 34)
                    .foregroundStyle(canSubmit ? Color.white : Color.secondary)
                    .background(
                        Circle()
                            .fill(canSubmit ? Color.accentColor.opacity(0.75) : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.trailing, 10)
            .padding(.top, 5)
            .padding(.bottom, 10)
        }
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
        (!input.trimmingCharacters(in: .whitespaces).isEmpty || !attachments.isEmpty)
            && appState.defaultChatModel != nil
            && !appState.isChatBusy
    }

    private var chatInputFont: NSFont {
        .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
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
        guard !text.isEmpty || !attachments.isEmpty else { return }
        appState.sendChat(text: text, model: model, attachments: attachments)
        input = ""
        attachments = []
        inputHeight = 22
    }

    private func addPastedAttachments(_ payloads: [PastedImagePayload]) {
        let newAttachments = payloads.compactMap {
            appState.makeChatAttachment(data: $0.data, preferredExtension: $0.preferredExtension)
        }
        attachments.append(contentsOf: newAttachments)
    }

    private func attachmentThumb(_ attachment: ChatAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            LocalImage(url: URL(fileURLWithPath: attachment.path), contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }

            Button {
                attachments.removeAll { $0.id == attachment.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(Circle().fill(Color.black.opacity(0.72)))
            }
            .buttonStyle(.plain)
            .padding(3)
        }
    }

    private func loadPastedImages(
        from providers: [NSItemProvider],
        receive: @MainActor @Sendable @escaping ([PastedImagePayload]) -> Void
    ) {
        for provider in providers {
            guard let type = preferredImageType(for: provider) else { continue }
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                guard let data else { return }
                let payload = PastedImagePayload(
                    data: data,
                    preferredExtension: type.preferredFilenameExtension ?? "png"
                )
                Task { @MainActor in
                    receive([payload])
                }
            }
        }
    }

    private func preferredImageType(for provider: NSItemProvider) -> UTType? {
        [.png, .jpeg, .heic, .tiff, .image].first {
            provider.hasItemConformingToTypeIdentifier($0.identifier)
        }
    }

    private func installCommandReturnMonitor() {
        guard commandReturnMonitor == nil else { return }
        commandReturnMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard appState.focusedInput == .chat,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
                  event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n" else {
                return event
            }
            submit()
            return nil
        }
    }

    private func removeCommandReturnMonitor() {
        if let commandReturnMonitor {
            NSEvent.removeMonitor(commandReturnMonitor)
            self.commandReturnMonitor = nil
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 32) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if !message.content.isEmpty {
                    bubbleBody
                }
                attachmentStrip
                metaRow
            }

            if message.role == .assistant { Spacer(minLength: 32) }
        }
    }

    @ViewBuilder
    private var attachmentStrip: some View {
        if !message.attachments.isEmpty {
            HStack(spacing: 6) {
                ForEach(message.attachments) { attachment in
                    LocalImage(url: URL(fileURLWithPath: attachment.path), contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
    }

    @ViewBuilder
    private var bubbleBody: some View {
        Text(message.content)
            .font(.body)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
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
