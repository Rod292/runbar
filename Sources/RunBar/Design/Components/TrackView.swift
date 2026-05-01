import SwiftUI

/// Piste pointillée + runner positionné selon `progress`, drapeau à droite.
/// Réplique le `track.jsx` du design (viewBox 320×80 par défaut).
public struct TrackView: View {
    public var progress: Double
    public var runnerState: RunnerState
    public var dark: Bool
    public var showFlag: Bool
    public var withRunner: Bool
    public var victory: Bool

    public init(
        progress: Double,
        runnerState: RunnerState,
        dark: Bool = false,
        showFlag: Bool = true,
        withRunner: Bool = true,
        victory: Bool = false
    ) {
        self.progress = max(0, min(1, progress))
        self.runnerState = runnerState
        self.dark = dark
        self.showFlag = showFlag
        self.withRunner = withRunner
        self.victory = victory
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let lineY: CGFloat = height * 0.7
            let startX: CGFloat = 12
            let endX: CGFloat = width - 28
            let runnerX = startX + (endX - startX) * CGFloat(progress)
            let lineColor = dark
                ? Color.white.opacity(0.32)
                : RunBarColor.granite.opacity(0.45)

            ZStack(alignment: .topLeading) {
                if victory {
                    ConfettiView(width: width, height: height)
                }

                // Baseline + dashes + decor
                Canvas { ctx, _ in
                    // Baseline continue très subtile
                    var base = Path()
                    base.move(to: CGPoint(x: startX, y: lineY))
                    base.addLine(to: CGPoint(x: endX, y: lineY))
                    ctx.stroke(base, with: .color(lineColor.opacity(0.4)), lineWidth: 0.6)

                    // Dashes (22 segments).
                    let dashCount = 22
                    let dashLen = (endX - startX) / CGFloat(dashCount)
                    for i in 0..<dashCount {
                        let x = startX + CGFloat(i) * dashLen
                        var d = Path()
                        d.move(to: CGPoint(x: x, y: lineY))
                        d.addLine(to: CGPoint(x: x + dashLen * 0.55, y: lineY))
                        ctx.stroke(d, with: .color(lineColor),
                                   style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                    }

                    // Touffes / cailloux
                    let positions: [Double] = [0.08, 0.18, 0.27, 0.4, 0.52, 0.6, 0.72, 0.84, 0.95]
                    for (i, p) in positions.enumerated() {
                        let x = startX + (endX - startX) * CGFloat(p)
                        if i % 2 == 0 {
                            // Touffe : 3 brins
                            var tuft = Path()
                            tuft.move(to: CGPoint(x: x, y: lineY + 6))
                            tuft.addLine(to: CGPoint(x: x - 1.5, y: lineY + 2))
                            tuft.move(to: CGPoint(x: x, y: lineY + 6))
                            tuft.addLine(to: CGPoint(x: x + 1.5, y: lineY + 2))
                            tuft.move(to: CGPoint(x: x, y: lineY + 6))
                            tuft.addLine(to: CGPoint(x: x, y: lineY + 1))
                            ctx.stroke(tuft, with: .color(lineColor.opacity(0.85)),
                                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        } else {
                            let pebble = CGRect(x: x - 1.6, y: lineY + 4.1, width: 3.2, height: 1.8)
                            ctx.fill(Path(ellipseIn: pebble), with: .color(lineColor.opacity(0.7)))
                        }
                    }

                    // Marqueur de départ
                    var startMark = Path()
                    startMark.move(to: CGPoint(x: startX, y: lineY - 6))
                    startMark.addLine(to: CGPoint(x: startX, y: lineY + 6))
                    ctx.stroke(startMark, with: .color(lineColor.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }

                // Runner (foreignObject équivalent)
                if withRunner {
                    let runnerSize: CGFloat = 40
                    RunnerView(state: runnerState)
                        .frame(width: runnerSize, height: runnerSize)
                        .position(x: runnerX, y: lineY - runnerSize / 2 + 2)
                        .animation(.easeOut(duration: 0.6), value: progress)
                }

                // Drapeau d'arrivée
                if showFlag {
                    FinishFlagView(size: 36, dark: dark, waving: victory)
                        .position(x: endX + 18, y: lineY - 16)
                }
            }
        }
    }
}
