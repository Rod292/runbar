import AppKit
import Combine
import Foundation
import SwiftUI

public enum PopoverMode: String, Sendable {
    case empty
    case normal
    case victory
}

/// ViewModel du popover. Wrapping autour de l'`ActivityStore` + `GoalCalculator`.
@MainActor
public final class PopoverViewModel: ObservableObject {
    @Published public var activitiesThisWeek: [Activity] = []
    @Published public var goal: WeeklyGoal = .default
    @Published public var lastSync: Date? = nil
    @Published public var isSyncing: Bool = false
    @Published public var lastError: String? = nil
    @Published public var lastImportedActivityCount: Int? = nil
    @Published public var pendingSuggestion: GoalSuggestion? = nil
    @Published public var coachMessage: CoachMessage? = nil
    @Published public var coachIsFetching: Bool = false

    public var settingsCoordinator: SettingsCoordinator? {
        didSet {
            settingsCancellable = settingsCoordinator?.objectWillChange.sink { [weak self] _ in
                Task { @MainActor in self?.objectWillChange.send() }
            }
        }
    }

    private let store: ActivityStore
    private let calculator = GoalCalculator()
    private let syncManager: SyncManager
    private let snapshots: SnapshotStore?
    private let suggestions: GoalSuggestionStore?
    private let coach: CoachService?
    private var cancellables = Set<AnyCancellable>()
    private var settingsCancellable: AnyCancellable?

    public init(
        store: ActivityStore,
        syncManager: SyncManager,
        snapshots: SnapshotStore? = nil,
        suggestions: GoalSuggestionStore? = nil,
        coach: CoachService? = nil
    ) {
        self.store = store
        self.syncManager = syncManager
        self.snapshots = snapshots
        self.suggestions = suggestions
        self.coach = coach
        bind()
    }

    /// Streak "goal completion" — semaines consécutives où la cible (km/runs/D+)
    /// est atteinte. Strict, aspirationnel — affiché dans le badge popover.
    public var currentStreak: Int {
        snapshots?.currentStreak ?? 0
    }

    /// Streak "activité" — semaines consécutives avec au moins 1 sortie,
    /// indépendamment du goal. Convention Strava — affiché dans le menu bar.
    public var currentRunStreak: Int {
        let cal = Calendar.iso8601Monday
        let thisMonday = Date.now.startOfWeek(weekday: goal.resetWeekday)
        var streak = 0
        var weekStart = thisMonday

        // Si la semaine en cours n'a pas encore eu de sortie, on démarre la
        // semaine précédente — la streak ne se "casse" pas tant que la
        // semaine en cours n'est pas terminée.
        if activitiesThisWeek.isEmpty {
            weekStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        }

        while streak < 250 { // safety cap
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let hasActivity = store.activities.contains { $0.startDate >= weekStart && $0.startDate < weekEnd }
            if hasActivity {
                streak += 1
                weekStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            } else {
                break
            }
        }
        return streak
    }

    public var recentSnapshots: [WeeklySnapshot] {
        snapshots?.recent(limit: 8) ?? []
    }

    /// Record progression de la semaine en cours dans le store de snapshots.
    /// Appelé après chaque sync pour que le streak soit à jour.
    public func recordCurrentWeek() {
        guard let snapshots else { return }
        let monday = Date.now.startOfWeek(weekday: goal.resetWeekday)
        let previousValue = snapshots.snapshots.first(where: {
            $0.weekStart == monday
        })?.achieved ?? 0
        let value = currentValue
        snapshots.record(weekStart: monday, metric: goal.metric,
                          target: goal.target, achieved: value)

        // Victory : on franchit la ligne pour la première fois cette semaine.
        let target = goal.target
        if RunBarPreferences.notifyVictory, previousValue < target && value >= target {
            playVictorySound()
            Task {
                await NotificationService.shared.notifyVictory(
                    distanceKm: value, target: target, unit: goal.metric.unit
                )
            }
        }

        // Re-programme le récap dominical avec les valeurs à jour.
        let tier = RunnerTier.tier(forKm: target).label
        Task {
            await NotificationService.shared.scheduleSundayRecap(
                achieved: value, target: target, unit: goal.metric.unit,
                tier: tier, streak: currentStreak
            )
        }
    }

