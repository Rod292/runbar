import Foundation

/// Cinq états de l'avatar coureur — référencés dans le design system v1.
public enum RunnerState: String, CaseIterable, Codable, Sendable {
    case idle
    case jogging
    case sprinting
    case tired
    case victory

    /// Nombre de frames d'animation (cf. design canvas et tables `RunnerFrames`).
    public var frames: Int {
        switch self {
        case .idle:      return 4
        case .jogging:   return 8
        case .sprinting: return 8
        case .tired:     return 8
        case .victory:   return 4
        }
    }

    /// Cadence d'animation (frames par seconde).
    public var fps: Double {
        switch self {
        case .idle:      return 4
        case .jogging:   return 6
        case .sprinting: return 9
        case .tired:     return 4
        case .victory:   return 6
        }
    }

    /// Vrai si l'état utilise les sprites PNG hand-drawn (cycle de course
    /// partagé). Idle et victory restent en rendu parametric — ce ne sont
    /// pas des poses de course.
    public var hasSpriteAssets: Bool {
        switch self {
        case .jogging, .sprinting, .tired: return true
        case .idle, .victory: return false
        }
    }

    public var label: String {
        let key: String.LocalizationValue
        switch self {
        case .idle:      key = "runner.state.idle"
        case .jogging:   key = "runner.state.jogging"
        case .sprinting: key = "runner.state.sprinting"
        case .tired:     key = "runner.state.tired"
        case .victory:   key = "runner.state.victory"
        }
        return String(localized: key, bundle: .module)
    }
}
