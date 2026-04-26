import Foundation

@MainActor
final class ChatOrchestrator {
    let providers: [Provider: any ChatProvider]
    let log: ChatLogStore
    let keychain: KeychainStore

    init(
        providers: [Provider: any ChatProvider] = [
            .openai: OpenAIChatProvider(),
            .gemini: GeminiChatProvider()
        ],
        log: ChatLogStore = ChatLogStore(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.providers = providers
        self.log = log
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
        guard let apiKey = keychain.apiKey(for: model.provider), !apiKey.isEmpty else {
            throw ChatOrchestratorError.missingAPIKey(model.provider)
        }

        try? log.append(userMessage)

        let reply = try await provider.send(
            messages: history + [userMessage],
            modelID: model.id,
            apiKey: apiKey
        )
        try? log.append(reply)
        return reply
    }
}

enum ChatOrchestratorError: Error, LocalizedError {
    case unsupportedProvider(Provider)
    case missingAPIKey(Provider)

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let p): return "Unsupported provider: \(p.displayName)"
        case .missingAPIKey(let p): return "Missing API key for \(p.displayName)"
        }
    }
}
