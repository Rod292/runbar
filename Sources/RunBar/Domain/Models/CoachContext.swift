import Foundation

/// Faits transmis au LLM. Volontairement minimal : agrégats hebdo, pas de noms
/// de séances ni d'horodatages précis. Sérialisé en JSON dans le prompt.
public struct CoachContext: Codable, Equatable, Sendable {
    public let weekKm: Double
    public let weekRuns: Int
    public let weekElevationM: Double
    public let targetKm: Double
    public let progressPct: Int
    public let daysLeftInWeek: Int
    public let last4WeeksKm: [Double]
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
        weekKm: Double,
        weekRuns: Int,
        weekElevationM: Double,
        targetKm: Double,
        progressPct: Int,
        daysLeftInWeek: Int,
        last4WeeksKm: [Double],
        streakWeeks: Int,
        race: RaceContext?
    ) {
        self.weekKm = weekKm
        self.weekRuns = weekRuns
        self.weekElevationM = weekElevationM
        self.targetKm = targetKm
        self.progressPct = progressPct
        self.daysLeftInWeek = daysLeftInWeek
        self.last4WeeksKm = last4WeeksKm
        self.streakWeeks = streakWeeks
        self.race = race
    }
}
