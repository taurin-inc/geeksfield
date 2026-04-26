import Foundation

enum ProjectStoreError: Error {
    case projectNotFound(String)
}

final class ProjectStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager

    init(paths: AppPaths = .shared, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func listProjects() throws -> [Project] {
        try paths.ensureSkeleton()
        let entries = (try? fileManager.contentsOfDirectory(
            at: paths.projectsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        var results: [Project] = []
        for dir in entries {
            let jsonURL = paths.projectJSON(dir.lastPathComponent)
            guard let project = try? readProject(from: jsonURL) else { continue }
            results.append(project)
        }
        return results.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createProject(name: String) throws -> Project {
        let project = Project.makeNew(name: name)
        try paths.ensureProjectSkeleton(project.id)
        try writeProject(project)
        return project
    }

    func renameProject(id: String, to name: String) throws -> Project {
        var project = try readProject(from: paths.projectJSON(id))
        project.name = name
        project.updatedAt = Date()
        try writeProject(project)
        return project
    }

    func deleteProject(id: String) throws {
        let root = paths.projectRoot(id)
        guard fileManager.fileExists(atPath: root.path) else {
            throw ProjectStoreError.projectNotFound(id)
        }
        var resulting: NSURL?
        try fileManager.trashItem(at: root, resultingItemURL: &resulting)
    }

    // MARK: - Private

    private func readProject(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        return try jsonDecoder().decode(Project.self, from: data)
    }

    private func writeProject(_ project: Project) throws {
        try paths.ensureProjectSkeleton(project.id)
        let data = try jsonEncoder().encode(project)
        try data.write(to: paths.projectJSON(project.id), options: .atomic)
    }

    private func jsonEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private func jsonDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}
