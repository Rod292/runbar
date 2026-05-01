import Foundation

/// Cinq états de l'avatar coureur — référencés dans le design system v1.
public enum RunnerState: String, CaseIterable, Codable, Sendable {
    case idle
    case jogging
    case sprinting
    case tired
    case victory

    /// Nombre de frames d'animation (cf. design canvas).
    public var frames: Int {
        switch self {
        case .idle:      return 4
        case .jogging:   return 6
        case .sprinting: return 6
        case .tired:     return 6
        case .victory:   return 4
        }
    }

    /// Cadence d'animation (frames par seconde).
    public var fps: Double {
        switch self {
        case .idle:      return 4
        case .jogging:   return 8
        case .sprinting: return 12
        case .tired:     return 5
        case .victory:   return 6
        }
    }

    public var label: String {
        switch self {
        case .idle:      return "Au repos"
        case .jogging:   return "Dans les clous"
        case .sprinting: return "Sprint"
        case .tired:     return "En retard"
        case .victory:   return "Objectif atteint"
        }
    }
}
