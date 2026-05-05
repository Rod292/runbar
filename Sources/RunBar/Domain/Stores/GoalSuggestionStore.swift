import Combine
import Foundation

/// État persistant de la suggestion hebdo : suggestion en attente, dernières
/// semaines acceptée / dismissée. Une suggestion ne peut s'afficher qu'une
/// fois par semaine ISO ; après accept ou dismiss, on attend le lundi suivant.
@MainActor
public final class GoalSuggestionStore: ObservableObject {
    @Published public private(set) var pending: GoalSuggestion?

    private let store: ActivityStore
    private let engine: GoalSuggestionEngine
    private let defaults: UserDefaults

    private let pendingKey = "runbar.goalSuggestion.pending.v1"
    private let dismissedKey = "runbar.goalSuggestion.lastDismissedWeek.v1"
    private let acceptedKey = "runbar.goalSuggestion.lastAcceptedWeek.v1"

    public init(
        store: ActivityStore,
        engine: GoalSuggestionEngine = GoalSuggestionEngine(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.engine = engine
        self.defaults = defaults
        self.pending = loadPending()
    }

    /// Re-calcule la suggestion à partir des activités courantes du store.
    /// Appelée après chaque sync et au démarrage.
    public func refresh(now: Date = .now) {
        let cal = Calendar.iso8601Monday
        let thisMonday = now.startOfWeek(weekday: store.goal.resetWeekday, calendar: cal)

        // Suggestion périmée d'une semaine précédente : la jeter.
        if let p = pending, p.weekStart < thisMonday {
            setPending(nil)
        }

        if let lastDismissed = loadWeek(dismissedKey), lastDismissed >= thisMonday { return }
        if let lastAccepted = loadWeek(acceptedKey), lastAccepted >= thisMonday { return }

        let suggestion = engine.evaluate(
            activities: store.activities,
            goal: store.goal,
            now: now
        )
        setPending(suggestion)
    }

    /// Applique la suggestion au goal et marque la semaine comme acceptée.
    public func accept(now: Date = .now) {
        guard let p = pending else { return }
        store.goal.target = p.suggestedTarget
        saveWeek(acceptedKey, value: weekStart(now))
        setPending(nil)
    }

    /// Ferme la suggestion sans l'appliquer ; ne reviendra pas avant lundi prochain.
    public func dismiss(now: Date = .now) {
        saveWeek(dismissedKey, value: weekStart(now))
        setPending(nil)
    }

    private func setPending(_ value: GoalSuggestion?) {
        pending = value
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: pendingKey)
        } else {
            defaults.removeObject(forKey: pendingKey)
        }
    }

    private func loadPending() -> GoalSuggestion? {
        guard let data = defaults.data(forKey: pendingKey) else { return nil }
        return try? JSONDecoder().decode(GoalSuggestion.self, from: data)
    }

    private func loadWeek(_ key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    private func saveWeek(_ key: String, value: Date) {
        defaults.set(value, forKey: key)
    }

    private func weekStart(_ now: Date) -> Date {
        now.startOfWeek(weekday: store.goal.resetWeekday, calendar: .iso8601Monday)
    }
}
