import Foundation

struct GeminiChatProvider: ChatProvider {
    let provider: Provider = .gemini
    let baseURL: URL
    let session: URLSession

    init(
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func send(messages: [ChatMessage], modelID: String, apiKey: String) async throws -> ChatMessage {
        let url = baseURL.appending(path: "models/\(modelID):generateContent")

        // Gemini does not take a system message alongside user turns the same
        // way OpenAI does. For now we inline the system message as the first
        // user turn's prefix if present.
        var systemPrefix = ""
        var nonSystem: [ChatMessage] = []
        for m in messages {
            if m.role == .system {
                systemPrefix += (systemPrefix.isEmpty ? "" : "\n") + m.content
            } else {
                nonSystem.append(m)
            }
        }

        let contents: [[String: Any]] = nonSystem.enumerated().map { idx, m in
            var parts: [[String: Any]] = []
            let text = (idx == 0 && !systemPrefix.isEmpty) ? "\(systemPrefix)\n\n\(m.content)" : m.content
            parts.append(["text": text])
            for att in m.attachments {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: att.path)) {
                    parts.append([
                        "inlineData": [
                            "mimeType": att.mimeType,
                            "data": data.base64EncodedString()
                        ]
                    ])
                }
            }
            return [
                "role": m.role == .assistant ? "model" : "user",
                "parts": parts
            ]
        }

        let body: [String: Any] = ["contents": contents]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageProviderError.http(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let text = decoded.candidates?
            .first?
            .content
            .parts
            .compactMap { $0.text }
            .joined(separator: "\n") ?? ""

        return ChatMessage(
            id: UUID().uuidString.lowercased(),
            role: .assistant,
            content: text,
            createdAt: Date(),
            provider: .gemini,
            modelID: modelID,
            attachments: []
        )
    }

    private struct Response: Decodable {
        struct Candidate: Decodable { let content: Content }
        struct Content: Decodable { let parts: [Part] }
        struct Part: Decodable {
            let text: String?
        }
        let candidates: [Candidate]?
    }
}
