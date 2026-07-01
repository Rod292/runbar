import Foundation

/// Faits transmis au LLM. Volontairement minimal : agrégats hebdo, pas de noms
/// de séances ni d'horodatages précis. Sérialisé en JSON dans le prompt.
/// Les distances sont exprimées dans l'unité préférée de l'utilisateur
/// (`unit` : "km" ou "mi") pour que le coach parle la même langue que l'UI.
public struct CoachContext: Codable, Equatable, Sendable {
    /// "km" ou "mi" — l'unité de toutes les distances du contexte.
    public let unit: String
    public let weekDistance: Double
    public let weekRuns: Int
    public let weekElevationM: Double
    public let targetDistance: Double
    public let progressPct: Int
    public let daysLeftInWeek: Int
    public let last4WeeksDistance: [Double]
    public let streakWeeks: Int
    public let race: RaceContext?

    public struct RaceContext: Codable, Equatable, Sendable {
        public let name: String
        public let daysUntil: Int

        public init(name: String, daysUntil: Int) {
            self.name = name
            self.daysUntil = daysUntil
        }
    }

    public init(
        unit: String,
        weekDistance: Double,
        weekRuns: Int,
        weekElevationM: Double,
        targetDistance: Double,
        progressPct: Int,
        daysLeftInWeek: Int,
        last4WeeksDistance: [Double],
        streakWeeks: Int,
        race: RaceContext?
    ) {
        self.unit = unit
        self.weekDistance = weekDistance
        self.weekRuns = weekRuns
        self.weekElevationM = weekElevationM
        self.targetDistance = targetDistance
        self.progressPct = progressPct
        self.daysLeftInWeek = daysLeftInWeek
        self.last4WeeksDistance = last4WeeksDistance
        self.streakWeeks = streakWeeks
        self.race = race
    }
}
