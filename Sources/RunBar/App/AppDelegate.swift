import AppKit
import Combine
import SwiftUI

/// AppDelegate — possède l'`NSStatusItem` (icône menu bar custom) et le
/// `NSPopover` qui contient le SwiftUI `PopoverView`. On bypass `MenuBarExtra`
/// parce qu'il ne sait pas afficher de Canvas custom — on a besoin de notre
/// runner animé frame-par-frame.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ActivityStore { AppContainer.shared.store }
    private var sync: SyncManager { AppContainer.shared.sync }
    private var settings: SettingsCoordinator { AppContainer.shared.settings }
    private var popoverVM: PopoverViewModel { AppContainer.shared.popoverVM }

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var frameTimer: Timer?
    private var frameIndex: Int = 0
    private var currentState: RunnerState = .idle
    private var stateObserver: AnyCancellable?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Force-init container avant tout
        _ = AppContainer.shared
        RunnerBitmap.warmCache()
        setupStatusItem()
        setupPopover()
        bindRunnerState()
        startFrameTimer()
        startBackgroundWork()
        triggerOnboardingIfNeeded()
    }

    /// On ne veut PAS quitter quand l'utilisateur ferme Settings/Onboarding —
    /// l'app vit dans la barre de menu et ne se ferme qu'avec "Quitter RunBar".
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startBackgroundWork() {
        sync.startBackgroundSync()
        AppContainer.shared.webhook.start()
        Task { await sync.syncNow() }
    }

    /// Si l'onboarding n'a jamais été fait, on ouvre le popover automatiquement
    /// au lancement — la `OnboardingTrigger` SwiftUI à l'intérieur appelle
    /// `openWindow(id: "onboarding")` dès qu'elle s'affiche.
    private func triggerOnboardingIfNeeded() {
        let done = UserDefaults.standard.bool(forKey: "runbar.onboardingDone")
        guard !done else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, let button = self.statusItem?.button, let pop = self.popover, !pop.isShown else { return }
            NSApp.activate(ignoringOtherApps: true)
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 28)
        if let button = item.button {
            button.image = RunnerBitmap.image(for: currentState, subframe: 0)
            button.imagePosition = .imageOnly
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func handleClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Synchroniser maintenant",
                                action: #selector(menuSync), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Préférences…",
                                action: #selector(menuSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter RunBar",
                                action: #selector(menuQuit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuSync()     { Task { await sync.syncNow() } }
    @objc private func menuSettings() { settings.bringToFront(); openSettingsWindow() }
    @objc private func menuQuit()     { NSApplication.shared.terminate(nil) }

    private func openSettingsWindow() {
        // Sur macOS 14+, l'action standard `showSettingsWindow:` ouvre la scene `Settings { }`.
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 420)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: popoverVM)
                .environmentObject(store)
                .frame(width: 320, height: 420)
        )
        popover = pop

        // Permet au popover de se fermer via NotificationCenter (bouton ✕).
        NotificationCenter.default.addObserver(
            forName: .runbarClosePopover, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.popover?.performClose(nil) }
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown {
            pop.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Runner animation

    private func bindRunnerState() {
        // Recompute current state when activities change. We sample the
        // popoverVM's published runnerState via objectWillChange.
        stateObserver = popoverVM.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let newState = self.popoverVM.runnerState
                if newState != self.currentState {
                    self.currentState = newState
                    self.frameIndex = 0
                    self.restartFrameTimer()
                    self.refreshIcon()
                }
            }
        }
    }

    private func startFrameTimer() {
        restartFrameTimer()
        refreshIcon()
    }

    private func restartFrameTimer() {
        frameTimer?.invalidate()
        // L'intervalle est divisé par tweenSteps pour rendre les sub-frames.
        let interval = 1.0 / (currentState.fps * Double(RunnerBitmap.tweenSteps))
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let total = RunnerBitmap.totalSubframes(for: self.currentState)
                self.frameIndex = (self.frameIndex + 1) % total
                self.refreshIcon()
            }
        }
        t.tolerance = interval * 0.1
        RunLoop.main.add(t, forMode: .common)
        frameTimer = t
    }

    private func refreshIcon() {
        statusItem?.button?.image = RunnerBitmap.image(for: currentState, subframe: frameIndex)
    }
}
