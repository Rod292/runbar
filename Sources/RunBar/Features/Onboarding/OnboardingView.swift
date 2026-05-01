import SwiftUI

/// Tier de coureur — utilisé pour donner un repère gamifié sur l'objectif.
enum RunnerTier: String, CaseIterable {
    case discovery   // 0-25 km
    case regular     // 25-50 km
    case engaged     // 50-80 km
    case endurance   // 80+ km

    static func tier(forKm km: Double) -> RunnerTier {
        switch km {
        case ..<25:  return .discovery
        case ..<50:  return .regular
        case ..<80:  return .engaged
        default:     return .endurance
        }
    }

    var label: String {
        switch self {
        case .discovery: return "Découverte"
        case .regular:   return "Régulier"
        case .engaged:   return "Engagé"
        case .endurance: return "Endurance"
        }
    }

    var symbol: String {
        switch self {
        case .discovery: return "leaf"
        case .regular:   return "tree"
        case .engaged:   return "mountain.2"
        case .endurance: return "trophy"
        }
    }

    var blurb: String {
        switch self {
        case .discovery: return "Tu te lances. Une à deux sorties par semaine."
        case .regular:   return "Trois à quatre sorties. Tu commences à voir les progrès."
        case .engaged:   return "Quatre à cinq sorties. Préparation 10 km / semi."
        case .endurance: return "Cinq sorties et plus. Marathon ou ultra dans le viseur."
        }
    }

    var color: Color {
        switch self {
        case .discovery: return RunBarColor.moss
        case .regular:   return RunBarColor.moss
        case .engaged:   return RunBarColor.gold
        case .endurance: return RunBarColor.terra
        }
    }
}

