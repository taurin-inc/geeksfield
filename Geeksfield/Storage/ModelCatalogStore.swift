import Foundation

enum ModelCatalogError: Error {
    case bundleResourceMissing
    case decodeFailed
}

/// Sources the model catalog from the bundled resource first. The app is Codex
/// only, so remote/catalog cache data from earlier OpenAI/Gemini builds must
/// not override the packaged catalog.
final class ModelCatalogStore: @unchecked Sendable {
    let paths: AppPaths
    let bundle: Bundle
    let fileManager: FileManager

    init(
        paths: AppPaths = .shared,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.bundle = bundle
        self.fileManager = fileManager
    }

    /// Returns the most current catalog available. Always returns *some* catalog.
    func loadCurrent() async -> ModelCatalog {
        if let bundled = try? readBundled() {
            return bundled
        }
        if let cached = try? readCache() {
            return cached
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

    // MARK: - Cache

    func writeCache(_ catalog: ModelCatalog) throws {
        try paths.ensureSkeleton()
        let data = try encoder.encode(catalog)
        try data.write(to: paths.catalogCacheFile, options: .atomic)
    }

    private var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }

    private var decoder: JSONDecoder { JSONDecoder() }
}
