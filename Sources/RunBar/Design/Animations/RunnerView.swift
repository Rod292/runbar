import SwiftUI

/// Vue statique d'une pose donnée — pas de timer, frame fixe. Utile pour
/// l'export bitmap (menu bar) et les previews.
struct StaticRunnerView: View {
    let pose: RunnerPose
    let color: Color

    var body: some View {
        Canvas { context, size in
            // Le pose-space est 96×96. On scale uniformément pour remplir.
            let scale = min(size.width, size.height) / 96
            context.scaleBy(x: scale, y: scale)
            drawRunner(pose: pose, in: &context, color: color)
        }
    }
}

/// Vue SwiftUI animée du coureur. Pour les états avec sprites hand-drawn
/// (jogging/sprinting/tired) on cycle les PNG en mode template pour pouvoir
/// les coloriser. Pour idle/victory on garde le rendu Canvas parametric.
public struct RunnerView: View {
    public let state: RunnerState
    public let color: Color?
    public let animated: Bool

    @State private var frameIndex: Int = 0
    @State private var animationTask: Task<Void, Never>?

    public init(state: RunnerState, color: Color? = nil, animated: Bool = true) {
        self.state = state
        self.color = color
        self.animated = animated
    }

    public var body: some View {
        let tint = color ?? RunBarColor.accent(for: state)

        Group {
            if state.hasSpriteAssets {
                spriteBody(tint: tint)
            } else {
                parametricBody(tint: tint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startAnimation() }
        .onDisappear { animationTask?.cancel() }
        .onChange(of: state) { _, _ in
            frameIndex = 0
            startAnimation()
        }
        .id(state)
    }

    @ViewBuilder
    private func spriteBody(tint: Color) -> some View {
        let total = max(RunnerSprite.frameCount(for: state), 1)
        let safe = ((frameIndex % total) + total) % total
        // On charge la NSImage multi-rep (la frame native @1x/@2x/@3x). SwiftUI
        // pioche la repr Retina au moment du rendu — pas de pré-scaling pixellisé.
        // Le lean (jogging/sprinting uniquement) est appliqué vectoriellement.
        if let nsImage = RunnerSprite.rawImage(state: state, frame: safe) {
            let lean: Double = {
                switch state {
                case .jogging:   return Double(RunnerSprite.runningLeanDegrees)
                case .sprinting: return Double(RunnerSprite.sprintLeanDegrees)
                default:         return 0
                }
            }()
            Image(nsImage: nsImage)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .rotationEffect(.degrees(lean))
        } else {
            parametricBody(tint: tint)
        }
    }

    @ViewBuilder
    private func parametricBody(tint: Color) -> some View {
        let totalSubframes = state.frames * RunnerBitmap.tweenSteps
        let safe = ((frameIndex % totalSubframes) + totalSubframes) % totalSubframes
        let pose = RunnerFrames.tweenedPose(for: state, subframe: safe)

        Canvas { context, size in
            let scale = min(size.width, size.height) / 96
            context.scaleBy(x: scale, y: scale)
            drawRunner(pose: pose, in: &context, color: tint)
        }
    }

    private func startAnimation() {
        animationTask?.cancel()
        guard animated else { return }
        // Sprites = 1 frame / fps. Parametric = subframes interpolées.
        let mult = state.hasSpriteAssets ? 1.0 : Double(RunnerBitmap.tweenSteps)
        let interval = 1.0 / (state.fps * mult)
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                frameIndex &+= 1
            }
        }
    }
}

// MARK: - Drawing

