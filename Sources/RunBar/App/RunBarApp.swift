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

    init() {
        // Menu-bar-only même sans bundle .app — caché du Dock.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        Settings {
            SettingsView(store: AppContainer.shared.store, coordinator: AppContainer.shared.settings)
        }

        Window("Bienvenue", id: "onboarding") {
            OnboardingView(store: AppContainer.shared.store, coordinator: AppContainer.shared.settings) {
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
    public let popoverVM: PopoverViewModel
    public let webhook: StravaWebhookServer

    private init() {
        let s = ActivityStore()
        let snaps = SnapshotStore()
        let strava = StravaService()
        let sm = SyncManager(store: s, strava: strava)
        let coord = SettingsCoordinator(strava: strava)
        let vm = PopoverViewModel(store: s, syncManager: sm, snapshots: snaps)
        vm.settingsCoordinator = coord

        let hook = StravaWebhookServer(port: 47863) { _ in
            Task { @MainActor in await sm.syncNow() }
        }

        self.store = s
        self.snapshots = snaps
        self.strava = strava
        self.sync = sm
        self.settings = coord
        self.popoverVM = vm
        self.webhook = hook
    }
}
