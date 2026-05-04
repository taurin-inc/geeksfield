import Foundation

struct CodexModelLister: ModelLister {
    let provider: Provider = .codex
    let authStore: CodexAuthStore

    init(authStore: CodexAuthStore = CodexAuthStore()) {
        self.authStore = authStore
    }

    func listAvailableModelIDs(apiKey: String) async throws -> [String] {
        _ = apiKey
        _ = try authStore.load()
        return ["gpt-5.4"]
    }
}
