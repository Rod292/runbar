import Foundation

/// Métrique de l'objectif hebdo : km parcourus, nombre de sorties, ou D+ cumulé.
public enum GoalMetric: String, CaseIterable, Codable, Sendable {
    case distance
    case count
    case elevation

    public var label: String {
        switch self {
        case .distance:  return "Distance"
        case .count:     return "Run count"
        case .elevation: return "Elevation"
        }
    }

    public var unit: String {
        switch self {
        case .distance:  return "km"
        case .count:     return "runs"
        case .elevation: return "m up"
        }
    }
}

/// L'objectif hebdo de l'utilisateur.
public struct WeeklyGoal: Codable, Sendable, Equatable {
    public var metric: GoalMetric
    /// Cible en unités de la métrique (km, count, m).
    public var target: Double
    /// 2 = lundi (ISO). 1 = dimanche.
    public var resetWeekday: Int
    public var createdAt: Date
    /// Date d'une course visée — affichée en countdown si <30j.
    public var raceDate: Date?
    public var raceName: String?

    public init(
        metric: GoalMetric = .distance,
        target: Double = 60,
        resetWeekday: Int = 2,
        createdAt: Date = .now,
        raceDate: Date? = nil,
        raceName: String? = nil
    ) {
        self.metric = metric
        self.target = target
        self.resetWeekday = resetWeekday
        self.createdAt = createdAt
        self.raceDate = raceDate
        self.raceName = raceName
    }

    public static let `default` = WeeklyGoal()

    /// Nombre de jours jusqu'à la course (0 = aujourd'hui, négatif = passée).
    public func daysUntilRace(now: Date = .now) -> Int? {
        guard let d = raceDate else { return nil }
        let cal = Calendar.iso8601Monday
        let today = cal.startOfDay(for: now)
        let race = cal.startOfDay(for: d)
        return cal.dateComponents([.day], from: today, to: race).day
    }
}
