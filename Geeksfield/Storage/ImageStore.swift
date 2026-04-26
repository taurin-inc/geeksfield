import Foundation

enum ImageStoreError: Error {
    case fileNotFound(URL)
}

final class ImageStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager

    init(paths: AppPaths = .shared, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func savePNG(
        data: Data,
        projectID: String,
        imageID: String,
        status: ImageStatus,
        createdAt: Date = Date()
    ) throws -> URL {
        // If the bytes aren't a well-formed PNG with an IDAT chunk we can write
        // the raw payload — users can still open the file, they just miss the
        // embedded id tag.
        let withID = (try? PNGMetadata.write(textEntries: ["geeksfield.id": imageID], into: data)) ?? data
        let url = fileURL(projectID: projectID, imageID: imageID, status: status, createdAt: createdAt)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try withID.write(to: url, options: .atomic)
        return url
    }

    func move(projectID: String, imageID: String, to newStatus: ImageStatus) throws -> URL {
        guard let current = try locate(projectID: projectID, imageID: imageID) else {
            throw ImageStoreError.fileNotFound(paths.projectRoot(projectID))
        }
        let newDir: URL
        switch newStatus {
        case .draft: newDir = paths.draftsDir(projectID)
        case .picked: newDir = paths.pickedDir(projectID)
        case .failed, .pending: return current
        }
        try fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
        let destination = newDir.appendingPathComponent(current.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: current, to: destination)
        return destination
    }

    func trash(projectID: String, imageID: String) throws {
        guard let url = try locate(projectID: projectID, imageID: imageID) else { return }
        var resulting: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resulting)
    }

    func locate(projectID: String, imageID: String) throws -> URL? {
        // Filenames carry only the first 8 hex chars of the imageID (see fileURL
        // below), so we have to match on that prefix — not the full UUID.
        let short = String(imageID.prefix(8))
        for dir in [paths.draftsDir(projectID), paths.pickedDir(projectID)] {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            let entries = try fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            if let match = entries.first(where: { $0.lastPathComponent.contains(short) }) {
                return match
            }
        }
        return nil
    }

    // MARK: - Filenames

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    func fileURL(projectID: String, imageID: String, status: ImageStatus, createdAt: Date) -> URL {
        let dir: URL
        switch status {
        case .draft: dir = paths.draftsDir(projectID)
        case .picked: dir = paths.pickedDir(projectID)
        case .failed, .pending: dir = paths.draftsDir(projectID)
        }
        let short = String(imageID.prefix(8))
        let stamp = Self.stampFormatter.string(from: createdAt)
        return dir.appendingPathComponent("\(stamp)_\(short).png")
    }
}
