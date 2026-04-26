import Foundation

struct ResolvedModels: Sendable {
    let image: [ModelDescriptor]
    let chat: [ModelDescriptor]
    let unknown: [(provider: Provider, id: String)]
}

final class ModelResolver: @unchecked Sendable {
    let catalog: ModelCatalog

    init(catalog: ModelCatalog) {
        self.catalog = catalog
    }

    func resolve(providerModels: [Provider: [String]]) -> ResolvedModels {
        var image: [ModelDescriptor] = []
        var chat: [ModelDescriptor] = []
        var unknown: [(Provider, String)] = []

        for (provider, ids) in providerModels {
            for id in ids {
                if let entry = matchImageEntry(provider: provider, id: id) {
                    image.append(makeImageDescriptor(id: id, entry: entry))
                } else if let entry = matchChatEntry(provider: provider, id: id) {
                    chat.append(makeChatDescriptor(id: id, entry: entry))
                } else {
                    unknown.append((provider, id))
                }
            }
        }

        image.sort { lhs, rhs in
            lhs.provider == rhs.provider ? lhs.id < rhs.id : lhs.provider.rawValue < rhs.provider.rawValue
        }
        chat.sort { lhs, rhs in
            lhs.provider == rhs.provider ? lhs.id < rhs.id : lhs.provider.rawValue < rhs.provider.rawValue
        }

        return ResolvedModels(image: image, chat: chat, unknown: unknown)
    }

    // MARK: - Matching

    private func matchImageEntry(provider: Provider, id: String) -> ImageModelEntry? {
        for entry in catalog.imageModels where entry.provider == provider {
            if matches(id: id, include: entry.idPatterns, exclude: entry.excludePatterns) {
                return entry
            }
        }
        return nil
    }

    private func matchChatEntry(provider: Provider, id: String) -> ChatModelEntry? {
        for entry in catalog.chatModels where entry.provider == provider {
            if matches(id: id, include: entry.idPatterns, exclude: entry.excludePatterns) {
                return entry
            }
        }
        return nil
    }

    private func matches(id: String, include: [String], exclude: [String]?) -> Bool {
        if let exclude, exclude.contains(where: { Self.glob($0, matches: id) }) {
            return false
        }
        return include.contains(where: { Self.glob($0, matches: id) })
    }

    // MARK: - Builders

    private func makeImageDescriptor(id: String, entry: ImageModelEntry) -> ModelDescriptor {
        let sizes = entry.sizes.compactMap { Size.parse($0) }
        let spec = ImageSpec(
            sizes: sizes,
            aspectRatios: entry.aspectRatios,
            maxBatch: entry.maxBatch,
            supportsInpaint: entry.supportsInpaint,
            supportsReference: entry.supportsReference
        )
        return ModelDescriptor(
            id: id,
            provider: entry.provider,
            displayName: render(template: entry.displayNameTemplate, id: id),
            capability: .image(spec)
        )
    }

    private func makeChatDescriptor(id: String, entry: ChatModelEntry) -> ModelDescriptor {
        let spec = ChatSpec(supportsVision: entry.supportsVision, contextWindow: entry.contextWindow)
        return ModelDescriptor(
            id: id,
            provider: entry.provider,
            displayName: render(template: entry.displayNameTemplate, id: id),
            capability: .chat(spec)
        )
    }

    private func render(template: String, id: String) -> String {
        template.replacingOccurrences(of: "{id}", with: id)
    }

    // MARK: - Glob

    /// Minimal glob supporting `*` (any chars) and `?` (single char). Anchored full-string match.
    static func glob(_ pattern: String, matches input: String) -> Bool {
        let p = Array(pattern)
        let s = Array(input)
        return globMatch(p, 0, s, 0)
    }

    private static func globMatch(_ p: [Character], _ pi: Int, _ s: [Character], _ si: Int) -> Bool {
        if pi == p.count { return si == s.count }
        let c = p[pi]
        if c == "*" {
            if pi + 1 == p.count { return true }
            for j in si...s.count {
                if globMatch(p, pi + 1, s, j) { return true }
            }
            return false
        }
        if si == s.count { return false }
        if c == "?" || c == s[si] {
            return globMatch(p, pi + 1, s, si + 1)
        }
        return false
    }
}
