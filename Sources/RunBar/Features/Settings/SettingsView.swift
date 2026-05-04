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
    @AppStorage("runbar.showGlyph") private var showGlyph: Bool = true
    @AppStorage("runbar.showPercent") private var showPercent: Bool = false
    @AppStorage("runbar.autoSync") private var autoSync: Bool = true
    @AppStorage("runbar.notifyVictory") private var notifyVictory: Bool = true
    @AppStorage("runbar.trailMode") private var trailMode: Bool = false
    @State private var sliderGoal: Double = 60

    private var unit: DistanceUnit {
        get { DistanceUnit(rawValue: unitRaw) ?? .km }
    }

    public init(store: ActivityStore, coordinator: SettingsCoordinator) {
        self.store = store
        self.coordinator = coordinator
        self._sliderGoal = State(initialValue: store.goal.target)
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
        // Le slider et le store sont en km. On affiche dans l'unité préférée.
        let displayValue = unit.valueFromKilometers(sliderGoal)
        let displayMin = unit.valueFromKilometers(10)
        let displayMax = unit.valueFromKilometers(150)
        let targetLabelKey: LocalizedStringKey = unit == .km
            ? "settings.goals.weekly_target"
            : "settings.goals.weekly_target_mi"
        return Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text(targetLabelKey, bundle: .module)
                        Spacer()
                        Text("\(Int(displayValue.rounded())) \(unit.symbol)")
                            .font(.system(size: 13, weight: .semibold).monospaced())
                    }
                    Slider(value: Binding(
                        get: { displayValue },
                        set: { newDisplayValue in
                            sliderGoal = unit.toKilometers(newDisplayValue)
                        }
                    ), in: displayMin...displayMax, step: unit == .km ? 5 : 1) {
                        EmptyView()
                    } onEditingChanged: { editing in
                        if !editing { store.goal.target = sliderGoal }
                    }
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
                if store.goal.raceDate != nil {
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
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(store: ActivityStore(), coordinator: SettingsCoordinator(strava: StravaService.preview))
}
#endif
