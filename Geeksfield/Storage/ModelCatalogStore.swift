import Foundation

enum ModelCatalogError: Error {
    case bundleResourceMissing
    case decodeFailed
}

/// Sources the model catalog from three places with a fallback chain:
///   1. remote URL (network)
///   2. on-disk cache (~/.../catalog/model_catalog.json)
///   3. bundled resource
///
/// Remote fetches that fail silently fall back to the next source.
final class ModelCatalogStore: @unchecked Sendable {
    let paths: AppPaths
    let bundle: Bundle
    let fileManager: FileManager
    let remoteURL: URL
    let cacheTTL: TimeInterval
    let session: URLSession

    init(
        paths: AppPaths = .shared,
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        remoteURL: URL = URL(string: "https://raw.githubusercontent.com/geeksfield/app/main/catalog/model_catalog.json")!,
        cacheTTL: TimeInterval = 3600,
        session: URLSession = .shared
    ) {
        self.paths = paths
        self.bundle = bundle
        self.fileManager = fileManager
        self.remoteURL = remoteURL
        self.cacheTTL = cacheTTL
        self.session = session
    }

    /// Returns the most current catalog available. Always returns *some* catalog.
    func loadCurrent() async -> ModelCatalog {
        if let remote = try? await fetchRemote() {
            try? writeCache(remote)
            return remote
        }
        if let cached = try? readCache(), !cacheExpired() {
            return cached
        }
        if let cached = try? readCache() {
            return cached
        }
        if let bundled = try? readBundled() {
            return bundled
        }
        // The bundled file is packaged with the app; if we cannot read it
        // something is broken but we can still return an empty stub rather
        // than crash startup.
        return ModelCatalog(version: "unknown", imageModels: [], chatModels: [])
    }

    // MARK: - Sources

    func readBundled() throws -> ModelCatalog {
        guard let url = bundle.url(forResource: "model_catalog", withExtension: "json") else {
            throw ModelCatalogError.bundleResourceMissing
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(ModelCatalog.self, from: data)
    }

    func readCache() throws -> ModelCatalog {
        let url = paths.catalogCacheFile
        let data = try Data(contentsOf: url)
        return try decoder.decode(ModelCatalog.self, from: data)
    }

    func fetchRemote() async throws -> ModelCatalog {
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ModelCatalogError.decodeFailed
        }
        return try decoder.decode(ModelCatalog.self, from: data)
    }

    // MARK: - Cache

    func writeCache(_ catalog: ModelCatalog) throws {
        try paths.ensureSkeleton()
        let data = try encoder.encode(catalog)
        try data.write(to: paths.catalogCacheFile, options: .atomic)
    }

    func cacheExpired() -> Bool {
        let url = paths.catalogCacheFile
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date else { return true }
        return Date().timeIntervalSince(mtime) > cacheTTL
    }

    private var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }

    private var decoder: JSONDecoder { JSONDecoder() }
}
