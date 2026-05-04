import Foundation
import Observation

/// Central source of truth for which models are currently available in the UI.
/// Merges provider-discovered model ids with the catalog's capability metadata.
@Observable
@MainActor
final class ModelRegistry {
    private(set) var imageModels: [ModelDescriptor] = []
    private(set) var chatModels: [ModelDescriptor] = []
    private(set) var unknownModels: [(provider: Provider, id: String)] = []
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshedAt: Date?
    private(set) var lastError: Error?

    var showUnknownModels: Bool = false

    private let keychain: KeychainStore
    private let catalogStore: ModelCatalogStore
    private let listers: [Provider: any ModelLister]

    init(
        keychain: KeychainStore = KeychainStore(),
        catalogStore: ModelCatalogStore = ModelCatalogStore(),
        listers: [Provider: any ModelLister] = [
            .codex: CodexModelLister()
        ]
    ) {
        self.keychain = keychain
        self.catalogStore = catalogStore
        self.listers = listers
    }

    func refresh() async {
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        let catalog = await catalogStore.loadCurrent()

        var provided: [Provider: [String]] = [:]
        for provider in Provider.allCases {
            guard let lister = listers[provider] else { continue }
            let key = keychain.apiKey(for: provider) ?? ""
            if provider.usesAPIKey && key.isEmpty { continue }
            do {
                let ids = try await lister.listAvailableModelIDs(apiKey: key)
                provided[provider] = ids
            } catch {
                lastError = error
            }
        }

        let resolver = ModelResolver(catalog: catalog)
        let resolved = resolver.resolve(providerModels: provided)
        self.imageModels = resolved.image
        self.chatModels = resolved.chat
        self.unknownModels = resolved.unknown
        self.lastRefreshedAt = Date()
    }

    func imageModels(for provider: Provider) -> [ModelDescriptor] {
        imageModels.filter { $0.provider == provider }
    }

    func chatModels(for provider: Provider) -> [ModelDescriptor] {
        chatModels.filter { $0.provider == provider }
    }
}
