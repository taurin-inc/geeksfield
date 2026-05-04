import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CodexImageProvider: ImageProvider {
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

    func generate(request: GenerationRequest, referenceImages: [Data], apiKey: String) async throws -> [Data] {
        _ = apiKey
        let count = max(1, request.batchSize)
        let prompt = Self.promptWithOutputOptions(
            request.prompt,
            size: request.size,
            aspectRatio: request.aspectRatio
        )
        var results: [Data] = []
        for _ in 0..<count {
            let image = try await requestImage(prompt: prompt, images: referenceImages, modelID: request.model.id)
            results.append(ImageOutputNormalizer.normalizedPNG(
                image,
                size: request.size,
                aspectRatio: request.aspectRatio
            ))
        }
        return results
    }

    func edit(request: InpaintRequest, originalPNG: Data, maskPNG: Data, apiKey: String) async throws -> Data {
        _ = apiKey
        let guidePNG = Self.makeAnnotatedGuide(originalPNG: originalPNG, maskPNG: maskPNG) ?? maskPNG
        let prompt = """
        Edit the first attached image according to this instruction:
        \(request.prompt)

        The second attached image is an edit guide: red highlighted pixels mark the only region to change. Preserve the rest of the first image as closely as possible. Return the complete edited image, not the guide.
        """
        return try await requestImage(prompt: prompt, images: [originalPNG, guidePNG], modelID: request.model.id)
    }

    private static func promptWithOutputOptions(_ prompt: String, size: Size, aspectRatio: String?) -> String {
        var lines = [prompt]
        var constraints: [String] = []
        if let aspectRatio, aspectRatio != "auto" {
            constraints.append("Target aspect ratio: \(aspectRatio). Compose the final image for this canvas ratio.")
        }
        if !size.isAuto {
            constraints.append("Target pixel size: \(size.description).")
        }
        guard !constraints.isEmpty else { return prompt }
        lines.append("")
        lines.append("Generation constraints:")
        lines.append(contentsOf: constraints.map { "- \($0)" })
        lines.append("- Do not choose a different output ratio unless technically impossible.")
        return lines.joined(separator: "\n")
    }

    private func requestImage(prompt: String, images: [Data], modelID: String) async throws -> Data {
        let auth = try authStore.load()
        var content: [[String: String]] = [
            ["type": "input_text", "text": prompt]
        ]
        for image in images {
            content.append([
                "type": "input_image",
                "image_url": "data:image/png;base64,\(image.base64EncodedString())"
            ])
        }

        let body: [String: Any] = [
            "model": modelID,
            "instructions": "",
            "input": [
                [
                    "type": "message",
                    "role": "user",
                    "content": content
                ]
            ],
            "tools": [
                ["type": "image_generation", "output_format": "png"]
            ],
            "tool_choice": ["type": "image_generation"],
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
        let preparedRequest = request

        return try await withTimeout(seconds: 180) {
            try await streamImage(for: preparedRequest)
        }
    }

    private func streamImage(for request: URLRequest) async throws -> Data {
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
        var summaries: [String] = []
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                let parsed = try parseEvent(lines: eventLines)
                if let summary = parsed.summary {
                    summaries.append(summary)
                }
                if let image = parsed.image {
                    return image
                }
                eventLines.removeAll(keepingCapacity: true)
            } else {
                eventLines.append(line)
            }
        }

        let parsed = try parseEvent(lines: eventLines)
        if let summary = parsed.summary {
            summaries.append(summary)
        }
        if let image = parsed.image {
            return image
        }
        let details = Self.compactSummaries(summaries)
        throw ImageProviderError.unsupportedOperation(
            details.isEmpty
                ? "Provider returned no image output and no parseable SSE events."
                : "Provider returned no image output. \(details)"
        )
    }

    private func parseEvent(lines: [String]) throws -> (image: Data?, summary: String?) {
        let dataLines = lines
            .filter { $0.hasPrefix("data:") }
            .map { line in
                let index = line.index(line.startIndex, offsetBy: 5)
                return String(line[index...]).trimmingCharacters(in: .whitespaces)
            }
        guard !dataLines.isEmpty else { return (nil, nil) }

        let objects = Self.parseSSEDataLines(dataLines)
        guard !objects.isEmpty else {
            let sample = dataLines.joined().prefix(160)
            return (nil, "Unparseable SSE data: \(sample)")
        }

        var summaries: [String] = []
        var completedSummary: String?
        for object in objects {
            let summary = Self.describeResponse(in: object)
            if let summary {
                summaries.append(summary)
            }
            if let message = Self.findErrorMessage(in: object) {
                throw ImageProviderError.unsupportedOperation(message)
            }
            if let base64 = Self.findFinalImageBase64(in: object),
               let image = Data(base64Encoded: base64) {
                return (image, summary)
            }
            if Self.containsResponseCompleted(in: object) {
                completedSummary = summary ?? "Provider returned no image output."
            }
        }
        if let completedSummary {
            throw ImageProviderError.unsupportedOperation(completedSummary)
        }
        return (nil, Self.compactSummaries(summaries))
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

        var objects: [Any] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "[DONE]",
                  let data = trimmed.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            objects.append(object)
        }

        return objects
    }

    private static func findFinalImageBase64(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            let type = dict["type"] as? String
            if type == "image_generation_call",
               let result = dict["result"] as? String {
                return result
            }
            if type?.contains("image_generation_call") == true,
               let result = dict["result"] as? String {
                return result
            }
            for child in dict.values {
                if let found = findFinalImageBase64(in: child) {
                    return found
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = findFinalImageBase64(in: child) {
                    return found
                }
            }
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

    private static func describeResponse(in value: Any) -> String? {
        var types: [String] = []
        var texts: [String] = []

        func walk(_ value: Any) {
            if let dict = value as? [String: Any] {
                if let type = dict["type"] as? String {
                    types.append(type)
                }
                if let text = dict["text"] as? String, !text.isEmpty {
                    texts.append(text)
                }
                if let content = dict["content"] as? String, !content.isEmpty {
                    texts.append(content)
                }
                for child in dict.values { walk(child) }
            } else if let array = value as? [Any] {
                for child in array { walk(child) }
            }
        }

        walk(value)
        let uniqueTypes = Array(NSOrderedSet(array: types)) as? [String] ?? []
        let typeText = uniqueTypes.isEmpty ? nil : "Output types: \(uniqueTypes.joined(separator: ", "))."
        let message = texts.first.map { "Text response: \($0.prefix(300))" }
        return [typeText, message].compactMap { $0 }.joined(separator: " ")
    }

    private static func compactSummaries(_ summaries: [String]) -> String {
        let clean = summaries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen: Set<String> = []
        var unique: [String] = []
        for item in clean where !seen.contains(item) {
            seen.insert(item)
            unique.append(item)
        }
        return unique.suffix(6).joined(separator: " ")
    }

    private static func makeAnnotatedGuide(originalPNG: Data, maskPNG: Data) -> Data? {
        guard let original = CGImageSourceCreateWithData(originalPNG as CFData, nil)
                .flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }),
              let mask = CGImageSourceCreateWithData(maskPNG as CFData, nil)
                .flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else {
            return nil
        }

        let width = original.width
        let height = original.height
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        ctx.draw(original, in: rect)
        ctx.saveGState()
        ctx.clip(to: rect, mask: mask)
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.45))
        ctx.fill(rect)
        ctx.restoreGState()

        guard let composed = ctx.makeImage(),
              let out = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, composed, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return out as Data
    }

    private func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw ImageProviderError.unsupportedOperation("Codex image generation timed out.")
            }
            guard let value = try await group.next() else {
                throw ImageProviderError.emptyResponse
            }
            group.cancelAll()
            return value
        }
    }
}
