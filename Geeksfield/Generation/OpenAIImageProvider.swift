import Foundation

struct OpenAIImageProvider: ImageProvider {
    let provider: Provider = .openai
    let generateEndpoint: URL
    let editEndpoint: URL
    let session: URLSession

    init(
        generateEndpoint: URL = URL(string: "https://api.openai.com/v1/images/generations")!,
        editEndpoint: URL = URL(string: "https://api.openai.com/v1/images/edits")!,
        session: URLSession = .shared
    ) {
        self.generateEndpoint = generateEndpoint
        self.editEndpoint = editEndpoint
        self.session = session
    }

    // MARK: - Generate

    func generate(request: GenerationRequest, referenceImages: [Data], apiKey: String) async throws -> [Data] {
        // OpenAI /v1/images/generations does not accept reference images. To use
        // them a caller should switch to the edit endpoint. We ignore them here
        // rather than fail so a project with refs attached still generates.
        _ = referenceImages
        var body: [String: Any] = [
            "model": request.model.id,
            "prompt": request.prompt,
            "n": request.batchSize
        ]
        body["size"] = request.size.isAuto ? "auto" : request.size.description

        var req = URLRequest(url: generateEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await session.data(for: req)
        try ensureSuccess(data: data, response: response)

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.data.compactMap { Data(base64Encoded: $0.b64_json) }
    }

    // MARK: - Edit (inpaint)

    func edit(request: InpaintRequest, originalPNG: Data, maskPNG: Data, apiKey: String) async throws -> Data {
        let boundary = "----GeeksfieldBoundary-\(UUID().uuidString)"
        var body = Data()

        func appendPart(name: String, text: String) {
            body.appendCRLF("--\(boundary)")
            body.appendCRLF("Content-Disposition: form-data; name=\"\(name)\"")
            body.appendCRLF("")
            body.appendCRLF(text)
        }

        func appendFilePart(name: String, filename: String, mime: String, data: Data) {
            body.appendCRLF("--\(boundary)")
            body.appendCRLF("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"")
            body.appendCRLF("Content-Type: \(mime)")
            body.appendCRLF("")
            body.append(data)
            body.appendCRLF("")
        }

        appendPart(name: "model", text: request.model.id)
        appendPart(name: "prompt", text: request.prompt)
        appendPart(name: "n", text: "1")
        if let size = request.size, !size.isAuto {
            appendPart(name: "size", text: size.description)
        }
        appendFilePart(name: "image", filename: "image.png", mime: "image/png", data: originalPNG)
        appendFilePart(name: "mask", filename: "mask.png", mime: "image/png", data: maskPNG)
        body.appendCRLF("--\(boundary)--")

        var req = URLRequest(url: editEndpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 120

        let (data, response) = try await session.data(for: req)
        try ensureSuccess(data: data, response: response)

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let first = decoded.data.first,
              let image = Data(base64Encoded: first.b64_json) else {
            throw ImageProviderError.emptyResponse
        }
        return image
    }

    // MARK: - Helpers

    private func ensureSuccess(data: Data, response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageProviderError.http(http.statusCode, body)
        }
    }

    private struct Response: Decodable {
        struct Item: Decodable { let b64_json: String }
        let data: [Item]
    }
}

// MARK: - Errors

enum ImageProviderError: Error, LocalizedError {
    case http(Int, String)
    case emptyResponse
    case unsupportedModel(String)
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            let snippet = body.prefix(200)
            return "HTTP \(code): \(snippet)"
        case .emptyResponse:
            return "Provider returned no images."
        case .unsupportedModel(let id):
            return "Unsupported model: \(id)"
        case .unsupportedOperation(let op):
            return "Unsupported operation: \(op)"
        }
    }
}

private extension Data {
    mutating func appendCRLF(_ text: String) {
        if let d = (text + "\r\n").data(using: .utf8) { append(d) }
    }
}
