import Foundation

/// Placeholder for Sparkle integration. Wiring the real framework in later means
/// adding the Sparkle SPM dep, instantiating `SPUStandardUpdaterController`, and
/// forwarding to `AutoUpdater` via a concrete implementation. The rest of the
/// app only sees this protocol.
protocol AutoUpdater: AnyObject, Sendable {
    func checkForUpdatesInBackground()
    func checkForUpdates()
    var isEnabled: Bool { get }
}

/// No-op updater shipped in builds without Sparkle.
final class NoOpAutoUpdater: AutoUpdater, @unchecked Sendable {
    let isEnabled: Bool = false
    func checkForUpdatesInBackground() {}
    func checkForUpdates() {}
}
