import SwiftUI

/// Drapeau à damier 4×4 sur mât. ViewBox interne 32×40.
/// `waving = true` ajoute une oscillation cosinusoïdale (mode victory).
public struct FinishFlagView: View {
    public var size: CGFloat = 40
    public var dark: Bool = false
    public var waving: Bool = false

    @State private var phase: Double = 0

    public var body: some View {
        Canvas { ctx, canvasSize in
            let scale = min(canvasSize.width / 32, canvasSize.height / 40)
            ctx.scaleBy(x: scale, y: scale)
            let pole = (dark ? RunBarColor.inkLight : RunBarColor.granite)

            let wave: CGFloat = waving ? CGFloat(sin(phase) * 1.4) : 0

            // Drapeau (translaté + skew léger pour le wave).
            ctx.drawLayer { layer in
                layer.translateBy(x: wave, y: 0)
                layer.transform = layer.transform.concatenating(
                    CGAffineTransform(a: 1, b: 0, c: CGFloat(wave * 0.05), d: 1, tx: 0, ty: 0)
                )
                let cellW: CGFloat = 4
                let cellH: CGFloat = 4
                let originX: CGFloat = 6
                let originY: CGFloat = 4
                for row in 0..<4 {
                    for col in 0..<4 {
                        let isDark = (row + col) % 2 == 0
                        let cell = CGRect(
                            x: originX + CGFloat(col) * cellW,
                            y: originY + CGFloat(row) * cellH,
                            width: cellW, height: cellH
                        )
                        layer.fill(Path(cell), with: .color(isDark ? RunBarColor.slate : RunBarColor.cream))
                    }
                }
                // Bordure du drapeau
                let border = CGRect(x: originX - 0.5, y: originY - 0.5, width: 4 * cellW + 1, height: 4 * cellH + 1)
                layer.stroke(Path(border), with: .color(pole.opacity(0.7)), lineWidth: 0.6)
            }

            // Mât
            var pole1 = Path()
            pole1.move(to: CGPoint(x: 6, y: 2))
            pole1.addLine(to: CGPoint(x: 6, y: 38))
            ctx.stroke(pole1, with: .color(pole), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            // Pointe
            ctx.fill(Path(ellipseIn: CGRect(x: 4.8, y: 0.8, width: 2.4, height: 2.4)), with: .color(pole))
        }
        .frame(width: size * 0.8, height: size)
        .onAppear {
            guard waving else { return }
            Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    phase += 0.12
                }
            }
        }
    }
}
