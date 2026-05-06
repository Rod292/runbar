import Combine
import Foundation

/// Persiste l'historique hebdo en `UserDefaults` (JSON). Sera migré vers
/// SwiftData en C1 — l'API publique reste stable.
@MainActor
public final class SnapshotStore: ObservableObject {
    @Published public private(set) var snapshots: [WeeklySnapshot] = []

    private let key = "runbar.weeklySnapshots.v1"

    public init() {
        load()
    }

    /// Met à jour ou crée le snapshot de la semaine donnée.
    public func record(weekStart: Date, metric: GoalMetric, target: Double, achieved: Double) {
        let snap = WeeklySnapshot(weekStart: weekStart, metric: metric,
                                   target: target, achieved: achieved)
        if let idx = snapshots.firstIndex(where: { Calendar.iso8601Monday.isDate($0.weekStart, inSameDayAs: weekStart) }) {
            snapshots[idx] = snap
        } else {
            snapshots.append(snap)
        }
        snapshots.sort(by: { $0.weekStart > $1.weekStart })
        save()
    }

    public var currentStreak: Int {
        StreakCalculator.current(snapshots: snapshots)
    }

    public func recent(limit: Int = 8) -> [WeeklySnapshot] {
        Array(snapshots.sorted(by: { $0.weekStart > $1.weekStart }).prefix(limit))
    }

    /// Wipes the entire weekly history. Called on Strava disconnect: even
    /// though weekly snapshots are derived aggregates, they are still
    /// "Personal Data pertaining to that user" under § 5.4 of the Strava API
    /// Agreement and must be deleted on revocation. Also clears the visual
    /// ghosting where the previous account's sparkline lingered after the
    /// new account was connected and returned no runs.
    public func clear() {
        snapshots = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([WeeklySnapshot].self, from: data) {
            snapshots = decoded.sorted(by: { $0.weekStart > $1.weekStart })
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
