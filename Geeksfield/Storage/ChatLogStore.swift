import Foundation

final class ChatLogStore: @unchecked Sendable {
    let paths: AppPaths
    let fileManager: FileManager

    init(paths: AppPaths = .shared, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func append(_ message: ChatMessage, to sessionID: String) throws {
        try paths.ensureSkeleton()
        let url = paths.chatSessionLog(sessionID)
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

    func readMessages(for sessionID: String) throws -> [ChatMessage] {
        try readMessages(at: paths.chatSessionLog(sessionID))
    }

    func loadSessions() throws -> [ChatSession] {
        try migrateLegacyLogIfNeeded()
        let url = paths.chatSessionsIndex
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([ChatSession].self, from: data)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveSessions(_ sessions: [ChatSession]) throws {
        try paths.ensureSkeleton()
        let data = try encoder.encode(sessions.sorted { $0.updatedAt > $1.updatedAt })
        try data.write(to: paths.chatSessionsIndex, options: .atomic)
    }

    func createSession(title: String, at date: Date = Date()) throws -> ChatSession {
        var sessions = try loadSessions()
        let session = ChatSession(
            id: UUID().uuidString.lowercased(),
            title: title,
            createdAt: date,
            updatedAt: date
        )
        sessions.insert(session, at: 0)
        try saveSessions(sessions)
        return session
    }

    private func migrateLegacyLogIfNeeded() throws {
        let index = paths.chatSessionsIndex
        guard !fileManager.fileExists(atPath: index.path),
              fileManager.fileExists(atPath: paths.chatLog.path) else { return }

        let messages = try readMessages(at: paths.chatLog)
        guard !messages.isEmpty else {
            try saveSessions([])
            return
        }

        let createdAt = messages.first?.createdAt ?? Date()
        let updatedAt = messages.last?.createdAt ?? createdAt
        let title = firstAssistantTitle(in: messages) ?? "Previous conversation"
        let session = ChatSession(
            id: UUID().uuidString.lowercased(),
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        try saveSessions([session])
        for message in messages {
            try append(message, to: session.id)
        }
    }

    private func readMessages(at url: URL) throws -> [ChatMessage] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(ChatMessage.self, from: d)
        }
    }

    private func firstAssistantTitle(in messages: [ChatMessage]) -> String? {
        guard let text = messages.first(where: { $0.role == .assistant })?.content
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        return String(firstLine.prefix(36))
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
