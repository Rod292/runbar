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
        // Force-init container avant tout
        _ = AppContainer.shared
        RunnerBitmap.warmCache()
        setupStatusItem()
        setupPopover()
        bindRunnerState()
        observePreferences()
        startFrameTimer()
        startBackgroundWork()
        registerGlobalHotkey()
        triggerOnboardingIfNeeded()
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
        Task { await sync.syncNow() }
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

    private func setupStatusItem() {
        // Length fixe 28 — `variableLength` peut donner 0 le temps que la
        // première image soit calculée, ce qui rend la cible de clic invisible
        // et place le popover hors écran (button.bounds = .zero).
        let item = NSStatusBar.system.statusItem(withLength: 28)
        if let button = item.button {
            applyIcon(to: button, image: RunnerBitmap.image(for: currentState, subframe: 0))
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            NSLog("[RunBar] StatusItem créé frameCount=\(RunnerSprite.frameCount)")
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
        menu.addItem(NSMenuItem(title: String(localized: "menu.sync_now", bundle: .module),
                                action: #selector(menuSync), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: String(localized: "menu.settings", bundle: .module),
                                action: #selector(menuSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.quit", bundle: .module),
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
            // Si l'icône est cachée (notch sur MacBook → button.window est nil
            // ou hors écran), on tombe sur un popover ancré à un anchor view
            // centré en haut de l'écran principal.
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
    }

    private func applyIcon(to button: NSStatusBarButton, image: NSImage?) {
        let wantsGlyph = RunBarPreferences.showGlyph
        let wantsPercent = RunBarPreferences.showPercent
        let validImage = image?.isUsableStatusImage == true ? image : fallbackStatusImage()
        let percent = "\(Int(round(popoverVM.progress * 100)))%"

        statusItem?.length = wantsPercent ? 52 : 28
        button.title = wantsPercent ? percent : ""
        button.image = wantsGlyph ? validImage : nil

        switch (wantsGlyph, wantsPercent) {
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
