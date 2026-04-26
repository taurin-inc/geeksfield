import Foundation
import Observation

/// Placeholder for Stage 5. Concurrent generation orchestration goes here.
@Observable
@MainActor
final class GenerationQueue {
    private(set) var inflight: Int = 0
}
