import Foundation

enum TrashService {
    static func trash(_ url: URL, fileManager: FileManager = .default) throws {
        var resulting: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resulting)
    }
}
