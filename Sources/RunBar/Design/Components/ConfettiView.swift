import SwiftUI

/// Confettis discrets pour la célébration victory.
/// 14 morceaux qui tombent en boucle, déphasés et colorés.
public struct ConfettiView: View {
    public var width: CGFloat
    public var height: CGFloat

    @State private var t: Double = 0

    private static let palette: [Color] = [
        RunBarColor.moss, RunBarColor.terra, RunBarColor.gold,
        Color(red: 0x4A/255, green: 0x8F/255, blue: 0xB8/255),
        Color(red: 0xB8/255, green: 0x6C/255, blue: 0xA8/255),
    ]

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        Canvas { ctx, _ in
            for i in 0..<14 {
                // pseudo-random reproductible
                let seed = (sin(Double(i) * 9.7) + 1) / 2
                let xBase = width - 40 - CGFloat(seed) * 80
                let yBase = 6 + CGFloat((sin(Double(i + 3) * 9.7) + 1) / 2) * 30
                let phase = (t + Double(i) * 0.08).truncatingRemainder(dividingBy: 1.6) / 1.6
                let x = xBase - CGFloat(phase) * 12
                let y = yBase + CGFloat(phase) * 80
                let opacity = max(0, sin(phase * .pi))
                let rotation = phase * 360 + seed * 360
                let color = Self.palette[i % Self.palette.count].opacity(opacity)

                ctx.drawLayer { layer in
                    layer.translateBy(x: x + 1.5, y: y + 3)
                    layer.rotate(by: .degrees(rotation))
                    layer.fill(Path(CGRect(x: -1.5, y: -3, width: 3, height: 6)), with: .color(color))
                }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .onAppear {
            Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    t += 0.016
                }
            }
        }
    }
}
