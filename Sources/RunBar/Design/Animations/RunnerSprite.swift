import AppKit
import Foundation

/// Charge les frames PNG hand-drawn (template macOS) depuis le bundle.
/// Quatre cycles distincts :
///   - jogging : `frame-1.png` ... `frame-8.png` (réutilisé par sprinting)
///   - idle    : `idle-1.png` ... `idle-6.png`
///   - tired   : `tired-1.png` ... `tired-6.png`
///   - victory : `victory-1.png` ... `victory-6.png`
@MainActor
public enum RunnerSprite {

    /// Vrai si on a réussi à charger les frames jogging (le minimum requis).
    public static var isAvailable: Bool { !joggingFrames.isEmpty }

    /// Inclinaison appliquée à jogging. Sprinting reçoit un lean plus marqué
    /// (`sprintLeanDegrees`) pour lire "court plus fort" malgré le partage
    /// du même sprite sheet. Idle/tired/victory restent à 0°.
    public static let runningLeanDegrees: CGFloat = -6
    public static let sprintLeanDegrees: CGFloat = -11

    // MARK: - Cycles

    private static let joggingFrames: [NSImage] = (1...8).compactMap { i in
        loadMultiResolution(baseName: "frame-\(i)")
    }
    private static let idleFrames: [NSImage] = (1...6).compactMap { i in
        loadMultiResolution(baseName: "idle-\(i)")
    }
    private static let tiredFrames: [NSImage] = (1...6).compactMap { i in
        loadMultiResolution(baseName: "tired-\(i)")
    }
    private static let victoryFrames: [NSImage] = (1...6).compactMap { i in
        loadMultiResolution(baseName: "victory-\(i)")
    }

    private static func cycle(for state: RunnerState) -> [NSImage] {
        switch state {
        case .jogging, .sprinting: return joggingFrames
        case .idle:                return idleFrames
        case .tired:               return tiredFrames
        case .victory:             return victoryFrames
        }
    }

    private static func leanDegrees(for state: RunnerState) -> CGFloat {
        switch state {
        case .jogging:                return runningLeanDegrees
        case .sprinting:              return sprintLeanDegrees
        case .idle, .tired, .victory: return 0
        }
    }

    // MARK: - Loading

    private static func loadMultiResolution(baseName: String) -> NSImage? {
        let img = NSImage()
        for scale in [1, 2, 3] {
            let resourceName = scale == 1 ? baseName : "\(baseName)@\(scale)x"
            guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let rep = NSBitmapImageRep(data: data) else { continue }
            rep.size = NSSize(
                width: CGFloat(rep.pixelsWide) / CGFloat(scale),
                height: CGFloat(rep.pixelsHigh) / CGFloat(scale)
            )
            img.addRepresentation(rep)
        }
        guard !img.representations.isEmpty else { return nil }
        if let smallest = img.representations.min(by: { $0.size.width < $1.size.width }) {
            img.size = smallest.size
        }
        return img
    }

    /// Rotation autour du centre, en gardant l'alpha. Utilisée seulement pour
    /// la version baked menu bar — côté SwiftUI on passe par `.rotationEffect()`.
    private static func leaned(_ image: NSImage, degrees: CGFloat, pointSize: CGFloat) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        if degrees != 0 {
            let transform = NSAffineTransform()
            transform.translateX(by: size.width / 2, yBy: size.height / 2)
            transform.rotate(byDegrees: degrees)
            transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
            transform.concat()
        }
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    // MARK: - Cache

    private static var cache: [Key: NSImage] = [:]
    private struct Key: Hashable {
        let state: RunnerState
        let frame: Int
        let pointSize: Int
    }

    // MARK: - Public API

    /// Image template à la taille demandée pour une frame d'un état donné.
    /// `frame` est mod-borné dans `[0, frameCount(for: state))`. Retourne `nil`
    /// si les assets sont absents — le caller doit alors retomber sur le rendu
    /// parametric.
    public static func image(state: RunnerState, frame: Int, pointSize: CGFloat) -> NSImage? {
        let frames = cycle(for: state)
        guard !frames.isEmpty else { return nil }
        let safe = ((frame % frames.count) + frames.count) % frames.count
        let key = Key(state: state, frame: safe, pointSize: Int(pointSize.rounded()))
        if let cached = cache[key] { return cached }
        let leaned = leaned(frames[safe], degrees: leanDegrees(for: state), pointSize: pointSize)
        guard !leaned.representations.isEmpty, leaned.size.width > 0, leaned.size.height > 0 else { return nil }
        leaned.isTemplate = true
        cache[key] = leaned
        return leaned
    }

    /// Image brute multi-rep, sans inclinaison ni resize forcé. Utilisée par
    /// SwiftUI (`RunnerView`) pour gérer rotation et scaling vectoriellement.
    public static func rawImage(state: RunnerState, frame: Int) -> NSImage? {
        let frames = cycle(for: state)
        guard !frames.isEmpty else { return nil }
        let safe = ((frame % frames.count) + frames.count) % frames.count
        return frames[safe]
    }

    /// Nombre de frames pour un état donné (0 si les assets ne sont pas chargés).
    public static func frameCount(for state: RunnerState) -> Int {
        cycle(for: state).count
    }

    /// Compatibilité avec l'ancienne API — retourne le frame count jogging.
    public static var frameCount: Int { joggingFrames.count }
}
