import SwiftUI

/// Vue statique d'une pose donnée — pas de timer, frame fixe. Utile pour
/// l'export bitmap (menu bar) et les previews.
struct StaticRunnerView: View {
    let pose: RunnerPose
    let color: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 64
            context.scaleBy(x: scale, y: scale)
            drawRunner(pose: pose, in: &context, color: color)
        }
    }
}

/// Vue SwiftUI du coureur — pictogramme silhouette plein, inspiré Apple Fitness.
/// Rend une `RunnerPose` dans un canvas 64×64 puis se laisse mettre à l'échelle
/// par le parent (.frame).
public struct RunnerView: View {
    public let state: RunnerState
    /// Si fourni, force la couleur. Sinon dérive de l'état (moss/terra/gold).
    public let color: Color?
    /// Active l'animation du cycle (timer interne). Si false, affiche frame 0.
    public let animated: Bool

    @State private var frameIndex: Int = 0

    public init(state: RunnerState, color: Color? = nil, animated: Bool = true) {
        self.state = state
        self.color = color
        self.animated = animated
    }

    public var body: some View {
        let pose = RunnerFrames.pose(for: state, frame: frameIndex)
        let tint = color ?? RunBarColor.accent(for: state)

        Canvas { context, size in
            let scale = min(size.width, size.height) / 64
            context.scaleBy(x: scale, y: scale)
            drawRunner(pose: pose, in: &context, color: tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startTimer() }
        .id(state) // reset frame quand l'état change
    }

    private func startTimer() {
        guard animated else { return }
        let frames = RunnerFrames.framesFor(state: state).count
        let interval = 1.0 / state.fps
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                frameIndex = (frameIndex + 1) % frames
            }
        }
    }
}

/// Dessine la silhouette dans un GraphicsContext (canvas 64×64).
@MainActor
func drawRunner(pose: RunnerPose, in context: inout GraphicsContext, color: Color) {
    // ─── Lignes de mouvement (sprint) ─────────────────────
    if pose.motionLines {
        let line = Color(color).opacity(0.45)
        for (y, w) in [(22, 10), (32, 12), (42, 10)] as [(CGFloat, CGFloat)] {
            var path = Path()
            path.move(to: CGPoint(x: 2, y: y))
            path.addLine(to: CGPoint(x: 2 + w, y: y))
            context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
        }
    }

    // Compute neck position (haut du tronc, après le lean).
    let neck = RunnerPose.endpoint(from: pose.hip, length: pose.torsoLength, angleDeg: 360 - pose.torsoLeanDeg)
    let shoulder = neck

    // ─── Tronc (capsule entre hip et neck) ────────────────
    let torsoWidth: CGFloat = 7.5
    drawCapsule(from: pose.hip, to: neck, width: torsoWidth, color: color, in: &context)

    // ─── Tête ────────────────────────────────────────────
    let headCenter = CGPoint(x: neck.x, y: neck.y - pose.headRadius - 0.5 + pose.headOffsetY)
    let headRect = CGRect(
        x: headCenter.x - pose.headRadius,
        y: headCenter.y - pose.headRadius,
        width: pose.headRadius * 2,
        height: pose.headRadius * 2
    )
    context.fill(Path(ellipseIn: headRect), with: .color(color))

    // ─── Bras (gauche derrière, droit devant — pour un side-view) ─
    drawLimb(
        pivot: shoulder,
        upperLength: pose.upperArmLength,
        lowerLength: pose.forearmLength,
        angles: pose.armLeft,
        width: pose.limbWidth * 0.85,
        color: color.opacity(0.85),
        in: &context
    )
    drawLimb(
        pivot: shoulder,
        upperLength: pose.upperArmLength,
        lowerLength: pose.forearmLength,
        angles: pose.armRight,
        width: pose.limbWidth * 0.85,
        color: color,
        in: &context
    )

    // ─── Jambes ──────────────────────────────────────────
    drawLimb(
        pivot: pose.hip,
        upperLength: pose.thighLength,
        lowerLength: pose.calfLength,
        angles: pose.legLeft,
        width: pose.limbWidth,
        color: color.opacity(0.85),
        in: &context
    )
    drawLimb(
        pivot: pose.hip,
        upperLength: pose.thighLength,
        lowerLength: pose.calfLength,
        angles: pose.legRight,
        width: pose.limbWidth,
        color: color,
        in: &context
    )
}

/// Dessine un membre à deux segments avec articulation au coude/genou.
@MainActor
private func drawLimb(
    pivot: CGPoint,
    upperLength: CGFloat,
    lowerLength: CGFloat,
    angles: RunnerPose.LimbAngles,
    width: CGFloat,
    color: Color,
    in context: inout GraphicsContext
) {
    let joint = RunnerPose.endpoint(from: pivot, length: upperLength, angleDeg: angles.upperDeg)
    let end   = RunnerPose.endpoint(from: joint, length: lowerLength, angleDeg: angles.lowerDeg)
    drawCapsule(from: pivot, to: joint, width: width, color: color, in: &context)
    drawCapsule(from: joint, to: end,   width: width * 0.92, color: color, in: &context)
}

/// Dessine une capsule pleine entre deux points.
@MainActor
private func drawCapsule(
    from a: CGPoint,
    to b: CGPoint,
    width: CGFloat,
    color: Color,
    in context: inout GraphicsContext
) {
    var path = Path()
    path.move(to: a)
    path.addLine(to: b)
    context.stroke(
        path,
        with: .color(color),
        style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    )
}

#Preview("All states") {
    HStack(spacing: 16) {
        ForEach(RunnerState.allCases, id: \.self) { s in
            VStack {
                RunnerView(state: s)
                    .frame(width: 96, height: 96)
                    .background(RunBarColor.accent(for: s).opacity(0.08))
                    .cornerRadius(10)
                Text(s.rawValue).font(.caption2.monospaced())
            }
        }
    }
    .padding()
    .background(RunBarColor.cream)
}
