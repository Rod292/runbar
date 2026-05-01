import CoreGraphics
import Foundation

/// Pose paramétrique d'un coureur — angles d'articulations dans le viewBox 64×64.
/// Origine en haut-gauche. Tout est en points relatifs à 64.
///
/// Convention angles : 0° = vers le haut, 90° = vers la droite (sens horaire).
struct RunnerPose {
    // Position du buste — pivote autour de la hanche.
    var hip: CGPoint
    var torsoLength: CGFloat
    /// Inclinaison du tronc (positif = penché vers l'avant).
    var torsoLeanDeg: CGFloat

    // Tête
    var headRadius: CGFloat
    /// Décalage vertical de la tête (oscillation respiration / bob).
    var headOffsetY: CGFloat

    // Bras (longueurs en points). Angles épaule + coude pour chaque bras.
    var upperArmLength: CGFloat
    var forearmLength: CGFloat
    var armLeft:  LimbAngles
    var armRight: LimbAngles

    // Jambes
    var thighLength: CGFloat
    var calfLength: CGFloat
    var legLeft:  LimbAngles
    var legRight: LimbAngles

    // Style
    var limbWidth: CGFloat
    /// Active les lignes de mouvement (sprint).
    var motionLines: Bool

    struct LimbAngles {
        /// Angle absolu du segment supérieur (épaule→coude ou hanche→genou).
        var upperDeg: CGFloat
        /// Angle absolu du segment inférieur (coude→main ou genou→pied).
        var lowerDeg: CGFloat
    }
}

extension RunnerPose {
    /// Conversion polaire vers cartésien (origine = pivot).
    static func endpoint(from pivot: CGPoint, length: CGFloat, angleDeg: CGFloat) -> CGPoint {
        let rad = (angleDeg - 90) * .pi / 180  // 0° = haut → ajustement
        return CGPoint(x: pivot.x + cos(rad) * length, y: pivot.y + sin(rad) * length)
    }

    /// Pose canonique : hanche au milieu-bas, tronc droit, jambes rejointes, bras le long du corps.
    static func base() -> RunnerPose {
        RunnerPose(
            hip: CGPoint(x: 32, y: 40),
            torsoLength: 16,
            torsoLeanDeg: 0,
            headRadius: 6,
            headOffsetY: 0,
            upperArmLength: 9,
            forearmLength: 8,
            armLeft:  .init(upperDeg: 175, lowerDeg: 175),
            armRight: .init(upperDeg: 185, lowerDeg: 185),
            thighLength: 11,
            calfLength: 10,
            legLeft:  .init(upperDeg: 178, lowerDeg: 178),
            legRight: .init(upperDeg: 182, lowerDeg: 182),
            limbWidth: 4.2,
            motionLines: false
        )
    }
}