/// Onboarding 5 étapes : Welcome → Métrique → Objectif → Strava → Done.
public struct OnboardingView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var coordinator: SettingsCoordinator
    var onFinish: () -> Void

    @State private var step: Int = 0
    @State private var metric: GoalMetric = .distance
    @State private var targetKm: Double = 40
    @State private var targetCount: Double = 4
    @State private var targetElev: Double = 800

    public init(
        store: ActivityStore,
        coordinator: SettingsCoordinator,
        onFinish: @escaping () -> Void
    ) {
        self.store = store
        self.coordinator = coordinator
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                progressBar
                    .padding(.top, 24)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 16)

                Group {
                    switch step {
                    case 0: WelcomeStep().transition(stepTransition)
                    case 1: MetricStep(selected: $metric).transition(stepTransition)
                    case 2: GoalStep(metric: metric,
                                     targetKm: $targetKm,
                                     targetCount: $targetCount,
                                     targetElev: $targetElev).transition(stepTransition)
                    case 3: ConnectStep(coordinator: coordinator).transition(stepTransition)
                    default: DoneStep().transition(stepTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)

                navigationBar
                    .padding(.horizontal, 36)
                    .padding(.vertical, 22)
            }
        }
        .frame(width: 720, height: 560)
        .preferredColorScheme(.light)
    }

    // MARK: - Sections

    private var background: some View {
        LinearGradient(
            colors: [
                RunBarColor.cream,
                Color(red: 0.94, green: 0.91, blue: 0.83)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RunBarColor.moss : RunBarColor.moss.opacity(0.15))
                    .frame(height: 4)
                    .animation(.easeOut(duration: 0.3), value: step)
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            if step > 0 && step < 4 {
                Button("Retour") { withAnimation { step -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            } else {
                Spacer().frame(height: 1)
            }
            Spacer()
            primaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        let isLast = step == 4
        Button(action: handleNext) {
            HStack(spacing: 8) {
                Text(primaryButtonLabel)
                    .font(.system(size: 14, weight: .semibold))
                if !isLast {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(RunBarColor.slate)
            )
            .foregroundStyle(RunBarColor.cream)
        }
        .buttonStyle(.plain)
    }

    private var primaryButtonLabel: String {
        switch step {
        case 0: return "Commencer"
        case 1: return "Continuer"
        case 2: return "Continuer"
        case 3: return coordinator.stravaConnected ? "Continuer" : "Plus tard"
        default: return "C'est parti"
        }
    }

    private func handleNext() {
        if step == 2 {
            commitGoal()
        }
        if step == 4 {
            onFinish()
            return
        }
        withAnimation { step += 1 }
    }

    private func commitGoal() {
        switch metric {
        case .distance:
            store.goal = WeeklyGoal(metric: .distance, target: targetKm)
        case .count:
            store.goal = WeeklyGoal(metric: .count, target: targetCount)
        case .elevation:
            store.goal = WeeklyGoal(metric: .elevation, target: targetElev)
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - Step 0 — Welcome

private struct WelcomeStep: View {
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RunBarColor.moss.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                Circle()
                    .fill(RunBarColor.moss.opacity(0.18))
                    .frame(width: 160, height: 160)
                RunnerView(state: .jogging, color: RunBarColor.slate)
                    .frame(width: 130, height: 130)
            }
            .onAppear { pulse = true }

            VStack(spacing: 10) {
                Text("RunBar")
                    .font(.system(size: 38, weight: .bold))
                    .tracking(-0.8)
                Text("Un compagnon discret pour ta semaine de course.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Spacer()
        }
    }
}

// MARK: - Step 1 — Metric

private struct MetricStep: View {
    @Binding var selected: GoalMetric

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                kicker: "Étape 1 / 3",
                title: "Comment tu mesures ta semaine ?",
                subtitle: "Tu peux changer plus tard dans Préférences."
            )

            HStack(spacing: 14) {
                metricCard(.distance, icon: "ruler", title: "Distance",      example: "60 km / sem")
                metricCard(.count,    icon: "calendar", title: "Sorties",     example: "4 séances / sem")
                metricCard(.elevation, icon: "mountain.2", title: "Dénivelé", example: "1000 m D+ / sem")
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    @ViewBuilder
    private func metricCard(_ value: GoalMetric, icon: String, title: String, example: String) -> some View {
        let isOn = selected == value
        Button(action: { withAnimation(.spring(response: 0.3)) { selected = value } }) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                Text(example)
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(isOn
                                     ? RunBarColor.cream.opacity(0.75)
                                     : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? RunBarColor.slate : Color.white.opacity(0.6))
                    .shadow(color: .black.opacity(isOn ? 0.18 : 0.05), radius: isOn ? 12 : 4, y: isOn ? 6 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isOn ? RunBarColor.moss : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isOn ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2 — Goal value

private struct GoalStep: View {
    let metric: GoalMetric
    @Binding var targetKm: Double
    @Binding var targetCount: Double
    @Binding var targetElev: Double

    private var currentValue: Double {
        switch metric {
        case .distance:  return targetKm
        case .count:     return targetCount
        case .elevation: return targetElev
        }
    }

    private var tier: RunnerTier {
        switch metric {
        case .distance:  return RunnerTier.tier(forKm: targetKm)
        case .count:     return RunnerTier.tier(forKm: targetCount * 8) // proxy
        case .elevation: return RunnerTier.tier(forKm: targetElev / 20)
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            stepHeader(
                kicker: "Étape 2 / 3",
                title: "Vise ton objectif hebdo",
                subtitle: "Le bonhomme reflètera où tu en es chaque jour."
            )

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formatted)
                        .font(.system(size: 64, weight: .bold).monospacedDigit())
                        .tracking(-2)
                        .foregroundStyle(RunBarColor.slate)
                        .contentTransition(.numericText())
                    Text(metric.unit)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("par semaine").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            sliderForCurrent

            tierBadge
                .padding(.top, 6)

            Spacer()
        }
    }

    @ViewBuilder
    private var sliderForCurrent: some View {
        switch metric {
        case .distance:
            Slider(value: $targetKm, in: 10...150, step: 5)
                .tint(RunBarColor.moss)
                .frame(maxWidth: 420)
        case .count:
            Slider(value: $targetCount, in: 1...10, step: 1)
                .tint(RunBarColor.moss)
                .frame(maxWidth: 420)
        case .elevation:
            Slider(value: $targetElev, in: 100...3000, step: 100)
                .tint(RunBarColor.moss)
                .frame(maxWidth: 420)
        }
    }

    private var formatted: String {
        switch metric {
        case .distance:  return String(Int(targetKm))
        case .count:     return String(Int(targetCount))
        case .elevation: return String(Int(targetElev))
        }
    }

    private var tierBadge: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tier.color.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: tier.symbol)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(tier.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Niveau \(tier.label)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RunBarColor.slate)
                Text(tier.blurb)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 320, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
        )
        .animation(.spring(response: 0.4), value: tier)
    }
}

// MARK: - Step 3 — Connect

private struct ConnectStep: View {
    @ObservedObject var coordinator: SettingsCoordinator

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                kicker: "Étape 3 / 3",
                title: "Connecte tes sorties",
                subtitle: "Strava synchronise tes courses toutes les 30 minutes."
            )

            VStack(spacing: 12) {
                if coordinator.stravaConnected {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(RunBarColor.moss)
                        Text("Strava connecté")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(RunBarColor.moss.opacity(0.12))
                    )
                } else {
                    Button(action: { Task { await coordinator.connectStrava() } }) {
                        HStack(spacing: 10) {
                            AsyncImage(url: URL(string: "https://d3nn82uaxijpm6.cloudfront.net/icon-strava-chrome-192.png")) { img in
                                img.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: { Color.clear }
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            Text(coordinator.stravaBusy ? "Connexion…" : "Connecter Strava")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.99, green: 0.30, blue: 0.01))
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.stravaBusy)
                }

                if let err = coordinator.stravaError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Text("Apple Health et Garmin arrivent bientôt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()
        }
    }
}

// MARK: - Step 4 — Done

private struct DoneStep: View {
    @State private var pop: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RunBarColor.gold.opacity(0.15))
                    .frame(width: 200, height: 200)
                Circle()
                    .fill(RunBarColor.gold.opacity(0.25))
                    .frame(width: 130, height: 130)
                RunnerView(state: .victory, color: RunBarColor.slate)
                    .frame(width: 110, height: 110)
                    .scaleEffect(pop ? 1.0 : 0.6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: pop)
                ConfettiView(width: 320, height: 220)
            }
            .frame(height: 240)
            .onAppear { pop = true }

            VStack(spacing: 8) {
                Text("Tu es prêt")
                    .font(.system(size: 28, weight: .bold))
                Text("Le runner t'attend en haut à droite. Bonne semaine.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
}

// MARK: - Helpers

@ViewBuilder
private func stepHeader(kicker: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 8) {
        Text(kicker)
            .font(.system(size: 11, weight: .semibold).monospaced())
            .tracking(0.8)
            .foregroundStyle(RunBarColor.moss)
        Text(title)
            .font(.system(size: 26, weight: .bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(RunBarColor.slate)
        Text(subtitle)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(.top, 6)
    .padding(.horizontal, 36)
}
