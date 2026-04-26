import Foundation

final class MetadataStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager

    init(paths: AppPaths = .shared, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func write(_ meta: ImageMetadata) throws {
        let dir = paths.metaDir(meta.projectID)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(meta.id).json")
        let data = try encoder.encode(meta)
        try data.write(to: url, options: .atomic)
    }

    func read(projectID: String, imageID: String) throws -> ImageMetadata {
        let url = paths.metaDir(projectID).appendingPathComponent("\(imageID).json")
        let data = try Data(contentsOf: url)
        return try decoder.decode(ImageMetadata.self, from: data)
    }

    func list(projectID: String) throws -> [ImageMetadata] {
        let dir = paths.metaDir(projectID)
        guard fileManager.fileExists(atPath: dir.path) else { return [] }
        let entries = try fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return entries.compactMap { url in
            try? decoder.decode(ImageMetadata.self, from: Data(contentsOf: url))
        }
    }

    func delete(projectID: String, imageID: String) throws {
        let url = paths.metaDir(projectID).appendingPathComponent("\(imageID).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - JSON

    private var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private var decoder: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}
