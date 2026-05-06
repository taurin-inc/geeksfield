import Foundation

struct CodexChatProvider: ChatProvider {
    let provider: Provider = .codex
    let endpoint: URL
    let session: URLSession
    let authStore: CodexAuthStore

    init(
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/codex/responses")!,
        session: URLSession = .shared,
        authStore: CodexAuthStore = CodexAuthStore()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.authStore = authStore
    }

    func send(messages: [ChatMessage], modelID: String, apiKey: String) async throws -> ChatMessage {
        _ = apiKey
        let auth = try authStore.load()
        let prompt = Self.transcript(from: messages)
        let inputContent = try Self.messageContent(prompt: prompt, attachments: messages.last?.attachments ?? [])
        let body: [String: Any] = [
            "model": modelID,
            "instructions": "You are a concise assistant inside an image generation workspace.",
            "input": [
                [
                    "type": "message",
                    "role": "user",
                    "content": inputContent
                ]
            ],
            "parallel_tool_calls": false,
            "reasoning": NSNull(),
            "store": false,
            "stream": true,
            "include": ["reasoning.encrypted_content"]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "session_id")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 180

        let content = try await streamText(for: request)
        return ChatMessage(
            id: UUID().uuidString.lowercased(),
            role: .assistant,
            content: content,
            createdAt: Date(),
            provider: .codex,
            modelID: modelID,
            attachments: []
        )
    }

    private func streamText(for request: URLRequest) async throws -> String {
        let (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 2_000 { break }
            }
            throw ImageProviderError.http(http.statusCode, body)
        }

        var eventLines: [String] = []
        var accumulated = ""
        var completedText: String?
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                let parsed = try parseEvent(lines: eventLines)
                accumulated += parsed.delta ?? ""
                if let final = parsed.finalText, !final.isEmpty {
                    completedText = final
                }
                if parsed.completed { break }
                eventLines.removeAll(keepingCapacity: true)
            } else {
                eventLines.append(line)
            }
        }

        let parsed = try parseEvent(lines: eventLines)
        accumulated += parsed.delta ?? ""
        if let final = parsed.finalText, !final.isEmpty {
            completedText = final
        }

        let text = (completedText ?? accumulated).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ImageProviderError.unsupportedOperation("Codex returned no chat text.")
        }
        return text
    }

    private func parseEvent(lines: [String]) throws -> (delta: String?, finalText: String?, completed: Bool) {
        let dataLines = lines
            .filter { $0.hasPrefix("data:") }
            .map { line in
                let index = line.index(line.startIndex, offsetBy: 5)
                return String(line[index...]).trimmingCharacters(in: .whitespaces)
            }
        guard !dataLines.isEmpty else { return (nil, nil, false) }

        let objects = Self.parseSSEDataLines(dataLines)
        var delta = ""
        var finalText: String?
        var completed = false
        for object in objects {
            if let message = Self.findErrorMessage(in: object) {
                throw ImageProviderError.unsupportedOperation(message)
            }
            delta += Self.findTextDelta(in: object) ?? ""
            if let text = Self.findFinalText(in: object), !text.isEmpty {
                finalText = text
            }
            completed = completed || Self.containsResponseCompleted(in: object)
        }
        return (delta.isEmpty ? nil : delta, finalText, completed)
    }

    private static func transcript(from messages: [ChatMessage]) -> String {
        messages.suffix(24).map { message in
            let attachmentLabel = message.attachments.isEmpty ? "" : " [\(message.attachments.count) image attachment(s)]"
            return "\(roleLabel(message.role)): \(message.content)\(attachmentLabel)"
        }
        .joined(separator: "\n\n")
    }

    private static func messageContent(prompt: String, attachments: [ChatAttachment]) throws -> [[String: Any]] {
        var content: [[String: Any]] = [
            ["type": "input_text", "text": prompt]
        ]
        for attachment in attachments {
            let url = URL(fileURLWithPath: attachment.path)
            let data = try Data(contentsOf: url)
            let mimeType = attachment.mimeType.isEmpty ? "image/png" : attachment.mimeType
            content.append([
                "type": "input_image",
                "image_url": "data:\(mimeType);base64,\(data.base64EncodedString())"
            ])
        }
        return content
    }

    private static func roleLabel(_ role: ChatRole) -> String {
        switch role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        }
    }

    private static func parseSSEDataLines(_ lines: [String]) -> [Any] {
        let candidates = [
            lines.joined(separator: "\n"),
            lines.joined()
        ]

        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "[DONE]",
                  let data = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            return [object]
        }

        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "[DONE]",
                  let data = trimmed.data(using: .utf8) else {
                return nil
            }
            return try? JSONSerialization.jsonObject(with: data)
        }
    }

    private static func findTextDelta(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            let type = dict["type"] as? String
            if type == "response.output_text.delta",
               let delta = dict["delta"] as? String {
                return delta
            }
            for child in dict.values {
                if let found = findTextDelta(in: child) {
                    return found
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = findTextDelta(in: child) {
                    return found
                }
            }
        }
        return nil
    }

    private static func findFinalText(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            let type = dict["type"] as? String
            if (type == "output_text" || type == "response.output_text.done"),
               let text = dict["text"] as? String {
                return text
            }
            for child in dict.values {
                if let found = findFinalText(in: child) {
                    return found
                }
            }
        } else if let array = value as? [Any] {
            let joined = array.compactMap { findFinalText(in: $0) }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func findErrorMessage(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            if let error = dict["error"] as? [String: Any] {
                return error["message"] as? String ?? String(describing: error)
            }
            for child in dict.values {
                if let found = findErrorMessage(in: child) {
                    return found
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = findErrorMessage(in: child) {
                    return found
                }
            }
        }
        return nil
    }

    private static func containsResponseCompleted(in value: Any) -> Bool {
        if let dict = value as? [String: Any] {
            if dict["type"] as? String == "response.completed" {
                return true
            }
            for child in dict.values where containsResponseCompleted(in: child) {
                return true
            }
        } else if let array = value as? [Any] {
            for child in array where containsResponseCompleted(in: child) {
                return true
            }
        }
        return false
    }
}
