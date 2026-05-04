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
        guard hasValidBundle else {
            NSLog("[RunBar] Sparkle disabled: not running from a .app bundle (dev mode)")
            return
        }
        controller.startUpdater()
    }

    public func checkForUpdates() {
        guard hasValidBundle else { return }
        controller.checkForUpdates(nil)
    }

    /// Sparkle exige un vrai bundle `.app` avec `SUFeedURL` dans l'Info.plist.
    /// En `swift run` / lancement direct du binaire, on no-op proprement.
    private var hasValidBundle: Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return false }
        return true
    }
}
