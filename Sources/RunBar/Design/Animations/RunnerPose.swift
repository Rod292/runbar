import CoreGraphics
import Foundation

/// Pose paramétrique d'un coureur — angles d'articulations dans le viewBox 96×96.
/// Origine en haut-gauche. Tout est en points relatifs à 96.
///
/// Convention angles : 0° = vers le haut, 90° = vers la droite (sens horaire).
/// Une pose décrit la position des joints + la morphologie locale (largeur des
/// segments, taille des extrémités). Deux poses peuvent être linéairement
/// interpolées pour produire une foulée fluide.
struct RunnerPose: Equatable {
    // ─── Tronc ───────────────────────────────────────────
    /// Position de la hanche (point d'ancrage du buste et des jambes).
    var hip: CGPoint
    var torsoLength: CGFloat
    /// Inclinaison du tronc en degrés (positif = penché vers l'avant).
    var torsoLeanDeg: CGFloat
    /// Largeur du tronc à la hanche.
    var hipWidth: CGFloat
    /// Largeur du tronc à l'épaule (typiquement plus large pour un V dorsal).
    var shoulderWidth: CGFloat

    // ─── Tête + cou ──────────────────────────────────────
    var headRadius: CGFloat
    /// Décalage vertical de la tête (oscillation respiration / bob).
    var headOffsetY: CGFloat
    /// Longueur du cou entre épaule et bas du crâne.
    var neckLength: CGFloat
    var neckWidth: CGFloat

    // ─── Bras ────────────────────────────────────────────
    var upperArmLength: CGFloat
    var forearmLength: CGFloat
    /// Largeur du segment supérieur (épaule) et inférieur (poignet).
    var upperArmWidth: CGFloat
    var wristWidth: CGFloat
    /// Rayon de la main au bout du bras.
    var handRadius: CGFloat
    var armLeft:  LimbAngles
    var armRight: LimbAngles

    // ─── Jambes ──────────────────────────────────────────
    var thighLength: CGFloat
    var calfLength: CGFloat
    /// Largeur des segments — pour le tapering anatomique.
    var thighWidth: CGFloat
    var ankleWidth: CGFloat
    /// Longueur du pied (orienté ~perpendiculaire à la jambe basse, vers l'avant).
    var footLength: CGFloat
    var footWidth: CGFloat
    var legLeft:  LimbAngles
    var legRight: LimbAngles

    /// Active les motion lines (sprint).
    var motionLines: Bool

    struct LimbAngles: Equatable {
        /// Angle absolu du segment supérieur (épaule→coude ou hanche→genou).
        var upperDeg: CGFloat
        /// Angle absolu du segment inférieur (coude→main ou genou→pied).
        var lowerDeg: CGFloat
    }
}

extension RunnerPose {
    /// Conversion polaire vers cartésien (origine = pivot).
    static func endpoint(from pivot: CGPoint, length: CGFloat, angleDeg: CGFloat) -> CGPoint {
        // 0° = haut → on fait pivoter de -90° pour matcher la convention math.
        let rad = (angleDeg - 90) * .pi / 180
        return CGPoint(x: pivot.x + cos(rad) * length, y: pivot.y + sin(rad) * length)
    }

    /// Pose canonique au repos. Coordonnées dans un canvas 96×96.
    /// Proportions ~7 têtes, runner adulte de profil.
    static func base() -> RunnerPose {
        RunnerPose(
            hip: CGPoint(x: 48, y: 60),
            torsoLength: 22,
            torsoLeanDeg: 0,
            hipWidth: 11,
            shoulderWidth: 14,

            headRadius: 7,
            headOffsetY: 0,
            neckLength: 3,
            neckWidth: 5.2,

            upperArmLength: 14,
            forearmLength: 12,
            upperArmWidth: 5.2,
            wristWidth: 3.6,
            handRadius: 2.4,
            armLeft:  .init(upperDeg: 175, lowerDeg: 175),
            armRight: .init(upperDeg: 185, lowerDeg: 185),

            thighLength: 17,
            calfLength: 16,
            thighWidth: 7.2,
            ankleWidth: 4.4,
            footLength: 7,
            footWidth: 3.4,
            legLeft:  .init(upperDeg: 178, lowerDeg: 178),
            legRight: .init(upperDeg: 182, lowerDeg: 182),

            motionLines: false
        )
    }
}

