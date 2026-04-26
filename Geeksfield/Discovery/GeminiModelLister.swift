import Foundation

struct GeminiModelLister: ModelLister {
    let provider: Provider = .gemini
    let endpoint: URL
    let session: URLSession

    init(
        endpoint: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func listAvailableModelIDs(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: endpoint)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ModelListerError.network(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw ModelListerError.invalidKey
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ModelListerError.http(http.statusCode, body)
            }
        }

        do {
            let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
            // API returns fully-qualified "models/gemini-3-pro-image-preview"; strip the prefix.
            return decoded.models.map { $0.name.hasPrefix("models/") ? String($0.name.dropFirst("models/".count)) : $0.name }
        } catch {
            throw ModelListerError.decode(error)
        }
    }

    private struct GeminiModelsResponse: Decodable {
        struct Item: Decodable { let name: String }
        let models: [Item]
    }
}
