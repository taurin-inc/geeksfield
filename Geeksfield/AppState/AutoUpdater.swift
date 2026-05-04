import Foundation
import Sparkle

@MainActor
protocol AutoUpdater: AnyObject {
    func checkForUpdatesInBackground()
    func checkForUpdates()
    var isEnabled: Bool { get }
}

final class SparkleAutoUpdater: AutoUpdater {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var isEnabled: Bool {
        updaterController.updater.canCheckForUpdates
    }

    func checkForUpdatesInBackground() {
        guard updaterController.updater.automaticallyChecksForUpdates else { return }
        updaterController.updater.checkForUpdatesInBackground()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
