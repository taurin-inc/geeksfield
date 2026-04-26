import Foundation
import Observation

struct DisplayableError: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let message: String
    let timestamp: Date

    init(title: String, message: String) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.timestamp = Date()
    }
}

@Observable
@MainActor
final class ErrorBus {
    var latest: DisplayableError?
    var history: [DisplayableError] = []

    func report(_ error: Error, title: String = "Error") {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        report(title: title, message: message)
    }

    func report(title: String, message: String) {
        let entry = DisplayableError(title: title, message: message)
        latest = entry
        history.append(entry)
    }

    func dismiss() { latest = nil }
}
