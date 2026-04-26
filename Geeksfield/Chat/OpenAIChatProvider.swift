import Foundation

struct OpenAIChatProvider: ChatProvider {
    let provider: Provider = .openai
    let endpoint: URL
    let session: URLSession

    init(
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func send(messages: [ChatMessage], modelID: String, apiKey: String) async throws -> ChatMessage {
        let body: [String: Any] = [
            "model": modelID,
            "messages": messages.map(encodeMessage)
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageProviderError.http(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let text = decoded.choices.first?.message.content ?? ""
        return ChatMessage(
            id: UUID().uuidString.lowercased(),
            role: .assistant,
            content: text,
            createdAt: Date(),
            provider: .openai,
            modelID: modelID,
            attachments: []
        )
    }

    private func encodeMessage(_ m: ChatMessage) -> [String: Any] {
        // Vision: if there are image attachments, content is an array of parts.
        // Otherwise a plain string.
        if !m.attachments.isEmpty {
            var parts: [[String: Any]] = [["type": "text", "text": m.content]]
            for att in m.attachments {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: att.path)) {
                    let b64 = data.base64EncodedString()
                    parts.append([
                        "type": "image_url",
                        "image_url": ["url": "data:\(att.mimeType);base64,\(b64)"]
                    ])
                }
            }
            return ["role": m.role.rawValue, "content": parts]
        }
        return ["role": m.role.rawValue, "content": m.content]
    }

    private struct Response: Decodable {
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
        let choices: [Choice]
    }
}
