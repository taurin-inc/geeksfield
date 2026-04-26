import Foundation

protocol ChatProvider: Sendable {
    var provider: Provider { get }
    func send(messages: [ChatMessage], modelID: String, apiKey: String) async throws -> ChatMessage
}
