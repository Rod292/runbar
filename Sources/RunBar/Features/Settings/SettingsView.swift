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

/// Fenêtre de préférences — réplique le mockup `extras.jsx > SettingsWindow`.
/// 5 onglets : Général, Affichage, Sources, Objectifs, À propos.
public struct SettingsView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var coordinator: SettingsCoordinator
    @State private var selection: Tab = .general
    @State private var unit: Unit = .km
    @State private var showGlyph: Bool = true
    @State private var showPercent: Bool = true
    @State private var autoSync: Bool = true
    @State private var notifyVictory: Bool = true
    @State private var trailMode: Bool = false
    @State private var sliderGoal: Double = 60

    public init(store: ActivityStore, coordinator: SettingsCoordinator) {
        self.store = store
        self.coordinator = coordinator
        self._sliderGoal = State(initialValue: store.goal.target)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case general, display, sources, goals, about
        var id: Self { self }
        var label: String {
            switch self {
            case .general: return "Général"
            case .display: return "Affichage"
            case .sources: return "Sources"
            case .goals:   return "Objectifs"
            case .about:   return "À propos"
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

    enum Unit: String, CaseIterable, Identifiable {
        case km, mi
        var id: Self { self }
    }

    public var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tab.label, systemImage: tab.systemImage)
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
        .navigationTitle("RunBar — Préférences")
    }

    // MARK: Panes

    private var generalPane: some View {
        Form {
            Picker("Unités", selection: $unit) {
                Text("Kilomètres").tag(Unit.km)
                Text("Miles").tag(Unit.mi)
            }
            .pickerStyle(.segmented)

            Toggle("Lancer au démarrage", isOn: $autoSync)
            Toggle("Synchro auto (toutes les 30 min)", isOn: $autoSync)
            Toggle("Notification d'objectif", isOn: $notifyVictory)
        }
        .formStyle(.grouped)
    }

    private var displayPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                Toggle("Glyphe coureur", isOn: $showGlyph)
                Toggle("Pourcentage", isOn: $showPercent)
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 8) {
                Text("APERÇU")
                    .font(.system(size: 10, weight: .semibold).monospaced())
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if showGlyph {
                        RunnerView(state: .jogging)
                            .frame(width: 20, height: 20)
                    }
                    if showPercent {
                        Text("70%").font(.system(size: 12).monospaced())
                    }
                    if !showGlyph && !showPercent {
                        Text("(rien à afficher)")
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            }
        }
    }

    private var sourcesPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            stravaRow
            sourceRow(name: "Apple Health",   status: "À venir",   canConnect: false)
            sourceRow(name: "Garmin Connect", status: "À venir",   canConnect: false)
            sourceRow(name: "Saisie manuelle", status: "Toujours actif", canConnect: false)
            if let err = coordinator.stravaError {
                Text(err).font(.caption).foregroundStyle(.red).padding(.top, 4)
            }
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
            Text(coordinator.stravaConnected ? "Connecté" : "Non connecté")
                .font(.caption).foregroundStyle(.secondary)
            if coordinator.stravaBusy {
                ProgressView().controlSize(.small)
            } else if coordinator.stravaConnected {
                Button("Déconnecter") {
                    Task { await coordinator.disconnectStrava() }
                }
                .controlSize(.small)
            } else {
                Button("Connecter") {
                    Task { await coordinator.connectStrava() }
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
        Form {
            Section("Objectif hebdo") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Cible")
                        Spacer()
                        Text("\(Int(sliderGoal)) \(store.goal.metric.unit)")
                            .font(.system(size: 13, weight: .semibold).monospaced())
                    }
                    Slider(value: $sliderGoal, in: 10...150, step: 5) {
                        EmptyView()
                    } onEditingChanged: { editing in
                        if !editing { store.goal.target = sliderGoal }
                    }
                }
                Picker("Métrique", selection: $store.goal.metric) {
                    ForEach(GoalMetric.allCases, id: \.self) { m in
                        Text(m.label).tag(m)
                    }
                }
                Picker("Reset", selection: $store.goal.resetWeekday) {
                    Text("Lundi").tag(2)
                    Text("Dimanche").tag(1)
                }
                Toggle("Trail mode (pondération D+)", isOn: $trailMode)
            }

            Section("Course visée") {
                TextField("Nom de la course", text: Binding(
                    get: { store.goal.raceName ?? "" },
                    set: { store.goal.raceName = $0.isEmpty ? nil : $0 }
                ))
                Toggle("Activer une course", isOn: Binding(
                    get: { store.goal.raceDate != nil },
                    set: { enabled in
                        store.goal.raceDate = enabled
                            ? Calendar.iso8601Monday.date(byAdding: .day, value: 30, to: .now)
                            : nil
                    }
                ))
                if store.goal.raceDate != nil {
                    DatePicker("Date", selection: Binding(
                        get: { store.goal.raceDate ?? .now },
                        set: { store.goal.raceDate = $0 }
                    ), in: Date.now..., displayedComponents: .date)
                }
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
                    Text("v0.1.0 · Bretagne")
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text("Un compteur de course discret pour la barre des menus. Conçu sur les chemins côtiers, pour ceux qui aiment voir où ils en sont sans interrompre leur journée.")
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
