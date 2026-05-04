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

    /// Inclinaison utilisée pour donner l'impression de course (négatif = vers
    /// l'avant). Appliquée par SwiftUI côté `RunnerView` pour préserver la
    /// résolution Retina, et au moment du baking NSImage menu bar (où le
    /// rendu se fait à 22pt template, donc la perte de qualité est invisible).
    public static let leanDegrees: CGFloat = -6

    /// Frames brutes — agrégat multi-résolutions (@1x + @2x + @3x) chargé
    /// comme une seule NSImage. macOS choisit alors la meilleure rep selon
    /// le scale factor de l'écran, sans rasterisation prématurée.
    private static let rawFrames: [NSImage] = (1...8).map { i in
        loadMultiResolution(baseName: "frame-\(i)") ?? NSImage()
    }

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

    /// Rotation autour du centre de l'image, en gardant l'alpha. Appliquée
    /// uniquement à la version baked menu bar (22pt). Côté SwiftUI on passe
    /// par `.rotationEffect()` pour préserver la qualité Retina.
    private static func leaned(_ image: NSImage, degrees: CGFloat, pointSize: CGFloat) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
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
    /// La rotation `leanDegrees` est bakée dans la bitmap menu bar.
    public static func image(frame: Int, pointSize: CGFloat) -> NSImage? {
        guard !rawFrames.isEmpty else { return nil }
        let safe = ((frame % rawFrames.count) + rawFrames.count) % rawFrames.count
        let key = Key(frame: safe, pointSize: Int(pointSize.rounded()))
        if let cached = cache[key] { return cached }
        let leaned = leaned(rawFrames[safe], degrees: leanDegrees, pointSize: pointSize)
        leaned.isTemplate = true
        cache[key] = leaned
        return leaned
    }

    /// Image brute multi-rep, sans inclinaison ni resize forcé. Utilisée
    /// par SwiftUI (`RunnerView`) qui préfère gérer rotation et scaling
    /// vectoriellement — ce qui élimine la pixellisation sur Retina.
    public static func rawImage(frame: Int) -> NSImage? {
        guard !rawFrames.isEmpty else { return nil }
        let safe = ((frame % rawFrames.count) + rawFrames.count) % rawFrames.count
        return rawFrames[safe]
    }

    /// Nombre de frames du cycle de course (8 si les assets sont chargés, 0 sinon).
    public static var frameCount: Int { rawFrames.count }
}
