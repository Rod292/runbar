import Foundation

/// Suggestion de target hebdo recalculée à partir des semaines récentes.
public struct GoalSuggestion: Codable, Equatable, Sendable {
    public enum Direction: String, Codable, Sendable {
        case increase
        case decrease
    }

    /// Lundi ISO de la semaine où la suggestion a été émise.
    public let weekStart: Date
    /// Target courant au moment du calcul (km).
    public let currentTarget: Double
    /// Target proposé (km).
    public let suggestedTarget: Double
    /// Moyenne km des 4 dernières semaines complètes.
    public let baselineAvgKm: Double
    public let direction: Direction

    public init(
        weekStart: Date,
        currentTarget: Double,
        suggestedTarget: Double,
        baselineAvgKm: Double,
        direction: Direction
    ) {
        self.weekStart = weekStart
        self.currentTarget = currentTarget
        self.suggestedTarget = suggestedTarget
        self.baselineAvgKm = baselineAvgKm
        self.direction = direction
    }
}
