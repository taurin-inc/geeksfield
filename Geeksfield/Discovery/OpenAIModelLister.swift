import Foundation

struct OpenAIModelLister: ModelLister {
    let provider: Provider = .openai
    let endpoint: URL
    let session: URLSession

    init(
        endpoint: URL = URL(string: "https://api.openai.com/v1/models")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func listAvailableModelIDs(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ModelListerError.network(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw ModelListerError.invalidKey }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ModelListerError.http(http.statusCode, body)
            }
        }

        do {
            let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
            return decoded.data.map(\.id)
        } catch {
            throw ModelListerError.decode(error)
        }
    }

    private struct OpenAIModelsResponse: Decodable {
        struct Item: Decodable { let id: String }
        let data: [Item]
    }
}
