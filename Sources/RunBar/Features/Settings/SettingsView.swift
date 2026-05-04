import SwiftUI

/// Coordonnateur léger pour ouvrir la fenêtre Settings depuis le popover.
@MainActor
public final class SettingsCoordinator: ObservableObject {
    @Published public var isOpen: Bool = false
    @Published public var stravaConnected: Bool = false
    @Published public var stravaBusy: Bool = false
    @Published public var stravaError: String? = nil

    public let strava: StravaServiceProtocol

    public init(strava: StravaServiceProtocol) {
        self.strava = strava
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
        } catch {
            stravaError = error.localizedDescription
        }
    }

    public func disconnectStrava() async {
        await strava.disconnect()
        await refreshStravaStatus()
    }
}

/// Fenêtre de préférences — 5 onglets : Général, Affichage, Sources, Objectifs, À propos.
public struct SettingsView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var coordinator: SettingsCoordinator
    @State private var selection: Tab = .general
    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    @AppStorage(RunBarPreferences.Key.showGlyph) private var showGlyph: Bool = true
    @AppStorage(RunBarPreferences.Key.showPercent) private var showPercent: Bool = false
    @AppStorage(RunBarPreferences.Key.autoSync) private var autoSync: Bool = true
    @AppStorage(RunBarPreferences.Key.notifyVictory) private var notifyVictory: Bool = true
    @AppStorage(RunBarPreferences.Key.trailMode) private var trailMode: Bool = false
    @State private var raceEnabled: Bool = false
    @State private var sliderGoal: Double = 60

    private var unit: DistanceUnit {
        get { DistanceUnit(rawValue: unitRaw) ?? .km }
    }

    public init(store: ActivityStore, coordinator: SettingsCoordinator) {
        self.store = store
        self.coordinator = coordinator
        self._sliderGoal = State(initialValue: store.goal.target)
        self._raceEnabled = State(initialValue: store.goal.raceDate != nil)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case general, display, sources, goals, about
        var id: Self { self }
        var labelKey: LocalizedStringKey {
            switch self {
            case .general: return "settings.tab.general"
            case .display: return "settings.tab.display"
            case .sources: return "settings.tab.sources"
            case .goals:   return "settings.tab.goals"
            case .about:   return "settings.tab.about"
            }
        }
        var systemImage: String {
            switch self {
            case .general: return "circle.fill"
            case .display: return "eye"
            case .sources: return "link"
            case .goals:   return "flag"
            case .about:   return "info.circle"
            }
        }
    }

    public var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label {
                    Text(tab.labelKey, bundle: .module)
                } icon: {
                    Image(systemName: tab.systemImage)
                }
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 170)
        } detail: {
            ScrollView {
                Group {
                    switch selection {
                    case .general: generalPane
                    case .display: displayPane
                    case .sources: sourcesPane
                    case .goals:   goalsPane
                    case .about:   aboutPane
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 620, height: 440)
        .navigationTitle(Text("settings.tab.general", bundle: .module))
    }

    // MARK: Panes

    private var generalPane: some View {
        Form {
            Picker(selection: $unitRaw) {
                Text("settings.general.unit.km", bundle: .module).tag(DistanceUnit.km.rawValue)
                Text("settings.general.unit.mi", bundle: .module).tag(DistanceUnit.mi.rawValue)
            } label: {
                Text("settings.general.unit", bundle: .module)
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $autoSync) {
                Text("settings.general.autosync", bundle: .module)
            }
            Toggle(isOn: $notifyVictory) {
                Text("settings.general.notify_victory", bundle: .module)
            }
        }
        .formStyle(.grouped)
    }

    private var displayPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                Toggle(isOn: $showGlyph) {
                    Text("settings.display.show_glyph", bundle: .module)
                }
                Toggle(isOn: $showPercent) {
                    Text("settings.display.show_percent", bundle: .module)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if showGlyph {
                        RunnerView(state: .jogging)
                            .frame(width: 20, height: 20)
                    }
                    if showPercent {
                        Text("70%").font(.system(size: 12).monospaced())
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            }
        }
    }

    private var sourcesPane: some View {
        let comingSoon = String(localized: "settings.sources.coming_soon", bundle: .module)
        let alwaysOn = String(localized: "settings.sources.always_active", bundle: .module)
        let countTemplate = String(localized: "settings.sources.local_data.subtitle", bundle: .module)
        return VStack(alignment: .leading, spacing: 8) {
            stravaRow
            sourceRow(name: "Apple Health",    status: comingSoon, canConnect: false)
            sourceRow(name: "Garmin Connect",  status: comingSoon, canConnect: false)
            sourceRow(name: "Manual entry",    status: alwaysOn,   canConnect: false)
            if let err = coordinator.stravaError {
                Text(err).font(.caption).foregroundStyle(.red).padding(.top, 4)
            }

            Divider().padding(.vertical, 8)

            diagnosticPanel

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.sources.local_data.title", bundle: .module)
                        .font(.system(size: 13, weight: .medium))
                    Text(String(format: countTemplate, store.activities.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    store.clear()
                } label: {
                    Text("settings.sources.local_data.clear", bundle: .module)
                }
                .controlSize(.small)
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        }
    }

    private var stravaRow: some View {
        HStack {
            AsyncImage(url: URL(string: "https://d3nn82uaxijpm6.cloudfront.net/icon-strava-chrome-192.png")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.clear
            }
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Circle()
                .fill(coordinator.stravaConnected ? RunBarColor.moss : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text("Strava").font(.system(size: 13, weight: .medium))
            Spacer()
            Text(coordinator.stravaConnected
                 ? LocalizedStringKey("settings.sources.connected")
                 : LocalizedStringKey("settings.sources.disconnected"),
                 bundle: .module)
                .font(.caption).foregroundStyle(.secondary)
            if coordinator.stravaBusy {
                ProgressView().controlSize(.small)
            } else if coordinator.stravaConnected {
                Button {
                    Task { await coordinator.disconnectStrava() }
                } label: {
                    Text("settings.sources.disconnect", bundle: .module)
                }
                .controlSize(.small)
                .buttonStyle(PressableButtonStyle())
            } else {
                Button {
                    Task { await coordinator.connectStrava() }
                } label: {
                    Text("settings.sources.connect", bundle: .module)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(RunBarColor.moss)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
    }

    private var diagnosticPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("settings.sources.diagnostic.title", bundle: .module)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            HStack(spacing: 0) {
                diagnosticMetric(
                    title: String(localized: "settings.sources.diagnostic.strava", bundle: .module),
                    value: coordinator.stravaConnected
                        ? String(localized: "settings.sources.connected", bundle: .module)
                        : String(localized: "settings.sources.disconnected", bundle: .module),
                    color: coordinator.stravaConnected ? RunBarColor.moss : RunBarColor.terra
                )
                Divider().padding(.horizontal, 12)
                diagnosticMetric(
                    title: String(localized: "settings.general.autosync", bundle: .module),
                    value: autoSync
                        ? String(localized: "common.on", bundle: .module)
                        : String(localized: "common.off", bundle: .module),
                    color: autoSync ? RunBarColor.moss : Color.secondary
                )
                Divider().padding(.horizontal, 12)
                diagnosticMetric(
                    title: String(localized: "settings.sources.diagnostic.local", bundle: .module),
                    value: "\(store.activities.count)",
                    color: RunBarColor.slate
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
    }

    private func diagnosticMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceRow(name: String, status: String, canConnect: Bool) -> some View {
        HStack {
            Circle()
                .fill(canConnect ? RunBarColor.gold : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(name).font(.system(size: 13, weight: .medium))
            Spacer()
            Text(status).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
    }

    private var goalsPane: some View {
        let metric = store.goal.metric
        let target = displayTargetValue(store.goal.target, metric: metric)
        let range = targetRange(metric: metric)
        let step = targetStep(metric: metric)
        let targetBinding = Binding<Double>(
            get: { displayTargetValue(store.goal.target, metric: store.goal.metric) },
            set: { newDisplayValue in
                store.goal.target = storedTargetValue(newDisplayValue, metric: store.goal.metric)
                sliderGoal = store.goal.target
            }
        )
        return Form {
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
            } label: {
                Text("settings.goals.metric", bundle: .module)
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("settings.goals.weekly_target", bundle: .module)
                        Spacer()
                        Text("\(Int(target.rounded())) \(targetUnit(metric: metric))")
                            .font(.system(size: 13, weight: .semibold).monospaced())
                    }
                    Slider(value: targetBinding, in: range, step: step) {
                        EmptyView()
                    }
                }
                Picker(selection: Binding(
                    get: { store.goal.resetWeekday },
                    set: { store.goal.resetWeekday = $0 }
                )) {
                    Text("Lundi").tag(2)
                    Text("Dimanche").tag(1)
                } label: {
                    Text("settings.goals.reset_day", bundle: .module)
                }
                Toggle(isOn: $trailMode) {
                    Text("settings.display.trail_mode", bundle: .module)
                }
            } header: {
                Text("settings.goals.section", bundle: .module)
            }

            Section {
                TextField(text: Binding(
                    get: { store.goal.raceName ?? "" },
                    set: { store.goal.raceName = $0.isEmpty ? nil : $0 }
                )) {
                    Text("settings.goals.race_name", bundle: .module)
                }
                Toggle(isOn: Binding(
                    get: { raceEnabled },
                    set: { enabled in
                        raceEnabled = enabled
                        store.goal.raceDate = enabled ? (store.goal.raceDate ?? Date.now.addingTimeInterval(30 * 24 * 3600)) : nil
                    }
                )) {
                    Text("settings.goals.race_date", bundle: .module)
                }
                if raceEnabled {
                    DatePicker(selection: Binding(
                        get: { store.goal.raceDate ?? .now },
                        set: { store.goal.raceDate = $0 }
                    ), in: Date.now..., displayedComponents: .date) {
                        Text("settings.goals.race_date", bundle: .module)
                    }
                }
            } header: {
                Text("settings.goals.race_section", bundle: .module)
            }
        }
        .formStyle(.grouped)
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

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                    RunnerView(state: .jogging, color: RunBarColor.moss)
                        .frame(width: 40, height: 40)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("RunBar").font(.system(size: 16, weight: .semibold))
                    Text(String(format: String(localized: "settings.about.version", bundle: .module), "0.1.0"))
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text("settings.about.tagline", bundle: .module)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360, alignment: .leading)
            Button {
                NSWorkspace.shared.open(URL(string: "https://runbar.app/download/RunBar.dmg")!)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.circle")
                    Text("settings.about.check_updates", bundle: .module)
                }
            }
            .controlSize(.small)
            .buttonStyle(PressableButtonStyle())
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(store: ActivityStore(), coordinator: SettingsCoordinator(strava: StravaService.preview))
}
#endif