    public func recordRecentWeeks() {
        guard let snapshots else { return }
        let cal = Calendar.iso8601Monday
        let thisStart = Date.now.startOfWeek(weekday: goal.resetWeekday)
        // 104 semaines = 2 ans. Aligné sur la fenêtre de sync Strava.
        // Permet à `StreakCalculator` de remonter aussi loin que les données.
        for offset in 1..<104 {
            guard
                let start = cal.date(byAdding: .day, value: -7 * offset, to: thisStart),
                let end = cal.date(byAdding: .day, value: 7, to: start)
            else { continue }
            let weekActivities = store.activities.filter { $0.startDate >= start && $0.startDate < end }
            guard !weekActivities.isEmpty else { continue }
            let value = calculator.currentValue(activities: weekActivities, goal: goal)
            snapshots.record(weekStart: start, metric: goal.metric, target: goal.target, achieved: value)
        }
    }

    private func playVictorySound() {
        // Son discret « Glass » du système.
        NSSound(named: NSSound.Name("Glass"))?.play()
    }

    private func bind() {
        store.$activities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] all in
                guard let self else { return }
                self.activitiesThisWeek = self.calculator.activitiesThisWeek(all, goal: self.goal)
                self.recordRecentWeeks()
                self.recordCurrentWeek()
            }
            .store(in: &cancellables)

        store.$goal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goal in
                guard let self else { return }
                self.goal = goal
                self.activitiesThisWeek = self.calculator.activitiesThisWeek(self.store.activities, goal: goal)
                self.recordRecentWeeks()
                self.recordCurrentWeek()
            }
            .store(in: &cancellables)

        syncManager.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)

        syncManager.$lastSync
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastSync, on: self)
            .store(in: &cancellables)

        syncManager.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)

        syncManager.$lastImportedActivityCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastImportedActivityCount, on: self)
            .store(in: &cancellables)

        if let suggestions {
            suggestions.$pending
                .receive(on: DispatchQueue.main)
                .assign(to: \.pendingSuggestion, on: self)
                .store(in: &cancellables)

            // Re-évalue la suggestion à chaque fin de sync (et au démarrage,
            // qui pousse `lastSync = nil`).
            syncManager.$lastSync
                .receive(on: DispatchQueue.main)
                .sink { [weak suggestions] _ in suggestions?.refresh() }
                .store(in: &cancellables)
        }

        if let coach {
            coach.$current
                .receive(on: DispatchQueue.main)
                .assign(to: \.coachMessage, on: self)
                .store(in: &cancellables)

            coach.$isFetching
                .receive(on: DispatchQueue.main)
                .assign(to: \.coachIsFetching, on: self)
                .store(in: &cancellables)

            // Régénère après chaque sync, si due.
            syncManager.$lastSync
                .receive(on: DispatchQueue.main)
                .sink { [weak coach] _ in coach?.refreshIfDue() }
                .store(in: &cancellables)
        }
    }

    // MARK: Derived

    public var currentValue: Double {
        calculator.currentValue(activities: activitiesThisWeek, goal: goal)
    }

    public var progress: Double {
        calculator.progress(activities: activitiesThisWeek, goal: goal)
    }

    public var runnerState: RunnerState {
        let recency: TimeInterval? = activitiesThisWeek.last.map { Date.now.timeIntervalSince($0.startDate) }
        return calculator.runnerState(
            progress: progress,
            dayOfWeek: Date.now.dayOfWeek(),
            lastSyncRecency: recency
        )
    }

    public var mode: PopoverMode {
        if progress >= 1.0 { return .victory }
        if activitiesThisWeek.isEmpty { return .empty }
        return .normal
    }

    public var lastSyncLabel: String {
        // Pas connecté → on n'invente pas un "Synced just now" mensonger.
        if !stravaConnected {
            return String(localized: "popover.status.connect_title", bundle: .runBarResources)
        }
        if let lastError, !lastError.isEmpty {
            return String(localized: "popover.last_sync_failed", bundle: .runBarResources)
        }
        guard let last = lastSync else {
            // Connecté mais jamais syncé encore.
            return String(localized: "popover.status.waiting_title", bundle: .runBarResources)
        }
        let secs = Date.now.timeIntervalSince(last)
        if secs < 60 {
            return String(localized: "popover.last_sync_now", bundle: .runBarResources)
        }
        let minutes = Int(secs / 60)
        if minutes < 60 {
            let template = String(localized: "popover.last_sync_min", bundle: .runBarResources)
            return String(format: template, minutes)
        }
        let hours = minutes / 60
        let template = String(localized: "popover.last_sync_hour", bundle: .runBarResources)
        return String(format: template, hours)
    }

    public var statusKind: PopoverStatusKind {
        if !stravaConnected { return .needsConnection }
        if let lastError, !lastError.isEmpty { return .error }
        if isSyncing { return .syncing }
        if lastSync == nil { return .waitingForSync }
        if lastImportedActivityCount == 0 && store.activities.isEmpty { return .noActivities }
        return .ready
    }

    public var statusTitle: String {
        switch statusKind {
        case .needsConnection:
            return String(localized: "popover.status.connect_title", bundle: .runBarResources)
        case .error:
            return String(localized: "popover.status.error_title", bundle: .runBarResources)
        case .syncing:
            return String(localized: "popover.status.syncing_title", bundle: .runBarResources)
        case .waitingForSync:
            return String(localized: "popover.status.waiting_title", bundle: .runBarResources)
        case .noActivities:
            return String(localized: "popover.status.no_activities_title", bundle: .runBarResources)
        case .ready:
            return String(localized: "popover.status.ready_title", bundle: .runBarResources)
        }
    }

    public var statusDetail: String {
        switch statusKind {
        case .needsConnection:
            return String(localized: "popover.status.connect_detail", bundle: .runBarResources)
        case .error:
            return lastError ?? String(localized: "popover.status.error_detail", bundle: .runBarResources)
        case .syncing:
            return String(localized: "popover.status.syncing_detail", bundle: .runBarResources)
        case .waitingForSync:
            return String(localized: "popover.status.waiting_detail", bundle: .runBarResources)
        case .noActivities:
            return String(localized: "popover.status.no_activities_detail", bundle: .runBarResources)
        case .ready:
            return lastSyncLabel
        }
    }

    public var averagePaceLabel: String {
        let runs = activitiesThisWeek.filter { $0.distance > 0 && $0.movingTime > 0 }
        guard !runs.isEmpty else { return "—" }
        let totalTime = runs.reduce(0) { $0 + $1.movingTime }
        let unit = UnitPreferences.current
        // Allure exprimée dans l'unité préférée (min/km ou min/mi).
        let totalDistanceInUnit: Double = {
            switch unit {
            case .km: return runs.reduce(0) { $0 + $1.distanceKm }
            case .mi: return runs.reduce(0) { $0 + ($1.distance / 1609.344) }
            }
        }()
        guard totalDistanceInUnit > 0 else { return "—" }
        let secsPerUnit = Double(totalTime) / totalDistanceInUnit
        let minutes = Int(secsPerUnit) / 60
        let seconds = Int(secsPerUnit) % 60
        return String(format: "%d:%02d/%@", minutes, seconds, unit.symbol)
    }

    public func timeLabel(for activity: Activity) -> String {
        let total = activity.movingTime
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h\(String(format: "%02d", m))"
        }
        return "\(m)'"
    }

    // MARK: Actions

    public func syncNow() {
        Task { await syncManager.syncNow() }
    }

    public func openSettings() {
        settingsCoordinator?.bringToFront()
    }

    public var stravaConnected: Bool {
        settingsCoordinator?.stravaConnected ?? false
    }

    public func connectStrava() {
        guard let coord = settingsCoordinator else { return }
        Task { await coord.connectStrava() }
    }

    public func close() {
        NotificationCenter.default.post(name: .runbarClosePopover, object: nil)
    }

    // MARK: Suggestion / target

    public func acceptSuggestion() {
        suggestions?.accept()
    }

    public func dismissSuggestion() {
        suggestions?.dismiss()
    }

    /// Modification rapide du target depuis le popover (clamp 5...300 km).
    public func setGoalTargetKm(_ km: Double) {
        guard store.goal.metric == .distance else { return }
        let clamped = max(5, min(300, km.rounded()))
        store.goal.target = clamped
    }

    // MARK: Coach

    public func refreshCoach() { coach?.forceRefresh() }
    public func dismissCoach() { coach?.dismiss() }
}

public enum PopoverStatusKind: Sendable {
    case needsConnection
    case error
    case syncing
    case waitingForSync
    case noActivities
    case ready
}

public extension Notification.Name {
    static let runbarClosePopover = Notification.Name("com.rodrigue.runbar.close-popover")
    static let runbarStravaConnected = Notification.Name("com.rodrigue.runbar.strava-connected")
}

#if DEBUG
public extension PopoverViewModel {
    static func preview(_ mode: PopoverMode) -> PopoverViewModel {
        let store = ActivityStore()
        let sync = SyncManager(store: store, strava: StravaService.preview)
        let vm = PopoverViewModel(
            store: store, syncManager: sync, snapshots: nil,
            suggestions: nil, coach: nil
        )
        switch mode {
        case .empty:
            store.clear()
        case .normal:
            store.upsert(SeedData.weekInProgress())
        case .victory:
            store.upsert(SeedData.weekComplete())
        }
        vm.lastSync = Date.now.addingTimeInterval(-720) // 12 min
        return vm
    }
}
#endif
