import CoreGraphics
import Foundation

/// Tables de poses par état — chaque entrée définit un frame dans le cycle d'animation.
/// On reste sur des valeurs entières/simples : c'est plus lisible et plus facile à ajuster.
enum RunnerFrames {
    static func pose(for state: RunnerState, frame: Int) -> RunnerPose {
        let frames = framesFor(state: state)
        let safe = ((frame % frames.count) + frames.count) % frames.count
        return frames[safe]
    }

    static func framesFor(state: RunnerState) -> [RunnerPose] {
        switch state {
        case .idle:      return idleCycle
        case .jogging:   return joggingCycle
        case .sprinting: return sprintingCycle
        case .tired:     return tiredCycle
        case .victory:   return victoryCycle
        }
    }

    // ─── Idle ──────────────────────────────────────────────
    /// Debout, légère respiration : la tête monte/descend de 1pt sur 4 frames.
    private static var idleCycle: [RunnerPose] = (0..<4).map { i in
        var p = RunnerPose.base()
        let bob: CGFloat = [0, -0.6, -1.0, -0.6][i]
        p.headOffsetY = bob
        // Bras très légèrement écartés en repos.
        p.armLeft  = .init(upperDeg: 172, lowerDeg: 172)
        p.armRight = .init(upperDeg: 188, lowerDeg: 188)
        p.legLeft  = .init(upperDeg: 178, lowerDeg: 178)
        p.legRight = .init(upperDeg: 182, lowerDeg: 182)
        return p
    }

    // ─── Jogging ───────────────────────────────────────────
    /// Cycle de course : 6 frames, ample mais contrôlé. Lean ~6°.
    private static var joggingCycle: [RunnerPose] = {
        // (legL.up, legL.lo, legR.up, legR.lo, armL.up, armL.lo, armR.up, armR.lo, headBob)
        let table: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (200, 220, 160, 145, 150, 130, 220, 240, -1.0),
            (215, 245, 150, 135, 140, 120, 230, 250, -0.4),
            (225, 215, 175, 175, 160, 150, 210, 220, 0.0),
            (160, 145, 200, 220, 220, 240, 150, 130, -1.0),
            (150, 135, 215, 245, 230, 250, 140, 120, -0.4),
            (175, 175, 225, 215, 210, 220, 160, 150, 0.0),
        ]
        return table.map { row in
            var p = RunnerPose.base()
            p.torsoLeanDeg = 6
            p.legLeft  = .init(upperDeg: row.0, lowerDeg: row.1)
            p.legRight = .init(upperDeg: row.2, lowerDeg: row.3)
            p.armLeft  = .init(upperDeg: row.4, lowerDeg: row.5)
            p.armRight = .init(upperDeg: row.6, lowerDeg: row.7)
            p.headOffsetY = row.8
            return p
        }
    }()

    // ─── Sprinting ─────────────────────────────────────────
    /// Plus penché, foulée plus ample, motion lines.
    private static var sprintingCycle: [RunnerPose] = {
        let table: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (210, 240, 140, 120, 130, 105, 240, 260),
            (230, 270, 130, 110, 120,  95, 250, 275),
            (240, 235, 170, 165, 145, 130, 220, 230),
            (140, 120, 210, 240, 240, 260, 130, 105),
            (130, 110, 230, 270, 250, 275, 120,  95),
            (170, 165, 240, 235, 220, 230, 145, 130),
        ]
        return table.map { row in
            var p = RunnerPose.base()
            p.torsoLeanDeg = 18
            p.hip = CGPoint(x: 31, y: 41) // un peu plus avancé / baissé
            p.headOffsetY = -2
            p.legLeft  = .init(upperDeg: row.0, lowerDeg: row.1)
            p.legRight = .init(upperDeg: row.2, lowerDeg: row.3)
            p.armLeft  = .init(upperDeg: row.4, lowerDeg: row.5)
            p.armRight = .init(upperDeg: row.6, lowerDeg: row.7)
            p.motionLines = true
            return p
        }
    }()

    // ─── Tired ─────────────────────────────────────────────
    /// Foulée raccourcie, épaules basses (lean négatif), tête basse.
    private static var tiredCycle: [RunnerPose] = {
        let table: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (192, 208, 168, 160, 165, 155, 195, 205),
            (200, 218, 165, 158, 160, 150, 200, 215),
            (208, 200, 178, 178, 168, 160, 192, 200),
            (168, 160, 192, 208, 195, 205, 165, 155),
            (165, 158, 200, 218, 200, 215, 160, 150),
            (178, 178, 208, 200, 192, 200, 168, 160),
        ]
        return table.map { row in
            var p = RunnerPose.base()
            p.torsoLeanDeg = 12   // penché de fatigue
            p.hip = CGPoint(x: 32, y: 42)
            p.headOffsetY = 1.5  // tête vers le bas
            p.legLeft  = .init(upperDeg: row.0, lowerDeg: row.1)
            p.legRight = .init(upperDeg: row.2, lowerDeg: row.3)
            p.armLeft  = .init(upperDeg: row.4, lowerDeg: row.5)
            p.armRight = .init(upperDeg: row.6, lowerDeg: row.7)
            return p
        }
    }()

    // ─── Victory ───────────────────────────────────────────
    /// Bras en V au-dessus de la tête, petit hop.
    private static var victoryCycle: [RunnerPose] = (0..<4).map { i in
        var p = RunnerPose.base()
        let hop: CGFloat = [0, -2, -3, -2][i]
        p.hip = CGPoint(x: 32, y: 40 + hop)
        p.headOffsetY = hop * 0.6
        // Bras levés ~330° (gauche) et ~30° (droite) — V ouvert.
        p.armLeft  = .init(upperDeg: 325, lowerDeg: 320)
        p.armRight = .init(upperDeg:  35, lowerDeg:  40)
        // Jambes serrées, légèrement fléchies.
        p.legLeft  = .init(upperDeg: 175, lowerDeg: 178)
        p.legRight = .init(upperDeg: 185, lowerDeg: 182)
        return p
    }
}
