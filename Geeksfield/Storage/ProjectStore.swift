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
        if results.contains(where: { $0.sortIndex != nil }) {
            return results.sorted {
                let left = $0.sortIndex ?? Int.max
                let right = $1.sortIndex ?? Int.max
                if left != right { return left < right }
                return $0.createdAt < $1.createdAt
            }
        }
        return results.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createProject(name: String) throws -> Project {
        let nextIndex = ((try? listProjects().compactMap(\.sortIndex).max()) ?? -1) + 1
        let project = Project.makeNew(name: name, sortIndex: nextIndex)
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

    func reorderProjects(ids: [String]) throws {
        for (index, id) in ids.enumerated() {
            var project = try readProject(from: paths.projectJSON(id))
            project.sortIndex = index
            try writeProject(project)
        }
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
