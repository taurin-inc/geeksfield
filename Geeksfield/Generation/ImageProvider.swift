import Foundation

protocol ImageProvider: Sendable {
    var provider: Provider { get }
    func generate(request: GenerationRequest, referenceImages: [Data], apiKey: String) async throws -> [Data]
    func edit(request: InpaintRequest, originalPNG: Data, maskPNG: Data, apiKey: String) async throws -> Data
}
