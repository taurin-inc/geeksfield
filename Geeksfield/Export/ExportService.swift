import AppKit
import Foundation
import UniformTypeIdentifiers

enum ExportError: Error, LocalizedError {
    case userCancelled
    case sourceMissing(URL)

    var errorDescription: String? {
        switch self {
        case .userCancelled: return "사용자가 취소했습니다."
        case .sourceMissing(let u): return "원본 파일이 없습니다: \(u.path)"
        }
    }
}

/// Thin wrappers around NSSavePanel / NSOpenPanel. All panels must run on the
/// main thread; callers use `await` from the main actor.
@MainActor
enum ExportService {
    /// Single-file export: prompts NSSavePanel and copies the PNG.
    @discardableResult
    static func exportSingle(source: URL, suggestedName: String? = nil) async throws -> URL {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ExportError.sourceMissing(source)
        }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName ?? source.lastPathComponent

        guard panel.runModal() == .OK, let destination = panel.url else {
            throw ExportError.userCancelled
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Multi-file export: prompts for a destination folder and copies each source
    /// preserving its filename.
    @discardableResult
    static func exportMany(sources: [URL]) async throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "여기에 저장"

        guard panel.runModal() == .OK, let destination = panel.url else {
            throw ExportError.userCancelled
        }

        let fm = FileManager.default
        for source in sources {
            guard fm.fileExists(atPath: source.path) else { continue }
            let target = destination.appendingPathComponent(source.lastPathComponent)
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: source, to: target)
        }
        return destination
    }

    /// Copies a project's entire drafts/ + picked/ tree into a user-chosen
    /// folder. We preserve the two-level structure so the export is re-openable.
    @discardableResult
    static func exportProject(draftsDir: URL, pickedDir: URL, projectName: String) async throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "여기에 저장"

        guard panel.runModal() == .OK, let root = panel.url else {
            throw ExportError.userCancelled
        }

        let fm = FileManager.default
        let exportRoot = root.appendingPathComponent(projectName, isDirectory: true)
        try fm.createDirectory(at: exportRoot, withIntermediateDirectories: true)

        for (name, src) in [("drafts", draftsDir), ("picked", pickedDir)] {
            guard fm.fileExists(atPath: src.path) else { continue }
            let target = exportRoot.appendingPathComponent(name, isDirectory: true)
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: src, to: target)
        }
        return exportRoot
    }
}