// MARK: - Interpolation

extension RunnerPose {
    /// Interpolation linéaire entre deux poses. `t ∈ [0,1]`.
    /// Les angles passent par le chemin le plus court (shortest-path).
    static func lerp(_ a: RunnerPose, _ b: RunnerPose, t: CGFloat) -> RunnerPose {
        let tt = max(0, min(1, t))
        return RunnerPose(
            hip: lerpPoint(a.hip, b.hip, tt),
            torsoLength:    lerpScalar(a.torsoLength,    b.torsoLength,    tt),
            torsoLeanDeg:   lerpAngle(a.torsoLeanDeg,    b.torsoLeanDeg,   tt),
            hipWidth:       lerpScalar(a.hipWidth,       b.hipWidth,       tt),
            shoulderWidth:  lerpScalar(a.shoulderWidth,  b.shoulderWidth,  tt),

            headRadius:     lerpScalar(a.headRadius,     b.headRadius,     tt),
            headOffsetY:    lerpScalar(a.headOffsetY,    b.headOffsetY,    tt),
            neckLength:     lerpScalar(a.neckLength,     b.neckLength,     tt),
            neckWidth:      lerpScalar(a.neckWidth,      b.neckWidth,      tt),

            upperArmLength: lerpScalar(a.upperArmLength, b.upperArmLength, tt),
            forearmLength:  lerpScalar(a.forearmLength,  b.forearmLength,  tt),
            upperArmWidth:  lerpScalar(a.upperArmWidth,  b.upperArmWidth,  tt),
            wristWidth:     lerpScalar(a.wristWidth,     b.wristWidth,     tt),
            handRadius:     lerpScalar(a.handRadius,     b.handRadius,     tt),
            armLeft:        LimbAngles.lerp(a.armLeft,   b.armLeft,        t: tt),
            armRight:       LimbAngles.lerp(a.armRight,  b.armRight,       t: tt),

            thighLength:    lerpScalar(a.thighLength,    b.thighLength,    tt),
            calfLength:     lerpScalar(a.calfLength,     b.calfLength,     tt),
            thighWidth:     lerpScalar(a.thighWidth,     b.thighWidth,     tt),
            ankleWidth:     lerpScalar(a.ankleWidth,     b.ankleWidth,     tt),
            footLength:     lerpScalar(a.footLength,     b.footLength,     tt),
            footWidth:      lerpScalar(a.footWidth,      b.footWidth,      tt),
            legLeft:        LimbAngles.lerp(a.legLeft,   b.legLeft,        t: tt),
            legRight:       LimbAngles.lerp(a.legRight,  b.legRight,       t: tt),

            motionLines:    tt < 0.5 ? a.motionLines : b.motionLines
        )
    }

    private static func lerpScalar(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private static func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: lerpScalar(a.x, b.x, t), y: lerpScalar(a.y, b.y, t))
    }

    /// Interpolation d'angle shortest-path : 350° → 10° passe par 0°, pas par 180°.
    /// Exposée pour tests et utilisation par `LimbAngles.lerp`.
    static func lerpAngle(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        // Normalise dans [-180, 180] le delta puis applique linéairement.
        var delta = (b - a).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let raw = a + delta * t
        // Renormalise en [0, 360) pour la sortie.
        let mod = raw.truncatingRemainder(dividingBy: 360)
        return mod < 0 ? mod + 360 : mod
    }
}

extension RunnerPose.LimbAngles {
    static func lerp(_ a: RunnerPose.LimbAngles, _ b: RunnerPose.LimbAngles, t: CGFloat) -> RunnerPose.LimbAngles {
        RunnerPose.LimbAngles(
            upperDeg: RunnerPose.lerpAngle(a.upperDeg, b.upperDeg, t),
            lowerDeg: RunnerPose.lerpAngle(a.lowerDeg, b.lowerDeg, t)
        )
    }
}
