import AppKit
import SwiftUI
import Logging

/// Point d'entrée. App menu-bar-only — toute l'icône est gérée côté `AppDelegate`
/// via `NSStatusItem` (Canvas → NSImage frame-par-frame, façon RunCat).
/// Les Scene SwiftUI ici ne servent que pour Settings et Onboarding.
@main
struct RunBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("runbar.onboardingDone") private var onboardingDone: Bool = false

    var body: some Scene {
        Settings {
            SettingsView(
                store: AppContainer.shared.store,
                coordinator: AppContainer.shared.settings,
                coachConfig: AppContainer.shared.coachConfiguration,
                coachService: AppContainer.shared.coach
            )
        }

        Window("Bienvenue", id: "onboarding") {
            OnboardingView(
                store: AppContainer.shared.store,
                coordinator: AppContainer.shared.settings,
                coachConfig: AppContainer.shared.coachConfiguration
            ) {
                onboardingDone = true
                NSApp.keyWindow?.close()
            }
            .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}

/// Container singleton des dépendances. Le `AppDelegate` le crée au launch,
/// les Scene SwiftUI le consomment.
@MainActor
public final class AppContainer {
    public static let shared = AppContainer()

    public let store: ActivityStore
    public let snapshots: SnapshotStore
    public let strava: StravaServiceProtocol
    public let sync: SyncManager
    public let settings: SettingsCoordinator
    public let suggestions: GoalSuggestionStore
    public let coachConfiguration: CoachConfiguration
    public let coach: CoachService
    public let popoverVM: PopoverViewModel
    public let webhook: StravaWebhookServer

    private init() {
        let s = ActivityStore()
        let snaps = SnapshotStore()
        let strava = StravaService()
        let sm = SyncManager(store: s, strava: strava)
        let coord = SettingsCoordinator(strava: strava, store: s, snapshots: snaps)
        let suggestionStore = GoalSuggestionStore(store: s)
        let coachCfg = CoachConfiguration()
        let coachSvc = CoachService(store: s, snapshots: snaps, configuration: coachCfg)
        let vm = PopoverViewModel(
            store: s, syncManager: sm, snapshots: snaps,
            suggestions: suggestionStore, coach: coachSvc
        )
        vm.settingsCoordinator = coord

        let hook = StravaWebhookServer(port: 47863) { objectId, aspect in
            Task { @MainActor in
                switch aspect {
                case .delete:
                    // Strava API Agreement § 2.6f: delete within 48h. We act
                    // immediately rather than waiting on the next sync window.
                    s.deleteStravaActivity(objectID: objectId)
                case .create, .update:
                    await sm.syncNow()
                }
            }
        }

        self.store = s
        self.snapshots = snaps
        self.strava = strava
        self.sync = sm
        self.settings = coord
        self.suggestions = suggestionStore
        self.coachConfiguration = coachCfg
        self.coach = coachSvc
        self.popoverVM = vm
        self.webhook = hook
    }
}
