import Combine
import SwiftUI

/// Icône menu bar. MenuBarExtra ne rend pas correctement les vues `Canvas`
/// custom — on utilise donc un SF Symbol `figure.run` template-image qui
/// s'adapte automatiquement light/dark, et on cycle entre des variantes
/// pour donner un effet d'animation façon RunCat.
public struct MenuBarIconView: View {
    let state: RunnerState
    @State private var frame: Int = 0

    public init(state: RunnerState) {
        self.state = state
    }

    public var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 14, weight: .semibold))
            .onReceive(timer) { _ in
                let frames = state.frames
                frame = (frame + 1) % frames
            }
    }

    /// SF Symbol par état + frame. SF a une famille `figure.*` riche, on
    /// alterne entre 2-3 glyphes pour suggérer le mouvement.
    private var symbolName: String {
        switch state {
        case .idle:
            return ["figure.stand", "figure.stand.line.dotted.figure.stand"][frame % 2]
        case .jogging:
            return ["figure.run", "figure.walk"][frame % 2]
        case .sprinting:
            return ["figure.run", "figure.run.circle.fill", "figure.run"][frame % 3]
        case .tired:
            return ["figure.walk", "figure.walk.motion"][frame % 2]
        case .victory:
            return ["figure.run", "trophy.fill"][frame % 2]
        }
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: 1.0 / state.fps, on: .main, in: .common).autoconnect()
    }
}
