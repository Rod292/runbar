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

    var labelKey: LocalizedStringKey {
        switch self {
        case .discovery: return "onboarding.tier.discovery"
        case .regular:   return "onboarding.tier.regular"
        case .engaged:   return "onboarding.tier.engaged"
        case .endurance: return "onboarding.tier.endurance"
        }
    }

    var label: String {
        String(localized: String.LocalizationValue(labelKeyRaw), bundle: .module)
    }

    private var labelKeyRaw: String {
        switch self {
        case .discovery: return "onboarding.tier.discovery"
        case .regular:   return "onboarding.tier.regular"
        case .engaged:   return "onboarding.tier.engaged"
        case .endurance: return "onboarding.tier.endurance"
        }
    }

    var blurbKey: LocalizedStringKey {
        switch self {
        case .discovery: return "onboarding.tier.discovery.subtitle"
        case .regular:   return "onboarding.tier.regular.subtitle"
        case .engaged:   return "onboarding.tier.engaged.subtitle"
        case .endurance: return "onboarding.tier.endurance.subtitle"
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

    var color: Color {
        switch self {
        case .discovery: return RunBarColor.moss
        case .regular:   return RunBarColor.moss
        case .engaged:   return RunBarColor.gold
        case .endurance: return RunBarColor.terra
        }
    }
}

/// Onboarding 6 étapes : Welcome → Unit → Metric → Goal → Strava → Done.
public struct OnboardingView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var coordinator: SettingsCoordinator
    var onFinish: () -> Void

    @State private var step: Int = 0
    @State private var metric: GoalMetric = .distance
    @State private var targetKm: Double = 40
    @State private var targetCount: Double = 4
    @State private var targetElev: Double = 800
    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue

    private var unit: DistanceUnit {
        DistanceUnit(rawValue: unitRaw) ?? .km
    }

    public init(
        store: ActivityStore,
        coordinator: SettingsCoordinator,
        onFinish: @escaping () -> Void
    ) {
        self.store = store
        self.coordinator = coordinator
        self.onFinish = onFinish
    }

    private let totalSteps = 6

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
                    case 1: UnitStep(unitRaw: $unitRaw).transition(stepTransition)
                    case 2: MetricStep(selected: $metric).transition(stepTransition)
                    case 3: GoalStep(metric: metric,
                                     unit: unit,
                                     targetKm: $targetKm,
                                     targetCount: $targetCount,
                                     targetElev: $targetElev).transition(stepTransition)
                    case 4: ConnectStep(coordinator: coordinator).transition(stepTransition)
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
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RunBarColor.moss : RunBarColor.moss.opacity(0.15))
                    .frame(height: 4)
                    .animation(.easeOut(duration: 0.3), value: step)
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            if step > 0 && step < totalSteps - 1 {
                Button { withAnimation { step -= 1 } } label: {
                    Text("onboarding.back", bundle: .module)
                }
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
        let isLast = step == totalSteps - 1
        Button(action: handleNext) {
            HStack(spacing: 8) {
                Text(primaryButtonKey, bundle: .module)
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

    private var primaryButtonKey: LocalizedStringKey {
        switch step {
        case 0: return "onboarding.welcome.cta"
        case totalSteps - 1: return "onboarding.done.cta"
        case 4: return coordinator.stravaConnected ? "onboarding.next" : "onboarding.connect.skip"
        default: return "onboarding.next"
        }
    }

    private func handleNext() {
        if step == 3 {
            commitGoal()
        }
        if step == totalSteps - 1 {
            onFinish()
            return
        }
        withAnimation { step += 1 }
    }

    private func commitGoal() {
        switch metric {
        case .distance:
            // targetKm est déjà en km (le slider stocke en km).
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
                Text("onboarding.welcome.subtitle", bundle: .module)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Spacer()
        }
    }
}

// MARK: - Step 1 — Unit (km vs mi)

private struct UnitStep: View {
    @Binding var unitRaw: String

    var body: some View {
        VStack(spacing: 22) {
            stepHeader(
                kickerKey: "onboarding.unit.title",
                titleKey: "onboarding.unit.title",
                subtitleKey: "onboarding.unit.subtitle"
            )

            HStack(spacing: 16) {
                unitCard(.km, title: "onboarding.tier.regular.subtitle".asLocalizedKey,
                         caption: "settings.general.unit.km")
                unitCard(.mi, title: "onboarding.tier.regular.subtitle".asLocalizedKey,
                         caption: "settings.general.unit.mi")
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    @ViewBuilder
    private func unitCard(_ value: DistanceUnit, title: LocalizedStringKey, caption: LocalizedStringKey) -> some View {
        let isOn = unitRaw == value.rawValue
        Button {
            withAnimation(.spring(response: 0.3)) { unitRaw = value.rawValue }
        } label: {
            VStack(spacing: 8) {
                Text(value == .km ? "10 km" : "6.2 mi")
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                Text(caption, bundle: .module)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
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

// MARK: - Step 2 — Metric

private struct MetricStep: View {
    @Binding var selected: GoalMetric

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                kickerKey: "onboarding.metrics.title",
                titleKey: "onboarding.metrics.title",
                subtitleKey: "onboarding.metrics.subtitle"
            )

            HStack(spacing: 14) {
                metricCard(.distance,  icon: "ruler",      title: "settings.tab.goals", example: "60 km / wk")
                metricCard(.count,     icon: "calendar",   title: "popover.outings",    example: "4 / wk")
                metricCard(.elevation, icon: "mountain.2", title: "settings.display.trail_mode", example: "1000 m+ / wk")
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    @ViewBuilder
    private func metricCard(_ value: GoalMetric, icon: String, title: LocalizedStringKey, example: String) -> some View {
        let isOn = selected == value
        Button { withAnimation(.spring(response: 0.3)) { selected = value } } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                Text(title, bundle: .module)
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

// MARK: - Step 3 — Goal value

private struct GoalStep: View {
    let metric: GoalMetric
    let unit: DistanceUnit
    @Binding var targetKm: Double
    @Binding var targetCount: Double
    @Binding var targetElev: Double

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
                kickerKey: "onboarding.goal.title",
                titleKey: "onboarding.goal.title",
                subtitleKey: "onboarding.goal.subtitle"
            )

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formatted)
                        .font(.system(size: 64, weight: .bold).monospacedDigit())
                        .tracking(-2)
                        .foregroundStyle(RunBarColor.slate)
                        .contentTransition(.numericText())
                    Text(unitLabel)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
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
            // Le store reste en km — on présente dans l'unité préférée.
            let displayValue = unit.valueFromKilometers(targetKm)
            let displayMin = unit.valueFromKilometers(10)
            let displayMax = unit.valueFromKilometers(150)
            Slider(value: Binding(
                get: { displayValue },
                set: { targetKm = unit.toKilometers($0) }
            ), in: displayMin...displayMax, step: unit == .km ? 5 : 1)
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
        case .distance:
            return "\(Int(unit.valueFromKilometers(targetKm).rounded()))"
        case .count:
            return String(Int(targetCount))
        case .elevation:
            return String(Int(targetElev))
        }
    }

    private var unitLabel: String {
        switch metric {
        case .distance:  return unit.symbol
        case .count:     return "/wk"
        case .elevation: return "m+"
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
                Text(tier.labelKey, bundle: .module)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RunBarColor.slate)
                Text(tier.blurbKey, bundle: .module)
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

// MARK: - Step 4 — Connect

private struct ConnectStep: View {
    @ObservedObject var coordinator: SettingsCoordinator

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                kickerKey: "onboarding.connect.title",
                titleKey: "onboarding.connect.title",
                subtitleKey: "onboarding.connect.subtitle"
            )

            VStack(spacing: 12) {
                if coordinator.stravaConnected {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(RunBarColor.moss)
                        Text("settings.sources.connected", bundle: .module)
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
                            Text("onboarding.connect.cta", bundle: .module)
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
            }

            Spacer()
        }
    }
}

// MARK: - Step 5 — Done

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
                Text("onboarding.done.title", bundle: .module)
                    .font(.system(size: 28, weight: .bold))
                Text("onboarding.done.subtitle", bundle: .module)
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
private func stepHeader(kickerKey: LocalizedStringKey, titleKey: LocalizedStringKey, subtitleKey: LocalizedStringKey) -> some View {
    VStack(spacing: 8) {
        Text(titleKey, bundle: .module)
            .font(.system(size: 26, weight: .bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(RunBarColor.slate)
        Text(subtitleKey, bundle: .module)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(.top, 6)
    .padding(.horizontal, 36)
}

private extension String {
    var asLocalizedKey: LocalizedStringKey { LocalizedStringKey(self) }
}
