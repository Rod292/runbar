import AppKit
import SwiftUI

/// Rend une pose du runner en `NSImage` template — pour l'icône menu bar.
/// Template image = macOS gère l'inversion light/dark automatiquement.
@MainActor
public enum RunnerBitmap {
    /// Cache simple : (state, frame) → image. Évite de re-render à chaque tick
    /// d'un timer qui boucle sur les mêmes 4-6 frames.
    private static var cache: [Key: NSImage] = [:]
    private static let lock = NSLock()

    private struct Key: Hashable {
        let state: RunnerState
        let frame: Int
        let pointSize: Int
    }

    public static func image(for state: RunnerState, frame: Int, pointSize: CGFloat = 22) -> NSImage? {
        let key = Key(state: state, frame: frame, pointSize: Int(pointSize.rounded()))
        lock.lock()
        let cached = cache[key]
        lock.unlock()
        if let cached { return cached }

        let pose = RunnerFrames.pose(for: state, frame: frame)
        let view = StaticRunnerView(pose: pose, color: .black)
            .frame(width: pointSize, height: pointSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        renderer.isOpaque = false

        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true   // light/dark auto

        lock.lock()
        cache[key] = image
        lock.unlock()
        return image
    }

    /// Précalcule toutes les frames de tous les états — appelé au démarrage
    /// pour que le premier affichage soit instantané.
    public static func warmCache(pointSize: CGFloat = 22) {
        for state in RunnerState.allCases {
            for frame in 0..<state.frames {
                _ = image(for: state, frame: frame, pointSize: pointSize)
            }
        }
    }
}
