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
    private var preferencesObserver: NSObjectProtocol?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyDefaultsIfNeeded()
        // Force-init container avant tout
        _ = AppContainer.shared
        RunnerBitmap.warmCache()
        setupPopover()
        bindRunnerState()
        observePreferences()
        startBackgroundWork()
        registerGlobalHotkey()
        UpdateService.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.setupStatusItem()
            self.configureActivationPolicy()
            self.startFrameTimer()
            self.triggerOnboardingIfNeeded()
        }
    }

    private func migrateLegacyDefaultsIfNeeded() {
        let legacyBundleIDs = ["com.rodrigue.runbar", "com.rodrigue.runbar.app"]
        let currentBundleID = Bundle.main.bundleIdentifier

        let defaults = UserDefaults.standard
        for legacyBundleID in legacyBundleIDs where currentBundleID != legacyBundleID {
            guard let legacyDomain = defaults.persistentDomain(forName: legacyBundleID), !legacyDomain.isEmpty else { continue }

            var migrated = 0
            for (key, value) in legacyDomain where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
                migrated += 1
            }

            if migrated > 0 {
                NSLog("[RunBar] Migrated \(migrated) UserDefaults value(s) from \(legacyBundleID)")
            }
        }
    }

    /// Raccourci global ⌘⇧R pour ouvrir le popover — utile quand l'icône menu
    /// bar est cachée derrière l'encoche d'un MacBook.
    private func registerGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift],
                  event.charactersIgnoringModifiers == "R" else { return }
            Task { @MainActor in self?.togglePopover() }
        }
    }

    /// On ne veut PAS quitter quand l'utilisateur ferme Settings/Onboarding —
    /// l'app vit dans la barre de menu et ne se ferme qu'avec "Quitter RunBar".
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startBackgroundWork() {
        configureAutoSync()
        Task {
            await sync.syncNow()
            // Auto-réparation de l'historique (throttlée à 24 h) : le backfill
            // de sync ne voit que le cache 7 jours — les semaines où le Mac
            // était éteint restaient définitivement trouées ou figées sur un
            // total partiel. Le rebuild refetch la fenêtre complète en mémoire
            // et corrige les agrégats dérivés.
            await settings.rebuildHistoryIfStale()
        }
        // Déclenche une sync immédiate dès qu'OAuth Strava réussit, pour ne pas
        // attendre le timer auto-sync (30 min) après la première connexion.
        NotificationCenter.default.addObserver(
            forName: .runbarStravaConnected, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.sync.syncNow() }
        }
    }

    private func configureAutoSync() {
        if RunBarPreferences.autoSync {
            sync.startBackgroundSync()
        } else {
            sync.stop()
        }
    }

    private func observePreferences() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.configureAutoSync()
                self?.refreshIcon()
            }
        }
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

    private func configureActivationPolicy() {
        // A bundled RunBar.app is already a menu-bar agent through LSUIElement.
        // On Tahoe, calling .accessory before/while AppKit installs the status
        // item can leave the item in Control Center's hidden/offscreen slot.
        // Keep the programmatic policy only for `swift run`, where there is no
        // app Info.plist to hide the Dock icon.
        let isAgentBundle = (Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool) == true
        guard !isAgentBundle else {
            NSLog("[RunBar] Activation policy left to LSUIElement")
            return
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        NSLog("[RunBar] Activation policy set to accessory after status item creation")
    }

    private func setupStatusItem() {
        // variableLength : laisse macOS auto-sizer, plus fiable que length fixe
        // sur les MacBook avec encoche où une length fixe peut se faire écraser
        // à width=0 si l'app active a beaucoup de menus.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // autosaveName explicite : sans ça, macOS range le status item dans le
        // namespace "Item-N" partagé avec d'autres apps, et `com.apple.controlcenter`
        // peut avoir une clé `NSStatusItem Visible Item-N = 0` qui écrase notre
        // `isVisible = true`. Avec un nom dédié, on a notre propre slot.
        item.autosaveName = "RunBarMenuBarItemV3"
        item.isVisible = true
        if let button = item.button {
            applyIcon(to: button, image: RunnerBitmap.image(for: currentState, subframe: 0))
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            NSLog("[RunBar] StatusItem created frameCount=\(RunnerSprite.frameCount) buttonFrame=\(button.frame)")
        }
        statusItem = item

        // Diagnostic 2s après launch : si la fenêtre interne du status item
        // a une width < 1 (squashée par l'encoche / app avec menus longs),
        // l'icône est invisible et on auto-affiche le popover au top-center
        // comme fallback. La frame du button reste 28×22 dans son window
        // local — ce qui compte c'est la frame du window à l'écran.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            let buttonFrame = button.frame
            let windowFrame = button.window?.frame ?? .zero
            NSLog("[RunBar] After 2s: buttonFrame=\(buttonFrame) windowFrame=\(windowFrame)")
            let hidden = windowFrame.width < 1 || windowFrame.origin.x == 0
            if hidden, let pop = self.popover, !pop.isShown {
                NSLog("[RunBar] Status item hidden by macOS (notch overflow). Showing popover at top-center.")
                NSApp.activate(ignoringOtherApps: true)
                self.showPopoverAtTopCenter(pop)
            }
        }
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
        menu.addItem(NSMenuItem(title: String(localized: "menu.sync_now", bundle: .runBarResources),
                                action: #selector(menuSync), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: String(localized: "menu.settings", bundle: .runBarResources),
                                action: #selector(menuSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: String(localized: "menu.check_updates", bundle: .runBarResources),
                                action: #selector(menuCheckUpdates), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.quit", bundle: .runBarResources),
                                action: #selector(menuQuit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuSync()          { Task { await sync.syncNow() } }
    @objc private func menuSettings()      { settings.bringToFront(); openSettingsWindow() }
    @objc private func menuCheckUpdates()  { UpdateService.shared.checkForUpdates() }
    @objc private func menuQuit()          { NSApplication.shared.terminate(nil) }

    private func openSettingsWindow() {
        // Sur macOS 14+, l'action standard `showSettingsWindow:` ouvre la scene `Settings { }`.
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 460)
        pop.behavior = .transient
        pop.animates = true
        let host = NSHostingController(
            rootView: PopoverView(viewModel: popoverVM)
                .environmentObject(store)
                .frame(width: 320)
        )
        // Ask the hosting controller to pin the popover to the SwiftUI
        // intrinsic height — so adding a race banner (or any optional row)
        // grows the popover instead of clipping the top/bottom.
        host.sizingOptions = [.preferredContentSize]
        pop.contentViewController = host
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
            // ⚠️ Ne PAS appeler `NSApp.activate(ignoringOtherApps: true)` ici —
            // cette API ramène toutes les fenêtres de l'app au premier plan,
            // donc la Settings window (si elle était ouverte mais cachée)
            // remonterait avec le popover. Le popover devient key window via
            // `makeKey()` ci-dessous, c'est suffisant pour qu'il reçoive
            // événements clavier et clics.
            if button.window != nil, button.bounds.width > 0 {
                pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            } else {
                showPopoverAtTopCenter(pop)
            }
            pop.contentViewController?.view.window?.makeKey()
        }
    }

    /// Affiche le popover ancré au centre supérieur de l'écran principal —
    /// fallback quand la status item n'est pas visible (barre saturée).
    private var fallbackAnchor: NSWindow?
    private func showPopoverAtTopCenter(_ pop: NSPopover) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let anchorRect = NSRect(x: frame.midX - 1, y: frame.maxY - 4, width: 2, height: 2)
        let window = NSWindow(contentRect: anchorRect, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.makeKeyAndOrderFront(nil)
        fallbackAnchor = window
        if let view = window.contentView {
            pop.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
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
        // Sprites = 1 sub-frame par PNG. Parametric = tweenSteps in-betweens par keyframe.
        let mult = currentState.hasSpriteAssets ? 1.0 : Double(RunnerBitmap.tweenSteps)
        let interval = 1.0 / (currentState.fps * mult)
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
        guard let button = statusItem?.button else { return }
        applyIcon(to: button, image: RunnerBitmap.image(for: currentState, subframe: frameIndex))
        // Tooltip — explique l'état courant ("Warming up", "Sprinting", etc.)
        // pour les nouveaux utilisateurs qui voient une animation sans contexte.
        let pctText = "\(Int(round(popoverVM.progress * 100)))%"
        button.toolTip = "RunBar — \(currentState.label) · \(pctText)"
    }

    private func applyIcon(to button: NSStatusBarButton, image: NSImage?) {
        let wantsGlyph = RunBarPreferences.showGlyph
        let wantsPercent = RunBarPreferences.showPercent
        // Tahoe is very sensitive to menu bar items that resize after launch:
        // once Strava syncs a long streak, Control Center can push the item
        // into an offscreen/hidden slot. Keep the status item compact and let
        // the popover/settings show richer progress details.
        let wantsStreak = false
        let validImage = image?.isUsableStatusImage == true ? image : fallbackStatusImage()
        let percent = "\(Int(round(popoverVM.progress * 100)))%"

        // Menu bar utilise le run streak (convention Strava : semaines avec
        // au moins 1 sortie). Le badge popover utilise le goal-completion
        // streak (plus strict, aspirationnel).
        let streak = popoverVM.currentRunStreak
        let streakActive = wantsStreak && streak >= 2
        let streakSuffix = streakActive ? "🔥\(streak)" : ""

        // Compose title — percent and/or streak, separated by a thin space.
        let title: String = {
            switch (wantsPercent, streakActive) {
            case (true, true):  return "\(percent) \(streakSuffix)"
            case (true, false): return percent
            case (false, true): return streakSuffix
            case (false, false): return ""
            }
        }()

        let extras = (wantsPercent ? 1 : 0) + (streakActive ? 1 : 0)
        let glyphWidth: CGFloat = wantsGlyph ? 28 : 0
        let textWidth: CGFloat = CGFloat(extras) * 26
        statusItem?.length = max(28, glyphWidth + textWidth)

        button.title = title
        button.image = wantsGlyph ? validImage : nil
        button.image?.isTemplate = true
        button.imageScaling = .scaleProportionallyDown

        switch (wantsGlyph, !title.isEmpty) {
        case (true, true):
            button.imagePosition = .imageLeft
        case (true, false):
            button.imagePosition = .imageOnly
        case (false, true):
            button.imagePosition = .noImage
        case (false, false):
            button.title = "RB"
            button.imagePosition = .noImage
        }
    }

    private func fallbackStatusImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "figure.run", accessibilityDescription: "RunBar")
        image?.isTemplate = true
        return image
    }
}

private extension NSImage {
    var isUsableStatusImage: Bool {
        !representations.isEmpty && size.width > 0 && size.height > 0
    }
}
