import CoreGraphics
import Foundation

/// Tables de keyframes par état. Chaque entrée est une `RunnerPose` complète.
/// Le `RunnerBitmap` interpole entre keyframes consécutives pour produire des
/// sub-frames (rendu fluide).
///
/// Conventions cycle de course (Williams, *The Animator's Survival Kit*) :
/// Les 8 phases canoniques sont — pour la jambe droite —
/// 1. Contact (pied droit touche)
/// 2. Recoil (compression genou droit)
/// 3. Low-point passing (jambe droite sous le corps)
/// 4. High-point (jambe gauche atteint son apex devant)
/// 5-8. Symétrie pour la jambe gauche
enum RunnerFrames {

    /// Récupère la pose pour un keyframe donné (sans interpolation).
    static func keyframePose(for state: RunnerState, frame: Int) -> RunnerPose {
        let frames = framesFor(state: state)
        let safe = ((frame % frames.count) + frames.count) % frames.count
        return frames[safe]
    }

    /// Récupère la pose interpolée pour un sub-frame (entre 0 et `state.frames * tweenSteps - 1`).
    static func tweenedPose(for state: RunnerState, subframe: Int) -> RunnerPose {
        let frames = framesFor(state: state)
        let totalSubframes = frames.count * RunnerTweenSteps
        let safe = ((subframe % totalSubframes) + totalSubframes) % totalSubframes
        let keyframeIndex = safe / RunnerTweenSteps
        let nextIndex = (keyframeIndex + 1) % frames.count
        let t = CGFloat(safe % RunnerTweenSteps) / CGFloat(RunnerTweenSteps)
        return RunnerPose.lerp(frames[keyframeIndex], frames[nextIndex], t: t)
    }

    static func framesFor(state: RunnerState) -> [RunnerPose] {
        switch state {
        case .idle:      return idleCycle
        case .jogging:   return joggingCycle
        case .sprinting: return sprintingCycle
        case .tired:     return tiredCycle
        case .victory:   return victoryCycle
        case .recovery:  return idleCycle
        }
    }

    // ─── Idle ─────────────────────────────────────────────
    /// 4 frames : respiration douce, oscillation cou/épaules de 1pt.
    private static var idleCycle: [RunnerPose] = (0..<4).map { i in
        var p = RunnerPose.base()
        let bob: CGFloat = [0, -0.8, -1.2, -0.8][i]
        p.headOffsetY = bob
        p.shoulderWidth = 14 + (i == 1 || i == 2 ? 0.3 : 0) // micro inflation poitrine
        // Bras au repos, légèrement écartés du corps.
        p.armLeft  = .init(upperDeg: 173, lowerDeg: 174)
        p.armRight = .init(upperDeg: 187, lowerDeg: 186)
        p.legLeft  = .init(upperDeg: 178, lowerDeg: 178)
        p.legRight = .init(upperDeg: 182, lowerDeg: 182)
        return p
    }

