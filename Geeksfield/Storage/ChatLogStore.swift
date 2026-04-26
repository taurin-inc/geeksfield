import Foundation

final class ChatLogStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager

    init(paths: AppPaths = .shared, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func append(_ message: ChatMessage) throws {
        try paths.ensureSkeleton()
        let url = paths.chatLog
        let data = try encoder.encode(message)
        var line = data
        line.append(0x0A)
        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            try line.write(to: url, options: .atomic)
        }
    }

    func readAll() throws -> [ChatMessage] {
        let url = paths.chatLog
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(ChatMessage.self, from: d)
        }
    }

    private var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private var decoder: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }
}
