import Foundation

@MainActor
final class ChatOrchestrator {
    let providers: [Provider: any ChatProvider]
    let keychain: KeychainStore

    init(
        providers: [Provider: any ChatProvider] = [
            .codex: CodexChatProvider()
        ],
        keychain: KeychainStore = KeychainStore()
    ) {
        self.providers = providers
        self.keychain = keychain
    }

    func send(
        history: [ChatMessage],
        userMessage: ChatMessage,
        model: ModelDescriptor
    ) async throws -> ChatMessage {
        guard let provider = providers[model.provider] else {
            throw ChatOrchestratorError.unsupportedProvider(model.provider)
        }
        let apiKey = keychain.apiKey(for: model.provider) ?? ""
        guard !model.provider.usesAPIKey || !apiKey.isEmpty else {
            throw ChatOrchestratorError.missingAPIKey(model.provider)
        }

        let reply = try await provider.send(
            messages: history + [userMessage],
            modelID: model.id,
            apiKey: apiKey
        )
        return reply
    }

    func generateTitle(
        userMessage: ChatMessage,
        assistantMessage: ChatMessage,
        model: ModelDescriptor
    ) async throws -> String {
        guard let provider = providers[model.provider] else {
            throw ChatOrchestratorError.unsupportedProvider(model.provider)
        }
        let apiKey = keychain.apiKey(for: model.provider) ?? ""
        guard !model.provider.usesAPIKey || !apiKey.isEmpty else {
            throw ChatOrchestratorError.missingAPIKey(model.provider)
        }

        let prompt = """
        Create a concise chat title for this conversation.
        Rules:
        - Return only the title.
        - Use the same language as the conversation.
        - Do not quote the user's message verbatim.
        - Keep it under 8 words.

        User:
        \(userMessage.content)

        Assistant:
        \(assistantMessage.content)
        """
        let titleRequest = ChatMessage(
            id: UUID().uuidString.lowercased(),
            role: .user,
            content: prompt,
            createdAt: Date(),
            provider: model.provider,
            modelID: model.id,
            attachments: []
        )
        let reply = try await provider.send(messages: [titleRequest], modelID: model.id, apiKey: apiKey)
        return sanitizeTitle(reply.content)
    }

    private func sanitizeTitle(_ title: String) -> String {
        let trimmed = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`*_# "))
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let sentence = firstLine
            .replacingOccurrences(of: "Title:", with: "")
            .replacingOccurrences(of: "제목:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(sentence.prefix(40))
    }
}

enum ChatOrchestratorError: Error, LocalizedError {
    case unsupportedProvider(Provider)
    case missingAPIKey(Provider)

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let p): return "Unsupported provider: \(p.displayName)"
        case .missingAPIKey(let p): return "Missing credentials for \(p.displayName)"
        }
    }
}
