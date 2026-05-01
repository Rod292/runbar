import Foundation

/// Calcule la progression de la semaine et l'état du runner à afficher.
public struct GoalCalculator {
    public init() {}

    /// Somme des métriques pour les activités de la semaine en cours.
    public func currentValue(activities: [Activity], goal: WeeklyGoal) -> Double {
        switch goal.metric {
        case .distance:
            return activities.reduce(0) { $0 + $1.distanceKm }
        case .count:
            return Double(activities.count)
        case .elevation:
            return activities.reduce(0) { $0 + $1.elevationGain }
        }
    }

    /// Ratio progression / cible, capé à 1.0.
    public func progress(activities: [Activity], goal: WeeklyGoal) -> Double {
        guard goal.target > 0 else { return 0 }
        let value = currentValue(activities: activities, goal: goal)
        return min(1.0, value / goal.target)
    }

    /// État du runner dérivé de la progression et de la position dans la semaine.
    /// - Parameters:
    ///   - progress: 0...1
    ///   - dayOfWeek: 1=lundi ... 7=dimanche
    ///   - lastSyncRecency: secondes depuis la dernière activité synchronisée. nil si aucune.
    public func runnerState(
        progress: Double,
        dayOfWeek: Int,
        lastSyncRecency: TimeInterval? = nil
    ) -> RunnerState {
        if progress >= 1.0 { return .victory }
        if let r = lastSyncRecency, r < 5 * 60 { return .sprinting }
        // Jeudi (4) ou plus avancé, si on a moins de 40% — on est à la traîne.
        if dayOfWeek >= 4 && progress < 0.4 { return .tired }
        if progress <= 0.001 { return .idle }
        return .jogging
    }

    /// Filtre une liste d'activités sur la semaine en cours selon le `resetWeekday` du goal.
    public func activitiesThisWeek(_ all: [Activity], goal: WeeklyGoal, now: Date = .now) -> [Activity] {
        let cal = Calendar.iso8601Monday
        let start = now.startOfWeek(weekday: goal.resetWeekday, calendar: cal)
        let end   = now.endOfWeek(weekday: goal.resetWeekday, calendar: cal)
        return all
            .filter { $0.startDate >= start && $0.startDate <= end }
            .sorted { $0.startDate < $1.startDate }
    }
}
