import Foundation

enum AppPathsError: Error {
    case applicationSupportUnavailable
}

struct AppPaths: Sendable {
    let root: URL

    static let shared: AppPaths = {
        do {
            return try AppPaths.resolve()
        } catch {
            fatalError("Application Support directory unavailable: \(error)")
        }
    }()

    static func resolve(fileManager: FileManager = .default) throws -> AppPaths {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("Geeksfield", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return AppPaths(root: root)
    }

    var projectsDir: URL { root.appendingPathComponent("projects", isDirectory: true) }
    var chatDir: URL { root.appendingPathComponent("chat", isDirectory: true) }
    var catalogDir: URL { root.appendingPathComponent("catalog", isDirectory: true) }
    var appJSON: URL { root.appendingPathComponent("app.json") }
    var chatLog: URL { chatDir.appendingPathComponent("messages.jsonl") }
    var chatAttachmentsDir: URL { chatDir.appendingPathComponent("attachments", isDirectory: true) }
    var catalogCacheFile: URL { catalogDir.appendingPathComponent("model_catalog.json") }

    func projectRoot(_ projectID: String) -> URL {
        projectsDir.appendingPathComponent(projectID, isDirectory: true)
    }

    func draftsDir(_ projectID: String) -> URL {
        projectRoot(projectID).appendingPathComponent("drafts", isDirectory: true)
    }

    func pickedDir(_ projectID: String) -> URL {
        projectRoot(projectID).appendingPathComponent("picked", isDirectory: true)
    }

    func privateDir(_ projectID: String) -> URL {
        projectRoot(projectID).appendingPathComponent(".geeksfield", isDirectory: true)
    }

    func projectJSON(_ projectID: String) -> URL {
        privateDir(projectID).appendingPathComponent("project.json")
    }

    func metaDir(_ projectID: String) -> URL {
        privateDir(projectID).appendingPathComponent("meta", isDirectory: true)
    }

    func thumbsDir(_ projectID: String) -> URL {
        privateDir(projectID).appendingPathComponent("thumbs", isDirectory: true)
    }

    func refsDir(_ projectID: String) -> URL {
        privateDir(projectID).appendingPathComponent("refs", isDirectory: true)
    }

    func ensureSkeleton() throws {
        let fm = FileManager.default
        for dir in [projectsDir, chatDir, chatAttachmentsDir, catalogDir] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func ensureProjectSkeleton(_ projectID: String) throws {
        let fm = FileManager.default
        for dir in [
            projectRoot(projectID),
            draftsDir(projectID),
            pickedDir(projectID),
            privateDir(projectID),
            metaDir(projectID),
            thumbsDir(projectID),
            refsDir(projectID)
        ] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
