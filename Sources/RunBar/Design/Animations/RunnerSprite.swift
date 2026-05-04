import AppKit
import Foundation

/// Charge les frames PNG hand-drawn (template macOS) depuis le bundle.
/// Les 8 frames partagées (`frame-1.png` ... `frame-8.png` avec @2x/@3x)
/// constituent un cycle de course unique réutilisé par jogging, sprinting
/// et tired — la différence est dans `RunnerState.fps`, pas dans les frames.
@MainActor
public enum RunnerSprite {

    /// Vrai si on a réussi à charger les frames depuis le bundle.
    public static var isAvailable: Bool { !rawFrames.isEmpty }

    /// Inclinaison appliquée à toutes les frames pour donner l'impression de
    /// course. Positive = penché vers l'avant (sens de la course = droite).
    private static let leanDegrees: CGFloat = -6

    /// Frames brutes (résolution native), pré-inclinées vers l'avant.
    private static let rawFrames: [NSImage] = (1...8).compactMap { i in
        guard let url = Bundle.module.url(forResource: "frame-\(i)", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        return leaned(img, degrees: leanDegrees)
    }

    /// Rotation autour du centre de l'image, en gardant l'alpha. La rotation
    /// est légère (~6°), donc on conserve la même bbox sans couper la silhouette
    /// (les frames ont du padding transparent autour).
    private static func leaned(_ image: NSImage, degrees: CGFloat) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let transform = NSAffineTransform()
        transform.translateX(by: size.width / 2, yBy: size.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    private static var cache: [Key: NSImage] = [:]
    private struct Key: Hashable { let frame: Int; let pointSize: Int }

    /// Image template à la taille demandée pour une frame de course donnée.
    /// `frame` est mod-borné dans `[0, 8)`. Retourne `nil` si les assets sont
    /// absents — le caller doit alors retomber sur le rendu parametric.
    public static func image(frame: Int, pointSize: CGFloat) -> NSImage? {
        guard !rawFrames.isEmpty else { return nil }
        let safe = ((frame % rawFrames.count) + rawFrames.count) % rawFrames.count
        let key = Key(frame: safe, pointSize: Int(pointSize.rounded()))
        if let cached = cache[key] { return cached }
        guard let copy = rawFrames[safe].copy() as? NSImage else { return nil }
        copy.size = NSSize(width: pointSize, height: pointSize)
        copy.isTemplate = true
        cache[key] = copy
        return copy
    }

    /// Nombre de frames du cycle de course (8 si les assets sont chargés, 0 sinon).
    public static var frameCount: Int { rawFrames.count }
}
