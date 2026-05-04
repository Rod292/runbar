import Foundation
import Sparkle

/// Façade Sparkle. On contrôle le `SPUStandardUpdaterController` ici pour que
/// l'AppDelegate n'ait qu'un point d'entrée — `checkForUpdates()` côté menu et
/// `start()` côté lancement.
@MainActor
public final class UpdateService: NSObject {
    public static let shared = UpdateService()

    private let controller: SPUStandardUpdaterController

    private override init() {
        // startingUpdater: false → on démarre manuellement après le launch pour
        // ne pas bloquer applicationDidFinishLaunching avec une vérif réseau.
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    public func start() {
        controller.startUpdater()
    }

    public func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
