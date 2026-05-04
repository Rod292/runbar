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

    public var settingsCoordinator: SettingsCoordinator?

    private let store: ActivityStore
    private let calculator = GoalCalculator()
    private let syncManager: SyncManager
    private let snapshots: SnapshotStore?
    private var cancellables = Set<AnyCancellable>()

    public init(store: ActivityStore, syncManager: SyncManager, snapshots: SnapshotStore? = nil) {
        self.store = store
        self.syncManager = syncManager
        self.snapshots = snapshots
        bind()
    }

    public var currentStreak: Int {
        snapshots?.currentStreak ?? 0
    }

    /// Record progression de la semaine en cours dans le store de snapshots.
    /// Appelé après chaque sync pour que le streak soit à jour.
    public func recordCurrentWeek() {
        guard let snapshots else { return }
        let monday = Date.now.startOfWeek()
        let previousValue = snapshots.snapshots.first(where: {
            $0.weekStart == monday
        })?.achieved ?? 0
        let value = currentValue
        snapshots.record(weekStart: monday, metric: goal.metric,
                          target: goal.target, achieved: value)

        // Victory : on franchit la ligne pour la première fois cette semaine.
        let target = goal.target
        if previousValue < target && value >= target {
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
                self.recordCurrentWeek()
            }
            .store(in: &cancellables)

        store.$goal
            .receive(on: DispatchQueue.main)
            .assign(to: \.goal, on: self)
            .store(in: &cancellables)

        syncManager.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)

        syncManager.$lastSync
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastSync, on: self)
            .store(in: &cancellables)
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
        guard let last = lastSync else {
            return String(localized: "popover.last_sync_now", bundle: .module)
        }
        let secs = Date.now.timeIntervalSince(last)
        if secs < 60 {
            return String(localized: "popover.last_sync_now", bundle: .module)
        }
        let minutes = Int(secs / 60)
        if minutes < 60 {
            let template = String(localized: "popover.last_sync_min", bundle: .module)
            return String(format: template, minutes)
        }
        let hours = minutes / 60
        let template = String(localized: "popover.last_sync_hour", bundle: .module)
        return String(format: template, hours)
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
}

public extension Notification.Name {
    static let runbarClosePopover = Notification.Name("com.rodrigue.runbar.close-popover")
}

#if DEBUG
public extension PopoverViewModel {
    static func preview(_ mode: PopoverMode) -> PopoverViewModel {
        let store = ActivityStore()
        let sync = SyncManager(store: store, strava: StravaService.preview)
        let vm = PopoverViewModel(store: store, syncManager: sync, snapshots: nil)
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
