import Foundation

/// Six états de l'avatar coureur — référencés dans le design system v1.
public enum RunnerState: String, CaseIterable, Codable, Sendable {
    case idle
    case jogging
    case sprinting
    case tired
    case victory
    /// Semaine de récupération après une grosse semaine (≥ 140 % de la
    /// cible) : le repos est mérité, l'avatar souffle au lieu de culpabiliser.
    /// Réutilise le cycle idle à cadence réduite — pas d'assets dédiés.
    case recovery

    /// Nombre de frames d'animation par état.
    /// - jogging/sprinting partagent les 8 frames du cycle de course
    /// - idle/tired/victory ont chacun leur propre cycle de 6 frames
    /// - recovery réutilise le cycle idle
    public var frames: Int {
        switch self {
        case .idle:      return 6
        case .jogging:   return 8
        case .sprinting: return 8
        case .tired:     return 6
        case .victory:   return 6
        case .recovery:  return 6
        }
    }

    /// Cadence d'animation (frames par seconde).
    public var fps: Double {
        switch self {
        case .idle:      return 3
        case .jogging:   return 6
        case .sprinting: return 9
        case .tired:     return 4
        case .victory:   return 6
        case .recovery:  return 2
        }
    }

    /// Tous les états utilisent désormais des sprites PNG hand-drawn dédiés.
    /// Le rendu parametric (RunnerFrames + Canvas) reste en fallback pour
    /// les preview / tests sans assets bundle.
    public var hasSpriteAssets: Bool { true }

    public var label: String {
        let key: String.LocalizationValue
        switch self {
        case .idle:      key = "runner.state.idle"
        case .jogging:   key = "runner.state.jogging"
        case .sprinting: key = "runner.state.sprinting"
        case .tired:     key = "runner.state.tired"
        case .victory:   key = "runner.state.victory"
        case .recovery:  key = "runner.state.recovery"
        }
        return String(localized: key, bundle: .runBarResources)
    }
}
