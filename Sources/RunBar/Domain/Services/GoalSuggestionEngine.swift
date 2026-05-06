import Foundation

/// Calcule chaque semaine si le target hebdo mérite d'être réajusté à partir des
/// 4 dernières semaines ISO complètes. Pure : pas de stockage, pas d'I/O.
///
/// Règles :
/// - Hausse : moyenne 4 sem × 1.10, arrondi au 5 km supérieur, plafonnée à +20% du target courant.
/// - Baisse : si l'utilisateur a complété < 70% du target sur ≥2 semaines sur 4,
///   on propose la moyenne réelle (sans buffer) — ne pas pousser à monter quand on n'atteint pas.
/// - Pas de suggestion si delta < 5 km ou < 10% — éviter le bruit.
/// - Nil si métrique ≠ distance, données insuffisantes, ou avg < 5 km/sem.
public struct GoalSuggestionEngine {
    public static let minBaselineKm: Double = 5
    public static let minDeltaKm: Double = 5
    public static let minDeltaRatio: Double = 0.10
    public static let increaseFactor: Double = 1.10
    public static let increaseCapFactor: Double = 1.20
    public static let underperformThreshold: Double = 0.70
    public static let underperformWeeksTrigger: Int = 2
    public static let lookbackWeeks: Int = 4
    public static let minSuggestion: Double = 10
    public static let maxSuggestion: Double = 150

    public init() {}

    /// Caller-friendly overload that derives weekly km totals from the
    /// rolling-cache `Activity` rows. Kept for unit tests and the legacy
    /// path; in production we now prefer `evaluate(snapshots:)` because
    /// SwiftData only holds 7 days of activities (Strava § 7.1) so a
    /// 4-week lookback against `Activity` only sees one full week.
    public func evaluate(
        activities: [Activity],
        goal: WeeklyGoal,
        now: Date = .now
    ) -> GoalSuggestion? {
        guard goal.metric == .distance else { return nil }
        guard goal.target > 0 else { return nil }
        let cal = Calendar.iso8601Monday
        let thisMonday = now.startOfWeek(weekday: goal.resetWeekday, calendar: cal)
        var weeklyKm: [Double] = []
        for i in 1...Self.lookbackWeeks {
            guard
                let start = cal.date(byAdding: .day, value: -7 * i, to: thisMonday),
                let end = cal.date(byAdding: .day, value: 7, to: start)
            else { continue }
            let km = activities
                .filter { $0.startDate >= start && $0.startDate < end }
                .reduce(0.0) { $0 + $1.distanceKm }
            weeklyKm.append(km)
        }
        return evaluate(weeklyKm: weeklyKm, goal: goal, thisMonday: thisMonday)
    }

    /// Production path: derive weekly totals from the persistent
    /// `WeeklySnapshot` history (which we seed on Strava connect via
    /// `SettingsCoordinator.seedHistoricalSnapshots`). The snapshots
    /// store keeps 8+ weeks of derived aggregates without violating the
    /// 7-day raw-data cache rule.
    public func evaluate(
        snapshots: [WeeklySnapshot],
        goal: WeeklyGoal,
        now: Date = .now
    ) -> GoalSuggestion? {
        guard goal.metric == .distance else { return nil }
        guard goal.target > 0 else { return nil }
        let cal = Calendar.iso8601Monday
        let thisMonday = now.startOfWeek(weekday: goal.resetWeekday, calendar: cal)
        var weeklyKm: [Double] = []
        for i in 1...Self.lookbackWeeks {
            guard
                let start = cal.date(byAdding: .day, value: -7 * i, to: thisMonday),
                let end = cal.date(byAdding: .day, value: 7, to: start)
            else { continue }
            let km = snapshots
                .first(where: {
                    $0.metric == .distance
                    && $0.weekStart >= start
                    && $0.weekStart < end
                })?.achieved ?? 0
            weeklyKm.append(km)
        }
        return evaluate(weeklyKm: weeklyKm, goal: goal, thisMonday: thisMonday)
    }

    private func evaluate(
        weeklyKm: [Double],
        goal: WeeklyGoal,
        thisMonday: Date
    ) -> GoalSuggestion? {
        guard weeklyKm.count == Self.lookbackWeeks else { return nil }
        let totalKm = weeklyKm.reduce(0, +)
        guard totalKm > 0 else { return nil }

        let avgKm = totalKm / Double(Self.lookbackWeeks)
        guard avgKm >= Self.minBaselineKm else { return nil }

        let underperform = weeklyKm.filter { $0 / goal.target < Self.underperformThreshold }.count
        let direction: GoalSuggestion.Direction =
            (underperform >= Self.underperformWeeksTrigger) ? .decrease : .increase

        let raw: Double
        switch direction {
        case .increase:
            let bumped = avgKm * Self.increaseFactor
            let cap = goal.target * Self.increaseCapFactor
            raw = ceil(min(bumped, cap) / 5) * 5
        case .decrease:
            raw = ceil(avgKm / 5) * 5
        }

        let suggested = min(Self.maxSuggestion, max(Self.minSuggestion, raw))

        let delta = abs(suggested - goal.target)
        let ratio = delta / goal.target
        guard delta >= Self.minDeltaKm, ratio >= Self.minDeltaRatio else { return nil }

        switch direction {
        case .increase where suggested <= goal.target: return nil
        case .decrease where suggested >= goal.target: return nil
        default: break
        }

        return GoalSuggestion(
            weekStart: thisMonday,
            currentTarget: goal.target,
            suggestedTarget: suggested,
            baselineAvgKm: avgKm,
            direction: direction
        )
    }
}
