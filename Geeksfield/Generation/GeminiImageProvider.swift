import Foundation

struct GeminiImageProvider: ImageProvider {
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

    func generate(request: GenerationRequest, referenceImages: [Data], apiKey: String) async throws -> [Data] {
        // Imagen uses :predict with n samples in one request and does not take
        // reference images. Multimodal gemini image models use :generateContent
        // and can include references as inline parts.
        if request.model.id.hasPrefix("imagen") {
            return try await generateWithPredict(request: request, apiKey: apiKey)
        }
        return try await generateWithContent(
            request: request,
            referenceImages: referenceImages,
            apiKey: apiKey
        )
    }

    // MARK: - predict (Imagen)

    private func generateWithPredict(request: GenerationRequest, apiKey: String) async throws -> [Data] {
        let url = baseURL.appending(path: "models/\(request.model.id):predict")
        var parameters: [String: Any] = ["sampleCount": request.batchSize]
        if let aspect = request.aspectRatio, aspect != "auto" {
            parameters["aspectRatio"] = aspect
        }
        let body: [String: Any] = [
            "instances": [["prompt": request.prompt]],
            "parameters": parameters
        ]

        let data = try await postJSON(url: url, apiKey: apiKey, body: body)
        let decoded = try JSONDecoder().decode(PredictResponse.self, from: data)
        let images = decoded.predictions.compactMap { Data(base64Encoded: $0.bytesBase64Encoded) }
        guard !images.isEmpty else { throw ImageProviderError.emptyResponse }
        return images
    }

    // MARK: - generateContent (multimodal gemini-*-image)

    private func generateWithContent(
        request: GenerationRequest,
        referenceImages: [Data],
        apiKey: String
    ) async throws -> [Data] {
        let url = baseURL.appending(path: "models/\(request.model.id):generateContent")

        var parts: [[String: Any]] = [["text": request.prompt]]
        for ref in referenceImages {
            parts.append([
                "inlineData": [
                    "mimeType": "image/png",
                    "data": ref.base64EncodedString()
                ]
            ])
        }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"]
            ]
        ]
        // Serialize once so the task-group closure captures Sendable Data instead
        // of an untyped [String: Any] dictionary.
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        return try await withThrowingTaskGroup(of: Data?.self) { group in
            for _ in 0..<request.batchSize {
                group.addTask {
                    let raw = try await self.postData(url: url, apiKey: apiKey, body: bodyData)
                    let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: raw)
                    for candidate in decoded.candidates ?? [] {
                        for part in candidate.content.parts {
                            if let inline = part.inlineData,
                               let data = Data(base64Encoded: inline.data) {
                                return data
                            }
                        }
                    }
                    return nil
                }
            }
            var out: [Data] = []
            for try await maybe in group {
                if let d = maybe { out.append(d) }
            }
            if out.isEmpty { throw ImageProviderError.emptyResponse }
            return out
        }
    }

    // MARK: - Edit (inpaint)

    func edit(request: InpaintRequest, originalPNG: Data, maskPNG: Data, apiKey: String) async throws -> Data {
        // Gemini's generateContent handles image edits by accepting the source
        // image + a mask image + a text prompt as separate parts. The model is
        // instructed to regenerate the masked region.
        guard !request.model.id.hasPrefix("imagen") else {
            throw ImageProviderError.unsupportedOperation("Imagen \(request.model.id)에서 인페인트 미지원")
        }

        let url = baseURL.appending(path: "models/\(request.model.id):generateContent")
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": "다음 이미지의 마스킹된 영역만 아래 지시에 따라 재생성하세요. 지시: \(request.prompt)"],
                    ["inlineData": ["mimeType": "image/png", "data": originalPNG.base64EncodedString()]],
                    ["inlineData": ["mimeType": "image/png", "data": maskPNG.base64EncodedString()]]
                ]
            ]],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"]
            ]
        ]
        let raw = try await postJSON(url: url, apiKey: apiKey, body: body)
        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: raw)
        for candidate in decoded.candidates ?? [] {
            for part in candidate.content.parts {
                if let inline = part.inlineData,
                   let data = Data(base64Encoded: inline.data) {
                    return data
                }
            }
        }
        throw ImageProviderError.emptyResponse
    }

    // MARK: - HTTP helpers

    private func postJSON(url: URL, apiKey: String, body: [String: Any]) async throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await postData(url: url, apiKey: apiKey, body: data)
    }

    private func postData(url: URL, apiKey: String, body: Data) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 120

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ImageProviderError.http(http.statusCode, text)
        }
        return data
    }

    // MARK: - Response schemas

    private struct PredictResponse: Decodable {
        struct Prediction: Decodable { let bytesBase64Encoded: String }
        let predictions: [Prediction]
    }

    private struct GenerateContentResponse: Decodable {
        struct Candidate: Decodable {
            let content: Content
        }
        struct Content: Decodable {
            let parts: [Part]
        }
        struct Part: Decodable {
            let text: String?
            let inlineData: InlineData?

            enum CodingKeys: String, CodingKey {
                case text
                case inlineData = "inlineData"
            }
        }
        struct InlineData: Decodable {
            let mimeType: String
            let data: String
        }
        let candidates: [Candidate]?
    }
}
