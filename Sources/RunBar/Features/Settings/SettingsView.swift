import SwiftUI

/// Coordonnateur léger pour ouvrir la fenêtre Settings depuis le popover.
@MainActor
public final class SettingsCoordinator: ObservableObject {
    @Published public var isOpen: Bool = false
    @Published public var stravaConnected: Bool = false
    @Published public var stravaBusy: Bool = false
    @Published public var stravaError: String? = nil

    /// True quand l'utilisateur a saisi son propre `client_id` + `client_secret`
    /// dans Settings (mode "Bring Your Own App"). Source de vérité :
    /// `StravaUserCredentialsStore.isUserManaged`.
    @Published public var stravaUsesUserAccount: Bool = StravaUserCredentialsStore.isUserManaged

    public let strava: StravaServiceProtocol
    private let store: ActivityStore?
    private let snapshots: SnapshotStore?

    public init(strava: StravaServiceProtocol, store: ActivityStore? = nil, snapshots: SnapshotStore? = nil) {
        self.strava = strava
        self.store = store
        self.snapshots = snapshots
        Task { await refreshStravaStatus() }
    }

    /// Activation de l'app : utile depuis un popover menu bar pour faire passer
    /// la fenêtre Settings au premier plan. L'ouverture elle-même passe par
    /// `@Environment(\.openSettings)` côté view (macOS 14+).
    public func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }
    public func close() { isOpen = false }

    public func refreshStravaStatus() async {
        stravaConnected = await strava.isAuthenticated()
    }

    public func connectStrava() async {
        stravaBusy = true
        stravaError = nil
        defer { stravaBusy = false }
        do {
            try await strava.startOAuth()
            await refreshStravaStatus()
            NSApp.activate(ignoringOtherApps: true)
            if stravaConnected {
                // Déclenche la sync immédiate (l'AppDelegate écoute ce signal
                // pour appeler `syncNow()` sans attendre le timer auto-sync).
                NotificationCenter.default.post(name: .runbarStravaConnected, object: nil)
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            stravaError = error.localizedDescription
        }
    }

    public func disconnectStrava() async {
        await strava.disconnect()
        // Strava API Agreement: "ensure that all Personal Data pertaining to
        // that user is deleted from your Developer Applications" upon
        // revocation. On supprime toutes les activités Strava locales et
        // les snapshots hebdo dérivés (qui restaient sinon comme historique
        // fantôme du compte précédent — surtout visible quand on switch de
        // compte Strava et que le sparkline 8 semaines reste plein alors
        // que la sync renvoie 0 activités).
        store?.clear(source: .strava)
        snapshots?.clear()
        await refreshStravaStatus()
    }

    /// Enregistre des credentials BYO. Force la déconnexion si on était
    /// connecté : les tokens existants ont été émis sous l'ancien `client_id`,
    /// ils sont devenus invalides côté Strava.
    public func saveUserStravaCredentials(clientID: String, clientSecret: String) async {
        stravaError = nil
        do {
            try StravaUserCredentialsStore.save(clientID: clientID, clientSecret: clientSecret)
            stravaUsesUserAccount = true
            if stravaConnected {
                await disconnectStrava()
            }
        } catch {
            stravaError = error.localizedDescription
        }
    }

    /// Fetches `daysBack` days of running activities from Strava, groups
    /// them by ISO week, and persists weekly aggregates as `WeeklySnapshot`.
    /// Returns the average km/week across the *completed* weeks (current
    /// week excluded), or `nil` when there is no usable data or the fetch
    /// fails.
    ///
    /// Why this is conformant with the Strava API Agreement:
    /// - § 7.1 (7-day cache limit): we never write the raw activities
    ///   beyond 7 days into SwiftData. The fetch result is in-memory only,
    ///   and only the *derived* weekly aggregates are persisted, which the
    ///   agreement explicitly allows.
    /// - § 2.9 (no aggregation/storage except as permitted): weekly
    ///   distance / runs / elevation aggregates are explicitly listed as
    ///   permitted derived data.
    ///
    /// Used by the onboarding flow to seed an accurate weekly target on
    /// first connect — without this, a fresh sync only fills the rolling
    /// 7-day window and underestimates the runner's true weekly pace.
    @discardableResult
    public func seedHistoricalSnapshots(
        daysBack: Int = 28,
        defaultTarget: Double = 40
    ) async -> Double? {
        let cal = Calendar.iso8601Monday
        let now = Date.now
        guard let cutoff = cal.date(byAdding: .day, value: -daysBack, to: now),
              let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start
        else { return nil }
        do {
            let dtos = try await strava.fetchActivities(since: cutoff)
            var byWeek: [Date: Double] = [:]
            for dto in dtos {
                guard let weekStart = cal.dateInterval(of: .weekOfYear, for: dto.startDate)?.start else { continue }
                byWeek[weekStart, default: 0] += dto.distance / 1000.0
            }
            // Persist derived snapshots for every week we touched (including
            // the current one — the popover sparkline benefits from it).
            for (weekStart, km) in byWeek {
                snapshots?.record(
                    weekStart: weekStart,
                    metric: .distance,
                    target: defaultTarget,
                    achieved: km
                )
            }
            // Average is computed over completed weeks only — the current
            // week is partial and would bias the seed downward.
            let completed = byWeek.filter { $0.key < currentWeekStart }
            guard !completed.isEmpty else { return nil }
            let avg = completed.values.reduce(0, +) / Double(completed.count)
            RunBarLog.sync.notice(
                "Historical seed: \(completed.count) completed weeks, avg \(String(format: "%.1f", avg)) km"
            )
            return avg
        } catch {
            RunBarLog.sync.error("Historical seed failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Repasse en mode app partagée (ré-utilise le `client_id` baked dans le
    /// binaire + backend Vercel). Force la déconnexion pour la même raison.
    public func clearUserStravaCredentials() async {
        StravaUserCredentialsStore.clear()
        stravaUsesUserAccount = false
        stravaError = nil
        if stravaConnected {
            await disconnectStrava()
        }
    }
}

/// Fenêtre de préférences — 5 panes, design éditorial aligné avec
/// la landing page : header numéroté, hairlines, mono small-caps,
/// accent terra. Les controls restent macOS natifs (Toggle, Picker,
/// Slider, DatePicker) pour rester at-home sur macOS.
public struct SettingsView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var coordinator: SettingsCoordinator
    @ObservedObject var coachConfig: CoachConfiguration
    let coachService: CoachService
    @State private var selection: Tab = .general
    @Environment(\.openWindow) private var openWindow
    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    @AppStorage(RunBarPreferences.Key.showGlyph) private var showGlyph: Bool = true
    @AppStorage(RunBarPreferences.Key.showPercent) private var showPercent: Bool = false
    @AppStorage(RunBarPreferences.Key.showStreak) private var showStreak: Bool = false
    @AppStorage(RunBarPreferences.Key.autoSync) private var autoSync: Bool = true
    @AppStorage(RunBarPreferences.Key.notifyVictory) private var notifyVictory: Bool = true
    @AppStorage(RunBarPreferences.Key.trailMode) private var trailMode: Bool = false
    @State private var raceEnabled: Bool = false
    @State private var sliderGoal: Double = 60
    @State private var byoSheetPresented: Bool = false

    private var unit: DistanceUnit {
        get { DistanceUnit(rawValue: unitRaw) ?? .km }
    }

    public init(
        store: ActivityStore,
        coordinator: SettingsCoordinator,
        coachConfig: CoachConfiguration,
        coachService: CoachService
    ) {
        self.store = store
        self.coordinator = coordinator
        self.coachConfig = coachConfig
        self.coachService = coachService
        self._sliderGoal = State(initialValue: store.goal.target)
        self._raceEnabled = State(initialValue: store.goal.raceDate != nil)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case general, display, sources, goals, coach, about
        var id: Self { self }
        var num: String {
            switch self {
            case .general: return "§ 01"
            case .display: return "§ 02"
            case .sources: return "§ 03"
            case .goals:   return "§ 04"
            case .coach:   return "§ 05"
            case .about:   return "§ 06"
            }
        }
        var labelKey: LocalizedStringKey {
            switch self {
            case .general: return "settings.tab.general"
            case .display: return "settings.tab.display"
            case .sources: return "settings.tab.sources"
            case .goals:   return "settings.tab.goals"
            case .coach:   return "settings.tab.coach"
            case .about:   return "settings.tab.about"
            }
        }
        var systemImage: String {
            switch self {
            case .general: return "circle.fill"
            case .display: return "eye"
            case .sources: return "link"
            case .goals:   return "flag"
            case .coach:   return "bubble.left.and.text.bubble.right"
            case .about:   return "info.circle"
            }
        }
    }

    public var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label {
                    Text(tab.labelKey, bundle: .runBarResources)
                } icon: {
                    Image(systemName: tab.systemImage)
                }
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 168, ideal: 180)
        } detail: {
            ScrollView {
                Group {
                    switch selection {
                    case .general: generalPane
                    case .display: displayPane
                    case .sources: sourcesPane
                    case .goals:   goalsPane
                    case .coach:   coachPane
                    case .about:   aboutPane
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 660, height: 480)
        .navigationTitle(Text(selection.labelKey, bundle: .runBarResources))
        .sheet(isPresented: $byoSheetPresented) {
            StravaByoSheet(coordinator: coordinator) {
                byoSheetPresented = false
            }
        }
    }

    // MARK: - Editorial header (per pane)

    private func paneHeader(_ tab: Tab, italicWord: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(tab.num)
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
                Rectangle().fill(.quaternary).frame(width: 22, height: 1)
                Text(tab.labelKey, bundle: .runBarResources)
                    .font(.system(size: 10.5, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            if let italicWord {
                Text(italicWord)
                    .font(.system(size: 26, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)
                    .padding(.top, 2)
            }
            Rectangle()
                .fill(.quaternary.opacity(0.6))
                .frame(height: 1)
                .padding(.top, italicWord == nil ? 6 : 10)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Section card

    private struct PaneSection<Content: View>: View {
        let label: LocalizedStringKey?
        let figure: String?
        let content: Content

        init(_ label: LocalizedStringKey? = nil, figure: String? = nil, @ViewBuilder content: () -> Content) {
            self.label = label
            self.figure = figure
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if label != nil || figure != nil {
                    HStack {
                        if let label {
                            Text(label, bundle: .runBarResources)
                                .font(.system(size: 10, design: .monospaced))
                                .tracking(1.6)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let figure {
                            Text(figure)
                                .font(.system(size: 10, design: .monospaced))
                                .tracking(1.6)
                                .textCase(.uppercase)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.bottom, 10)
                }
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.primary.opacity(0.025))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - General pane

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            paneHeader(.general, italicWord: "Preferences.")

            PaneSection("settings.general.unit", figure: "fig. a") {
                Picker(selection: $unitRaw) {
                    Text("settings.general.unit.km", bundle: .runBarResources).tag(DistanceUnit.km.rawValue)
                    Text("settings.general.unit.mi", bundle: .runBarResources).tag(DistanceUnit.mi.rawValue)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            PaneSection("settings.general.behavior", figure: "fig. b") {
                row {
                    Text("settings.general.autosync", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $autoSync).labelsHidden()
                }
                hairline
                row {
                    Text("settings.general.notify_victory", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $notifyVictory).labelsHidden()
                }
            }

            colophon("Local-first · No ads · MIT")
        }
    }

    // MARK: - Display pane

    private var displayPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            paneHeader(.display, italicWord: "How it shows.")

            PaneSection("settings.display.icon", figure: "fig. a") {
                row {
                    Text("settings.display.show_glyph", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $showGlyph).labelsHidden()
                }
                hairline
                row {
                    Text("settings.display.show_percent", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $showPercent).labelsHidden()
                }
                hairline
                row {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show streak")
                            .font(.system(size: 13))
                        Text("Flame badge appears at 2+ consecutive weeks at goal.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showStreak).labelsHidden()
                }
            }

            PaneSection("settings.display.preview", figure: "live") {
                HStack(spacing: 10) {
                    if showGlyph {
                        RunnerView(state: .jogging)
                            .frame(width: 22, height: 22)
                    }
                    if showPercent {
                        Text("70%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if showStreak {
                        Text("🔥3")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if !showGlyph && !showPercent && !showStreak {
                        Text("(empty)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("menubar · 22pt")
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Sources pane

    private var sourcesPane: some View {
        let comingSoon = String(localized: "settings.sources.coming_soon", bundle: .runBarResources)
        let alwaysOn   = String(localized: "settings.sources.always_active", bundle: .runBarResources)
        let countTemplate = String(localized: "settings.sources.local_data.subtitle", bundle: .runBarResources)

        return VStack(alignment: .leading, spacing: 22) {
            paneHeader(.sources, italicWord: "Where the data comes from.")

            stravaSection

            PaneSection("settings.sources.providers", figure: "fig. b") {
                sourceRow(name: "Apple Health",   status: comingSoon, dotColor: .secondary, available: false)
                hairline
                sourceRow(name: "Garmin Connect", status: comingSoon, dotColor: .secondary, available: false)
                hairline
                sourceRow(name: "Manual entry",   status: alwaysOn,   dotColor: RunBarColor.gold, available: true)
            }

            PaneSection("settings.sources.diagnostic.title", figure: "fig. c") {
                HStack(spacing: 0) {
                    diagnosticMetric(
                        title: String(localized: "settings.sources.diagnostic.strava", bundle: .runBarResources),
                        value: coordinator.stravaConnected
                            ? String(localized: "settings.sources.connected", bundle: .runBarResources)
                            : String(localized: "settings.sources.disconnected", bundle: .runBarResources),
                        color: coordinator.stravaConnected ? RunBarColor.moss : RunBarColor.terra
                    )
                    verticalHairline
                    diagnosticMetric(
                        title: String(localized: "settings.general.autosync", bundle: .runBarResources),
                        value: autoSync
                            ? String(localized: "common.on", bundle: .runBarResources)
                            : String(localized: "common.off", bundle: .runBarResources),
                        color: autoSync ? RunBarColor.moss : Color.secondary
                    )
                    verticalHairline
                    diagnosticMetric(
                        title: String(localized: "settings.sources.diagnostic.local", bundle: .runBarResources),
                        value: "\(store.activities.count)",
                        color: .primary
                    )
                }
            }

            PaneSection("settings.sources.local_data.title", figure: "fig. d") {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: countTemplate, store.activities.count))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        store.clear()
                    } label: {
                        Text("settings.sources.local_data.clear", bundle: .runBarResources)
                    }
                    .controlSize(.small)
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private var stravaRow: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://d3nn82uaxijpm6.cloudfront.net/icon-strava-chrome-192.png")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
            }
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(coordinator.stravaConnected ? RunBarColor.moss : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text("Strava").font(.system(size: 13, weight: .medium))
                }
                Text(coordinator.stravaConnected
                     ? LocalizedStringKey("settings.sources.connected")
                     : LocalizedStringKey("settings.sources.disconnected"),
                     bundle: .runBarResources)
                    .font(.system(size: 10.5, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if coordinator.stravaBusy {
                ProgressView().controlSize(.small)
            } else if coordinator.stravaConnected {
                Button {
                    Task { await coordinator.disconnectStrava() }
                } label: {
                    Text("settings.sources.disconnect", bundle: .runBarResources)
                }
                .controlSize(.small)
                .buttonStyle(PressableButtonStyle())
            } else {
                StravaConnectButton(size: .compact, action: {
                    Task { await coordinator.connectStrava() }
                })
            }
        }
    }

    /// Carte Strava unique. Tant que l'augmentation de quota n'est pas
    /// approuvée par Strava, on n'expose que le flow BYO — l'app partagée
    /// est en "Single Player Mode" (1 athlète max), donc proposer un bouton
    /// "Connect with Strava" standard amènerait l'utilisateur dans une
    /// impasse. Le code `stravaRow` shared reste dans le fichier pour
    /// réactivation rapide une fois le quota approuvé.
    private var stravaSection: some View {
        PaneSection("settings.sources.strava.label", figure: "fig. a") {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.sources.strava.blurb", bundle: .runBarResources)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Circle()
                        .fill(coordinator.stravaConnected ? RunBarColor.moss : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                    Text(coordinator.stravaConnected
                         ? LocalizedStringKey("settings.sources.connected")
                         : LocalizedStringKey("settings.sources.disconnected"),
                         bundle: .runBarResources)
                        .font(.system(size: 10.5, design: .monospaced))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if coordinator.stravaBusy {
                        ProgressView().controlSize(.small)
                    } else if coordinator.stravaConnected {
                        Button {
                            byoSheetPresented = true
                        } label: {
                            Text("settings.sources.byo.manage", bundle: .runBarResources)
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())

                        Button(role: .destructive) {
                            Task { await coordinator.disconnectStrava() }
                        } label: {
                            Text("settings.sources.disconnect", bundle: .runBarResources)
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())
                    } else {
                        Button {
                            byoSheetPresented = true
                        } label: {
                            Text("settings.sources.byo.configure", bundle: .runBarResources)
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())
                    }
                }

                if let err = coordinator.stravaError {
                    HStack(alignment: .top, spacing: 10) {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(RunBarColor.terra)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button {
                            Task { await coordinator.connectStrava() }
                        } label: {
                            Text("settings.sources.reconnect", bundle: .runBarResources)
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private func sourceRow(name: String, status: String, dotColor: Color, available: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5)
                .fill(.quaternary)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: available ? "checkmark" : "clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Circle().fill(dotColor.opacity(0.7)).frame(width: 7, height: 7)
                    Text(name).font(.system(size: 13, weight: .medium))
                }
                Text(status)
                    .font(.system(size: 10.5, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private func diagnosticMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Goals pane

    private var goalsPane: some View {
        let metric = store.goal.metric
        let target = displayTargetValue(store.goal.target, metric: metric)
        let range  = targetRange(metric: metric)
        let step   = targetStep(metric: metric)
        let targetBinding = Binding<Double>(
            get: { displayTargetValue(store.goal.target, metric: store.goal.metric) },
            set: { newDisplayValue in
                store.goal.target = storedTargetValue(newDisplayValue, metric: store.goal.metric)
                sliderGoal = store.goal.target
            }
        )
        return VStack(alignment: .leading, spacing: 22) {
            paneHeader(.goals, italicWord: "Your weekly line.")

            PaneSection("settings.goals.metric", figure: "fig. a") {
                Picker(selection: Binding(
                    get: { store.goal.metric },
                    set: {
                        store.goal.metric = $0
                        store.goal.target = defaultTarget(for: $0)
                        sliderGoal = store.goal.target
                    }
                )) {
                    ForEach(GoalMetric.allCases, id: \.self) { metric in
                        Text(metric.label).tag(metric)
                    }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            PaneSection("settings.goals.section", figure: "fig. b") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("settings.goals.weekly_target", bundle: .runBarResources)
                            .font(.system(size: 13))
                        Spacer()
                        Text("\(Int(target.rounded())) \(targetUnit(metric: metric))")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(RunBarColor.terra)
                    }
                    Slider(value: targetBinding, in: range, step: step) { EmptyView() }
                }
                hairline
                row {
                    Text("settings.goals.reset_day", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Picker(selection: Binding(
                        get: { store.goal.resetWeekday },
                        set: { store.goal.resetWeekday = $0 }
                    )) {
                        Text("Monday").tag(2)
                        Text("Sunday").tag(1)
                    } label: { EmptyView() }
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }
                hairline
                row {
                    Text("settings.display.trail_mode", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $trailMode).labelsHidden()
                }
            }

            PaneSection("settings.goals.race_section", figure: "fig. c") {
                row {
                    Text("settings.goals.race_name", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    TextField("", text: Binding(
                        get: { store.goal.raceName ?? "" },
                        set: { store.goal.raceName = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                }
                hairline
                row {
                    Text("settings.goals.race_date", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { raceEnabled },
                        set: { enabled in
                            raceEnabled = enabled
                            store.goal.raceDate = enabled
                                ? (store.goal.raceDate ?? Date.now.addingTimeInterval(30 * 24 * 3600))
                                : nil
                        }
                    )).labelsHidden()
                }
                if raceEnabled {
                    hairline
                    row {
                        Text("settings.goals.race_date", bundle: .runBarResources)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { store.goal.raceDate ?? .now },
                            set: { store.goal.raceDate = $0 }
                        ), in: Date.now..., displayedComponents: .date)
                        .labelsHidden()
                    }
                    if let days = store.goal.daysUntilRace(), days >= 0 {
                        hairline
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(days)")
                                .font(.system(size: 22, weight: .medium, design: .monospaced))
                                .foregroundStyle(RunBarColor.terra)
                            Text(days == 1 ? "day to go" : "days to go")
                                .font(.system(size: 11, design: .monospaced))
                                .tracking(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if days > 30 {
                                Text("Subtle banner · gets vivid at ≤ 30")
                                    .font(.system(size: 10, design: .monospaced))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("Banner active · vivid mode")
                                    .font(.system(size: 10, design: .monospaced))
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(RunBarColor.moss)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func displayTargetValue(_ stored: Double, metric: GoalMetric) -> Double {
        metric == .distance ? unit.valueFromKilometers(stored) : stored
    }

    private func storedTargetValue(_ display: Double, metric: GoalMetric) -> Double {
        metric == .distance ? unit.toKilometers(display) : display
    }

    private func targetRange(metric: GoalMetric) -> ClosedRange<Double> {
        switch metric {
        case .distance:
            return unit == .km ? 10...150 : 5...95
        case .count:
            return 1...14
        case .elevation:
            return 100...10_000
        }
    }

    private func targetStep(metric: GoalMetric) -> Double {
        switch metric {
        case .distance: return unit == .km ? 5 : 1
        case .count: return 1
        case .elevation: return 100
        }
    }

    private func targetUnit(metric: GoalMetric) -> String {
        metric == .distance ? unit.symbol : metric.unit
    }

    private func defaultTarget(for metric: GoalMetric) -> Double {
        switch metric {
        case .distance: return 60
        case .count: return 4
        case .elevation: return 1_000
        }
    }

    // MARK: - Coach pane

    @State private var coachKeyDraft: String = ""
    @State private var coachKeyMasked: Bool = true
    @State private var coachTestResult: String? = nil
    @State private var coachTestError: String? = nil
    @State private var coachTesting: Bool = false

    private var coachPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            paneHeader(.coach, italicWord: "Your AI coach.")

            if coachService.blockedByStravaPolicy {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RunBarColor.gold)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.coach.policy_paused_title", bundle: .runBarResources)
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("settings.coach.policy_paused_body", bundle: .runBarResources)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(RunBarColor.gold.opacity(0.10))
                )
            }

            PaneSection("settings.coach.section_provider", figure: "fig. a") {
                row {
                    Text("settings.coach.enabled", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $coachConfig.enabled)
                        .labelsHidden()
                }
                hairline
                row {
                    Text("settings.coach.provider", bundle: .runBarResources)
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $coachConfig.provider) {
                        ForEach(CoachConfiguration.Provider.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
            }

            PaneSection("settings.coach.section_key", figure: "fig. b") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        if coachKeyMasked {
                            SecureField("settings.coach.key_placeholder", text: $coachKeyDraft)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("settings.coach.key_placeholder", text: $coachKeyDraft)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: { coachKeyMasked.toggle() }) {
                            Image(systemName: coachKeyMasked ? "eye" : "eye.slash")
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 8) {
                        Button {
                            saveCoachKey()
                        } label: {
                            Text("settings.coach.save", bundle: .runBarResources)
                        }
                        .disabled(coachKeyDraft.isEmpty)

                        Button {
                            testCoachKey()
                        } label: {
                            HStack(spacing: 6) {
                                if coachTesting {
                                    ProgressView().controlSize(.small)
                                }
                                Text("settings.coach.test", bundle: .runBarResources)
                            }
                        }
                        .disabled(coachKeyDraft.isEmpty || coachTesting)

                        Spacer()
                        if coachConfig.hasKey {
                            Button(role: .destructive) {
                                coachConfig.clearKey()
                                coachKeyDraft = ""
                            } label: {
                                Text("settings.coach.remove", bundle: .runBarResources)
                            }
                        }
                    }
                    if let err = coachTestError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(RunBarColor.vermillonDeep)
                            .lineLimit(3)
                    }
                    if let ok = coachTestResult {
                        Text(ok)
                            .font(.system(size: 12, design: .serif).italic())
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Link(destination: coachConfig.provider.apiKeyURL) {
                        Text("settings.coach.get_key", bundle: .runBarResources)
                            .font(.system(size: 11))
                    }
                }
            }

            PaneSection("settings.coach.section_privacy", figure: "fig. c") {
                Text("settings.coach.privacy_disclaimer", bundle: .runBarResources)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func saveCoachKey() {
        coachTestError = nil
        coachTestResult = nil
        do {
            try coachConfig.setKey(coachKeyDraft)
            coachKeyDraft = ""
        } catch {
            coachTestError = error.localizedDescription
        }
    }

    private func testCoachKey() {
        coachTestError = nil
        coachTestResult = nil
        coachTesting = true
        let key = coachKeyDraft
        Task { @MainActor in
            defer { coachTesting = false }
            do {
                let preview = try await coachService.test(apiKey: key)
                coachTestResult = preview
            } catch {
                coachTestError = error.localizedDescription
            }
        }
    }

    // MARK: - About pane

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            paneHeader(.about, italicWord: "RunBar.")

            // Identity card
            HStack(alignment: .top, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.quaternary.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.quaternary, lineWidth: 0.5)
                        )
                    RunnerView(state: .jogging, color: RunBarColor.moss)
                        .frame(width: 44, height: 44)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("RunBar")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                    Text(String(
                        format: String(localized: "settings.about.version", bundle: .runBarResources),
                        // Read the actual bundled version instead of a stale
                        // hard-coded "0.1.0" — we ship a new build every time
                        // we bump CFBundleShortVersionString in package-app.sh.
                        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                    ))
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.tertiary)
                    Text("settings.about.tagline", bundle: .runBarResources)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                Spacer()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )

            PaneSection("settings.about.actions", figure: "fig. a") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://runbar.app/download/RunBar.dmg")!)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.down.circle")
                                Text("settings.about.check_updates", bundle: .runBarResources)
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())

                        Spacer()

                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/Rod292/runbar")!)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text("Source")
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())
                    }

                    HStack {
                        Button {
                            // Bump a token that OnboardingView observes via
                            // @AppStorage. Without this, the SwiftUI Window
                            // scene reuses the existing OnboardingView
                            // instance — so its @State `step` lingers at 7
                            // (the Done screen) from the previous run, and
                            // "Restart" only re-shows the Finish button.
                            let token = UserDefaults.standard.integer(forKey: "runbar.onboarding.restartToken")
                            UserDefaults.standard.set(token + 1, forKey: "runbar.onboarding.restartToken")
                            UserDefaults.standard.set(false, forKey: "runbar.onboardingDone")
                            openWindow(id: "onboarding")
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Restart onboarding")
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(PressableButtonStyle())

                        Spacer()
                    }
                }
            }

            // Dedicated support card — Ko-fi orange #ff4400, mug icon,
            // "Buy Me a Gel" label. Made prominent enough to actually be
            // seen (the previous version was a small row inside the
            // Actions list and was invisible at a glance).
            supportCard

            colophon("MIT · 2026 · Made with care")
        }
    }

    private var supportCard: some View {
        let kofiOrange = Color(red: 0xFF / 255, green: 0x44 / 255, blue: 0x00 / 255)
        return HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Free, MIT-licensed.")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)
                Text("If RunBar moves your week — fuel the runner.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                NSWorkspace.shared.open(URL(string: "https://ko-fi.com/V7V11Z3VNE")!)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Buy Me a Gel")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(kofiOrange)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(kofiOrange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(kofiOrange.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Tiny helpers

    @ViewBuilder
    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) { content() }
            .frame(minHeight: 26)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 0.5)
            .padding(.horizontal, 12)
    }

    private func colophon(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

/// Sheet "Use my own Strava API client" — instructions pas-à-pas pour créer
/// une OAuth app personnelle sur https://www.strava.com/settings/api, plus
/// les champs Client ID / Client Secret. Indispensable tant que l'app
/// partagée n'a pas reçu l'augmentation de quota Strava.
struct StravaByoSheet: View {
    @ObservedObject var coordinator: SettingsCoordinator
    let dismiss: () -> Void

    @State private var clientID: String = StravaUserCredentialsStore.clientID
    @State private var clientSecret: String = StravaUserCredentialsStore.clientSecret
    @State private var saving: Bool = false

    private var canSave: Bool {
        !saving
            && !clientID.trimmingCharacters(in: .whitespaces).isEmpty
            && !clientSecret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    instructions
                    credentialsForm
                    if let err = coordinator.stravaError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(RunBarColor.terra)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
            }
            footer
        }
        .frame(width: 560, height: 600)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("§ BYO")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
                Rectangle().fill(.quaternary).frame(width: 22, height: 1)
                Text("settings.sources.byo.sheet.eyebrow", bundle: .runBarResources)
                    .font(.system(size: 10.5, design: .monospaced))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            Text("settings.sources.byo.sheet.title", bundle: .runBarResources)
                .font(.system(size: 26, weight: .medium, design: .serif))
                .italic()
            Rectangle()
                .fill(.quaternary.opacity(0.6))
                .frame(height: 1)
                .padding(.top, 6)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("settings.sources.byo.sheet.intro", bundle: .runBarResources)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                step(num: "1", textKey: "settings.sources.byo.sheet.step1")
                step(num: "2", textKey: "settings.sources.byo.sheet.step2")
                step(num: "3", textKey: "settings.sources.byo.sheet.step3")
                step(num: "4", textKey: "settings.sources.byo.sheet.step4")
                step(num: "5", textKey: "settings.sources.byo.sheet.step5")
            }

            Button {
                NSWorkspace.shared.open(URL(string: "https://www.strava.com/settings/api")!)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.forward.square")
                    Text("settings.sources.byo.sheet.open_strava", bundle: .runBarResources)
                }
            }
            .controlSize(.small)
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func step(num: String, textKey: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(RunBarColor.terra)
                .frame(width: 18, alignment: .leading)
            Text(textKey, bundle: .runBarResources)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var credentialsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.sources.byo.sheet.form_title", bundle: .runBarResources)
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("settings.sources.byo.sheet.client_id", bundle: .runBarResources)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                TextField("", text: $clientID, prompt: Text("123456"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("settings.sources.byo.sheet.client_secret", bundle: .runBarResources)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                SecureField("", text: $clientSecret, prompt: Text("a1b2c3…"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if coordinator.stravaUsesUserAccount {
                Button(role: .destructive) {
                    Task {
                        saving = true
                        await coordinator.clearUserStravaCredentials()
                        clientID = ""
                        clientSecret = ""
                        saving = false
                    }
                } label: {
                    Text("settings.sources.byo.sheet.reset", bundle: .runBarResources)
                }
                .controlSize(.regular)
                .buttonStyle(PressableButtonStyle())
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("settings.sources.byo.sheet.cancel", bundle: .runBarResources)
            }
            .controlSize(.regular)
            .buttonStyle(PressableButtonStyle())
            Button {
                Task {
                    saving = true
                    await coordinator.saveUserStravaCredentials(
                        clientID: clientID,
                        clientSecret: clientSecret
                    )
                    // Save alone doesn't reconnect — the button is labelled
                    // "Save & reconnect", so we must actually drive the OAuth
                    // flow ourselves. Mirrors what the onboarding ConnectStep
                    // does on first connect.
                    if coordinator.stravaError == nil {
                        await coordinator.connectStrava()
                        if coordinator.stravaConnected {
                            await coordinator.seedHistoricalSnapshots(daysBack: 56)
                        }
                    }
                    saving = false
                    if coordinator.stravaError == nil {
                        dismiss()
                    }
                }
            } label: {
                if saving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("settings.sources.byo.sheet.save", bundle: .runBarResources)
                }
            }
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .tint(RunBarColor.terra)
            .disabled(!canSave)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(.quaternary.opacity(0.25))
                .overlay(Rectangle().fill(.quaternary).frame(height: 0.5), alignment: .top)
        )
    }
}

#if DEBUG
#Preview {
    let store = ActivityStore()
    let snaps = SnapshotStore()
    let cfg = CoachConfiguration()
    let coach = CoachService(store: store, snapshots: snaps, configuration: cfg)
    return SettingsView(
        store: store,
        coordinator: SettingsCoordinator(strava: StravaService.preview),
        coachConfig: cfg,
        coachService: coach
    )
}
#endif