    // ─── Jogging ──────────────────────────────────────────
    /// 8 phases d'un cycle de course modéré. Lean ~7°.
    /// Format : (legR_up, legR_lo, legL_up, legL_lo, armR_up, armR_lo, armL_up, armL_lo, headBob, hipDeltaY)
    private static var joggingCycle: [RunnerPose] = {
        let table: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            // 1. Contact pied droit (devant) — bras gauche devant, droit derrière
            (155, 145, 215, 235, 145, 130, 215, 230, 0.0, 0.5),
            // 2. Recoil — compression
            (170, 165, 200, 230, 155, 145, 205, 220, -0.8, 1.2),
            // 3. Low-point (sous le corps) — bras croisent vers le centre
            (185, 195, 195, 200, 175, 175, 185, 195, -0.4, 0.6),
            // 4. High-point gauche — la jambe gauche atteint son apex devant
            (210, 230, 165, 150, 195, 200, 165, 145, -1.0, 0.0),
            // 5. Contact pied gauche
            (225, 235, 155, 145, 215, 230, 145, 130, 0.0, 0.5),
            // 6. Recoil opposé
            (210, 230, 170, 165, 205, 220, 155, 145, -0.8, 1.2),
            // 7. Low-point opposé
            (195, 200, 185, 195, 185, 195, 175, 175, -0.4, 0.6),
            // 8. High-point droite
            (165, 150, 210, 230, 165, 145, 195, 200, -1.0, 0.0),
        ]
        return table.map { row in
            var p = RunnerPose.base()
            p.torsoLeanDeg = 7
            p.legRight = .init(upperDeg: row.0, lowerDeg: row.1)
            p.legLeft  = .init(upperDeg: row.2, lowerDeg: row.3)
            p.armRight = .init(upperDeg: row.4, lowerDeg: row.5)
            p.armLeft  = .init(upperDeg: row.6, lowerDeg: row.7)
            p.headOffsetY = row.8
            p.hip = CGPoint(x: 48, y: 60 + row.9)
            return p
        }
    }()

    // ─── Sprinting ────────────────────────────────────────
    /// 8 phases, foulée plus ample, lean prononcé. Motion lines actives.
    private static var sprintingCycle: [RunnerPose] = {
        let table: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (135, 120, 230, 255, 130, 105, 225, 245,  0.0, 1.0),
            (155, 145, 215, 250, 140, 115, 215, 230, -1.2, 2.0),
            (180, 195, 200, 200, 165, 165, 195, 200, -0.6, 1.0),
            (220, 250, 145, 125, 205, 220, 145, 120, -1.5, 0.0),
            (240, 260, 130, 110, 230, 250, 125, 105,  0.0, 1.0),
            (215, 250, 155, 145, 215, 230, 140, 115, -1.2, 2.0),
            (200, 200, 180, 195, 195, 200, 165, 165, -0.6, 1.0),
            (145, 125, 220, 250, 145, 120, 205, 220, -1.5, 0.0),
        ]
        return table.map { row in
            var p = RunnerPose.base()
            p.torsoLeanDeg = 18
            p.hip = CGPoint(x: 47, y: 62 + row.9)
            p.headOffsetY = row.8 - 1
            p.legRight = .init(upperDeg: row.0, lowerDeg: row.1)
            p.legLeft  = .init(upperDeg: row.2, lowerDeg: row.3)
            p.armRight = .init(upperDeg: row.4, lowerDeg: row.5)
            p.armLeft  = .init(upperDeg: row.6, lowerDeg: row.7)
            p.motionLines = true
            return p
        }
    }()

    // ─── Tired ────────────────────────────────────────────
    /// 8 phases, cadence courte, épaules basses, tête vers le bas.
    /// Foulée raccourcie : amplitude angulaire ~25° au lieu de 60°.
    private static var tiredCycle: [RunnerPose] = {
        let table: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (170, 162, 192, 200, 168, 160, 192, 200, 0.5),
            (178, 172, 188, 195, 172, 165, 188, 195, 1.0),
            (188, 188, 184, 188, 182, 180, 178, 180, 0.5),
            (200, 210, 168, 160, 192, 205, 168, 160, 0.0),
            (205, 215, 165, 158, 195, 210, 165, 158, 0.5),
            (200, 215, 170, 162, 192, 205, 170, 162, 1.0),
            (188, 192, 184, 184, 178, 180, 182, 180, 0.5),
            (168, 160, 200, 210, 168, 160, 192, 205, 0.0),
        ]
        return table.map { row in
            var p = RunnerPose.base()
            p.torsoLeanDeg = 14    // penché de fatigue
            p.hip = CGPoint(x: 48, y: 62)
            p.headOffsetY = 1.5    // tête vers le bas
            p.shoulderWidth = 13   // épaules un peu rentrées
            p.legRight = .init(upperDeg: row.0, lowerDeg: row.1)
            p.legLeft  = .init(upperDeg: row.2, lowerDeg: row.3)
            p.armRight = .init(upperDeg: row.4, lowerDeg: row.5)
            p.armLeft  = .init(upperDeg: row.6, lowerDeg: row.7)
            p.headOffsetY += row.8 * 0.3
            return p
        }
    }()

    // ─── Victory ──────────────────────────────────────────
    /// 4 frames : bras en V au-dessus de la tête, petit hop.
    private static var victoryCycle: [RunnerPose] = (0..<4).map { i in
        var p = RunnerPose.base()
        let hop: CGFloat = [0, -3, -4.5, -3][i]
        p.hip = CGPoint(x: 48, y: 60 + hop)
        p.headOffsetY = hop * 0.5
        // Bras levés en V ouvert.
        let armSpread: CGFloat = i == 2 ? 38 : 35
        p.armLeft  = .init(upperDeg: 360 - armSpread, lowerDeg: 360 - armSpread - 5)
        p.armRight = .init(upperDeg: armSpread,        lowerDeg: armSpread + 5)
        // Jambes serrées, pieds à plat sauf au sommet du saut.
        let kneeFlex: CGFloat = i == 2 ? 8 : 0
        p.legLeft  = .init(upperDeg: 175, lowerDeg: 178 + kneeFlex)
        p.legRight = .init(upperDeg: 185, lowerDeg: 182 - kneeFlex)
        return p
    }
}
