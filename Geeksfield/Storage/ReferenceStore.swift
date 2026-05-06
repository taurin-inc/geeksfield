import Foundation

final class ReferenceStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager

    init(paths: AppPaths = .shared, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    /// Copy an external file into the project's refs/ directory, returning the new id.
    @discardableResult
    func ingestExternal(projectID: String, sourceURL: URL) throws -> String {
        let dir = paths.refsDir(projectID)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let refID = "ref_" + String(UUID().uuidString.prefix(8).lowercased())
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let dest = dir.appendingPathComponent("\(refID).\(ext)")
        try fileManager.copyItem(at: sourceURL, to: dest)
        return refID
    }

    @discardableResult
    func ingestData(projectID: String, data: Data, preferredExtension: String = "png") throws -> String {
        let dir = paths.refsDir(projectID)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let refID = "ref_" + String(UUID().uuidString.prefix(8).lowercased())
        let ext = preferredExtension.isEmpty ? "png" : preferredExtension
        let dest = dir.appendingPathComponent("\(refID).\(ext)")
        try data.write(to: dest, options: .atomic)
        return refID
    }

    func url(projectID: String, refID: String) -> URL? {
        let dir = paths.refsDir(projectID)
        let entries = (try? fileManager.contentsOfDirectory(atPath: dir.path)) ?? []
        if let match = entries.first(where: { $0.hasPrefix(refID) }) {
            return dir.appendingPathComponent(match)
        }
        return nil
    }
}
