import Foundation

/// Snapshot d'une semaine terminée — utilisé pour calculer les streaks
/// et l'historique. Persisté dans `UserDefaults` (JSON) en attendant SwiftData.
public struct WeeklySnapshot: Codable, Equatable, Sendable {
    /// Lundi 00:00 de la semaine, dans la TZ locale.
    public let weekStart: Date
    public let metric: GoalMetric
    public let target: Double
    public let achieved: Double
    public var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, achieved / target)
    }
    public var completed: Bool { progress >= 1.0 }

    public init(weekStart: Date, metric: GoalMetric, target: Double, achieved: Double) {
        self.weekStart = weekStart
        self.metric = metric
        self.target = target
        self.achieved = achieved
    }
}

/// Calcul de streaks à partir d'un historique chronologique.
public enum StreakCalculator {
    /// Streak courant : nombre de semaines consécutives à 100%, terminant
    /// soit à la semaine en cours (si elle est complétée), soit à la semaine
    /// dernière sinon.
    public static func current(snapshots: [WeeklySnapshot], now: Date = .now) -> Int {
        let sorted = snapshots.sorted(by: { $0.weekStart > $1.weekStart })
        let cal = Calendar.iso8601Monday
        let thisMonday = now.startOfWeek()
        var streak = 0
        var expected = thisMonday
        // Si la semaine en cours n'est pas encore complétée on remonte d'une semaine.
        if let head = sorted.first, head.weekStart == thisMonday, !head.completed {
            expected = cal.date(byAdding: .day, value: -7, to: expected) ?? expected
        }
        for snap in sorted {
            if snap.weekStart == expected && snap.completed {
                streak += 1
                expected = cal.date(byAdding: .day, value: -7, to: expected) ?? expected
            } else if snap.weekStart < expected {
                break
            }
        }
        return streak
    }
}
