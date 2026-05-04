import AppKit
import SwiftUI

/// Rend une pose du runner en `NSImage` template — pour l'icône menu bar.
/// Template image = macOS gère l'inversion light/dark automatiquement.
///
/// Le cache indexe sur (state, subframe, pointSize) où subframe va de 0 à
/// `state.frames * tweenSteps - 1`. Chaque sub-frame est une pose interpolée
/// entre deux keyframes. À 8 fps logiques × 3 tweenSteps = 24 fps de rendu.
/// Nombre d'in-betweens entre deux keyframes consécutives. Hors MainActor
/// pour pouvoir être lu depuis n'importe quel contexte (RunnerFrames notamment).
public let RunnerTweenSteps: Int = 3

@MainActor
public enum RunnerBitmap {
    /// Re-export pratique — pour l'AppDelegate timer et le code legacy.
    public static var tweenSteps: Int { RunnerTweenSteps }

    private static var cache: [Key: NSImage] = [:]
    private static let lock = NSLock()

    private struct Key: Hashable {
        let state: RunnerState
        let subframe: Int
        let pointSize: Int
    }

    /// Image cached pour un sub-frame donné. `subframe` est mod-borné dans
    /// `[0, totalSubframes(for: state))`. Pour les états avec sprites
    /// (jogging/sprinting/tired), on bypasse l'interpolation et on retourne
    /// directement la frame PNG correspondante.
    public static func image(for state: RunnerState, subframe: Int, pointSize: CGFloat = 22) -> NSImage? {
        let total = totalSubframes(for: state)
        let safe = ((subframe % total) + total) % total

        if state.hasSpriteAssets, let sprite = RunnerSprite.image(state: state, frame: safe, pointSize: pointSize) {
            return sprite
        }

        let key = Key(state: state, subframe: safe, pointSize: Int(pointSize.rounded()))

        lock.lock()
        let cached = cache[key]
        lock.unlock()
        if let cached { return cached }

        let pose = RunnerFrames.tweenedPose(for: state, subframe: safe)
        let view = StaticRunnerView(pose: pose, color: .black)
            .frame(width: pointSize, height: pointSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        renderer.isOpaque = false

        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true

        lock.lock()
        cache[key] = image
        lock.unlock()
        return image
    }

    /// Pré-calcule toutes les sub-frames de tous les états — appelé au démarrage
    /// pour que le premier affichage soit instantané. Coût total ~2KB × ~70 = ~140KB.
    public static func warmCache(pointSize: CGFloat = 22) {
        for state in RunnerState.allCases {
            let total = totalSubframes(for: state)
            for sub in 0..<total {
                _ = image(for: state, subframe: sub, pointSize: pointSize)
            }
        }
    }

    /// Total de sub-frames pour un état (utile pour boucler le timer).
    /// Les états avec sprites n'ont pas d'interpolation : 1 sub-frame = 1 PNG.
    public static func totalSubframes(for state: RunnerState) -> Int {
        state.hasSpriteAssets ? state.frames : state.frames * tweenSteps
    }
}