/// Dessine la silhouette dans un GraphicsContext (canvas 96×96). Approche : un
/// seul `context.fill()` avec une `Path` qui contient tous les sous-paths
/// (tronc + tête + 4 membres + pieds + mains). Plus de jointures stickman,
/// pas d'overlap visible.
@MainActor
func drawRunner(pose: RunnerPose, in context: inout GraphicsContext, color: Color) {

    // Lignes de mouvement (sprint), avant la silhouette.
    if pose.motionLines {
        let line = color.opacity(0.45)
        let configs: [(CGFloat, CGFloat)] = [(34, 14), (48, 18), (62, 14)]
        for (y, w) in configs {
            var path = Path()
            path.move(to: CGPoint(x: 4, y: y))
            path.addLine(to: CGPoint(x: 4 + w, y: y))
            context.stroke(path, with: .color(line),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    // ─── Compute joint positions ──────────────────────────
    // Le tronc va de la hanche vers le haut, incliné selon torsoLeanDeg.
    // Convention : 0° = vers le haut. Pour penché vers l'avant on utilise
    // `360 - leanDeg` (pivote dans le sens trigonométrique inversé).
    let neck = RunnerPose.endpoint(from: pose.hip,
                                    length: pose.torsoLength,
                                    angleDeg: 360 - pose.torsoLeanDeg)
    // Le centre des épaules est légèrement au-dessus du cou physique.
    let shoulder = neck

    // Tête : centrée au-dessus du cou avec offset oscillant.
    let headCenter = CGPoint(
        x: shoulder.x + sin(CGFloat(pose.torsoLeanDeg) * .pi / 180) * (pose.neckLength + pose.headRadius - 1),
        y: shoulder.y - cos(CGFloat(pose.torsoLeanDeg) * .pi / 180) * (pose.neckLength + pose.headRadius - 1) + pose.headOffsetY
    )

    // ─── Build silhouette: arrière-plan d'abord (membres "loin"), avant ensuite ─

    // Bras gauche (back arm — opacité réduite pour suggérer la profondeur)
    let leftArm = limbSilhouette(
        pivot: shoulder,
        upperLength: pose.upperArmLength,
        lowerLength: pose.forearmLength,
        widthHip: pose.upperArmWidth,
        widthKnee: pose.upperArmWidth * 0.85,
        widthAnkle: pose.wristWidth,
        endRadius: pose.handRadius,
        angles: pose.armLeft,
        footLength: 0,
        footWidth: 0
    )
    context.fill(leftArm, with: .color(color.opacity(0.7)))

    // Jambe gauche
    let leftLeg = limbSilhouette(
        pivot: pose.hip,
        upperLength: pose.thighLength,
        lowerLength: pose.calfLength,
        widthHip: pose.thighWidth,
        widthKnee: pose.thighWidth * 0.78,
        widthAnkle: pose.ankleWidth,
        endRadius: 0,
        angles: pose.legLeft,
        footLength: pose.footLength,
        footWidth: pose.footWidth
    )
    context.fill(leftLeg, with: .color(color.opacity(0.78)))

    // Tronc + cou + tête en un seul path
    let body = bodyAndHeadSilhouette(
        hip: pose.hip,
        shoulder: shoulder,
        hipWidth: pose.hipWidth,
        shoulderWidth: pose.shoulderWidth,
        neckTop: neck,
        neckLength: pose.neckLength,
        neckWidth: pose.neckWidth,
        headCenter: headCenter,
        headRadius: pose.headRadius,
        leanDeg: pose.torsoLeanDeg
    )
    context.fill(body, with: .color(color))

    // Jambe droite (front)
    let rightLeg = limbSilhouette(
        pivot: pose.hip,
        upperLength: pose.thighLength,
        lowerLength: pose.calfLength,
        widthHip: pose.thighWidth,
        widthKnee: pose.thighWidth * 0.78,
        widthAnkle: pose.ankleWidth,
        endRadius: 0,
        angles: pose.legRight,
        footLength: pose.footLength,
        footWidth: pose.footWidth
    )
    context.fill(rightLeg, with: .color(color))

    // Bras droit (front)
    let rightArm = limbSilhouette(
        pivot: shoulder,
        upperLength: pose.upperArmLength,
        lowerLength: pose.forearmLength,
        widthHip: pose.upperArmWidth,
        widthKnee: pose.upperArmWidth * 0.85,
        widthAnkle: pose.wristWidth,
        endRadius: pose.handRadius,
        angles: pose.armRight,
        footLength: 0,
        footWidth: 0
    )
    context.fill(rightArm, with: .color(color))
}

// MARK: - Path builders

/// Silhouette d'un membre à 2 segments avec tapering anatomique :
/// quadrilatère taperisé épaule→coude, articulation arrondie au coude,
/// quadrilatère coude→poignet, et pied/main optionnels au bout.
private func limbSilhouette(
    pivot: CGPoint,
    upperLength: CGFloat,
    lowerLength: CGFloat,
    widthHip: CGFloat,    // Largeur à l'origine (épaule/hanche).
    widthKnee: CGFloat,   // Largeur à l'articulation (coude/genou).
    widthAnkle: CGFloat,  // Largeur au bout (poignet/cheville).
    endRadius: CGFloat,   // Rayon main (0 si jambe — on dessine un pied à la place).
    angles: RunnerPose.LimbAngles,
    footLength: CGFloat,
    footWidth: CGFloat
) -> Path {
    let joint = RunnerPose.endpoint(from: pivot, length: upperLength, angleDeg: angles.upperDeg)
    let end   = RunnerPose.endpoint(from: joint, length: lowerLength, angleDeg: angles.lowerDeg)

    var path = Path()
    addTaperedSegment(&path, from: pivot, to: joint, widthA: widthHip, widthB: widthKnee)
    // Articulation : disque à la jointure pour cacher l'angle.
    path.addEllipse(in: CGRect(x: joint.x - widthKnee/2, y: joint.y - widthKnee/2,
                                width: widthKnee, height: widthKnee))
    addTaperedSegment(&path, from: joint, to: end, widthA: widthKnee, widthB: widthAnkle)

    if endRadius > 0 {
        // Main : ovale orienté.
        path.addEllipse(in: CGRect(x: end.x - endRadius, y: end.y - endRadius,
                                    width: endRadius * 2, height: endRadius * 2))
    } else if footLength > 0 {
        // Pied : ellipse orientée perpendiculairement à la jambe basse,
        // centrée sur la cheville et avancée vers l'avant (sens horaire +90°).
        let direction = angles.lowerDeg + 90
        let footCenter = RunnerPose.endpoint(from: end,
                                              length: footLength * 0.4,
                                              angleDeg: direction)
        let footPath = orientedEllipse(center: footCenter,
                                        majorAxis: footLength,
                                        minorAxis: footWidth,
                                        angleDeg: direction)
        path.addPath(footPath)
    }

    return path
}

/// Quadrilatère à largeur variable, qui suit le segment (a→b) avec une largeur
/// `widthA` à l'origine et `widthB` à l'extrémité. Coins arrondis légèrement
/// par superposition d'un cercle aux extrémités.
private func addTaperedSegment(
    _ path: inout Path,
    from a: CGPoint,
    to b: CGPoint,
    widthA: CGFloat,
    widthB: CGFloat
) {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len = sqrt(dx*dx + dy*dy)
    guard len > 0.001 else { return }
    let nx = -dy / len  // perpendiculaire unité
    let ny =  dx / len
    let p1 = CGPoint(x: a.x + nx * widthA / 2, y: a.y + ny * widthA / 2)
    let p2 = CGPoint(x: a.x - nx * widthA / 2, y: a.y - ny * widthA / 2)
    let p3 = CGPoint(x: b.x - nx * widthB / 2, y: b.y - ny * widthB / 2)
    let p4 = CGPoint(x: b.x + nx * widthB / 2, y: b.y + ny * widthB / 2)
    path.move(to: p1)
    path.addLine(to: p2)
    path.addLine(to: p3)
    path.addLine(to: p4)
    path.closeSubpath()
}

/// Tronc trapézoïdal (hip→shoulder, plus large aux épaules) + cou + tête.
private func bodyAndHeadSilhouette(
    hip: CGPoint,
    shoulder: CGPoint,
    hipWidth: CGFloat,
    shoulderWidth: CGFloat,
    neckTop: CGPoint,
    neckLength: CGFloat,
    neckWidth: CGFloat,
    headCenter: CGPoint,
    headRadius: CGFloat,
    leanDeg: CGFloat
) -> Path {
    var path = Path()

    // Tronc : trapézoïde hip→shoulder.
    addTaperedSegment(&path, from: hip, to: shoulder,
                      widthA: hipWidth, widthB: shoulderWidth)

    // Petite ellipse de hanche pour adoucir.
    path.addEllipse(in: CGRect(x: hip.x - hipWidth/2, y: hip.y - hipWidth/2,
                                width: hipWidth, height: hipWidth))

    // Cou : court segment du sommet du tronc vers le bas du crâne.
    if neckLength > 0.5 {
        // Direction du cou : suit le lean.
        let neckEnd = RunnerPose.endpoint(from: shoulder,
                                           length: neckLength,
                                           angleDeg: 360 - leanDeg)
        addTaperedSegment(&path, from: shoulder, to: neckEnd,
                          widthA: neckWidth * 1.1, widthB: neckWidth)
    }

    // Tête : cercle plein.
    path.addEllipse(in: CGRect(
        x: headCenter.x - headRadius,
        y: headCenter.y - headRadius,
        width: headRadius * 2,
        height: headRadius * 2
    ))

    return path
}

/// Ellipse pleine orientée selon `angleDeg` (0° = vers le haut, sens horaire).
private func orientedEllipse(
    center: CGPoint,
    majorAxis: CGFloat,
    minorAxis: CGFloat,
    angleDeg: CGFloat
) -> Path {
    let unit = CGRect(x: -majorAxis / 2, y: -minorAxis / 2,
                       width: majorAxis, height: minorAxis)
    let radians = (angleDeg - 90) * .pi / 180
    let transform = CGAffineTransform.identity
        .translatedBy(x: center.x, y: center.y)
        .rotated(by: radians)
    return Path(unit).applying(transform)
}

#Preview("All states · 22pt") {
    HStack(spacing: 8) {
        ForEach(RunnerState.allCases, id: \.self) { s in
            VStack {
                RunnerView(state: s)
                    .frame(width: 22, height: 22)
                Text(s.rawValue).font(.caption2.monospaced())
            }
        }
    }
    .padding()
    .background(RunBarColor.cream)
}

#Preview("All states · 96pt") {
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
