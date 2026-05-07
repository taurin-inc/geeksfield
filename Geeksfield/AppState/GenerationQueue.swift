import Foundation

actor GenerationQueue {
    private let maxConcurrentStreams: Int
    private var inflight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrentStreams: Int = 8) {
        self.maxConcurrentStreams = max(1, maxConcurrentStreams)
    }

    var inflightCount: Int { inflight }
    var queuedCount: Int { waiters.count }

    func withPermit<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        if inflight < maxConcurrentStreams {
            inflight += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            inflight = max(0, inflight - 1)
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
