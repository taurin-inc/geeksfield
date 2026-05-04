import Foundation

struct InpaintRequest: Hashable, Sendable {
    let projectID: String
    let sourceImageID: String
    let outputImageID: String
    let maskPNGData: Data
    let prompt: String
    let model: ModelDescriptor
    let size: Size?
}
