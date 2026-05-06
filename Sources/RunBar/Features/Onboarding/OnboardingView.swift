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
        String(localized: String.LocalizationValue(labelKeyRaw), bundle: .runBarResources)
    }

    private var labelKeyRaw: String {
        switch self {
        case .discovery: return "onboarding.tier.discovery"
        case .regular:   return "onboarding.tier.regular"
        case .engaged:   return "onboarding.tier.engaged"
        case .endurance: return "onboarding.tier.endurance"
        }
    }

    func blurb(unit: DistanceUnit) -> String {
        switch self {
        case .discovery:
            return String(format: String(localized: "onboarding.tier.discovery.dynamic", bundle: .runBarResources),
                          Int(unit.valueFromKilometers(10).rounded()), unit.symbol)
        case .regular:
            return String(format: String(localized: "onboarding.tier.regular.dynamic", bundle: .runBarResources),
                          Int(unit.valueFromKilometers(25).rounded()), unit.symbol)
        case .engaged:
            return String(format: String(localized: "onboarding.tier.engaged.dynamic", bundle: .runBarResources),
                          Int(unit.valueFromKilometers(50).rounded()), unit.symbol)
        case .endurance:
            return String(format: String(localized: "onboarding.tier.endurance.dynamic", bundle: .runBarResources),
                          Int(unit.valueFromKilometers(80).rounded()), unit.symbol)
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

/// Onboarding 6 étapes — direction éditoriale alignée sur la landing page :
/// fond ivoire + grain papier, eyebrow mono small-caps, titres italique
/// display serif, hairlines, accent terra. Garde la chaleur visuelle
/// (runner pulsant, confettis) sans tomber dans le SaaS générique.
public struct OnboardingView: View {
    @ObservedObject var store: ActivityStore
    @ObservedObject var snapshots: SnapshotStore
    @ObservedObject var coordinator: SettingsCoordinator
    @ObservedObject var coachConfig: CoachConfiguration
    var onFinish: () -> Void

    @State private var step: Int = 0
    @AppStorage("runbar.onboarding.restartToken") private var restartToken: Int = 0
    @State private var lastSeenRestartToken: Int = 0
    @State private var metric: GoalMetric = .distance
    @State private var targetKm: Double = 40
    @State private var targetCount: Double = 4
    @State private var targetElev: Double = 800
    /// Set when we land on the Goal step and the seed came from the user's
    /// recent Strava history. Used to render the "based on your last weeks"
    /// banner instead of the generic "use the slider" caption.
    @State private var suggestionSeeded: Bool = false
    @State private var suggestionAvgKm: Double? = nil
    /// Race state — saved on commitRace() in `handleNext`.
    @State private var raceEnabled: Bool = false
    @State private var raceName: String = ""
    @State private var raceDate: Date = Date.now.addingTimeInterval(30 * 24 * 3600)
    /// Draft for the optional Gemini API key. Saved on leaving the Coach step.
    @State private var coachKeyDraft: String = ""
    @State private var coachKeyError: String? = nil
    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue

    private var unit: DistanceUnit {
        DistanceUnit(rawValue: unitRaw) ?? .km
    }

    public init(
        store: ActivityStore,
        snapshots: SnapshotStore,
        coordinator: SettingsCoordinator,
        coachConfig: CoachConfiguration,
        onFinish: @escaping () -> Void
    ) {
        self.store = store
        self.snapshots = snapshots
        self.coordinator = coordinator
        self.coachConfig = coachConfig
        self.onFinish = onFinish
    }

    private let totalSteps = 8

    public var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 22)
                    .padding(.horizontal, 36)

                Group {
                    switch step {
                    case 0: WelcomeStep().transition(stepTransition)
                    case 1: UnitStep(unitRaw: $unitRaw, stepIndex: 1, total: totalSteps).transition(stepTransition)
                    case 2: MetricStep(selected: $metric, unit: unit, stepIndex: 2, total: totalSteps).transition(stepTransition)
                    case 3: ConnectStep(coordinator: coordinator, stepIndex: 3, total: totalSteps).transition(stepTransition)
                    case 4: GoalStep(metric: metric,
                                     unit: unit,
                                     targetKm: $targetKm,
                                     targetCount: $targetCount,
                                     targetElev: $targetElev,
                                     suggestionSeeded: suggestionSeeded,
                                     suggestionAvgKm: suggestionAvgKm,
                                     stepIndex: 4,
                                     total: totalSteps).transition(stepTransition)
                    case 5: RaceStep(unit: unit,
                                     enabled: $raceEnabled,
                                     name: $raceName,
                                     date: $raceDate,
                                     stepIndex: 5,
                                     total: totalSteps).transition(stepTransition)
                    case 6: CoachStep(
                        keyDraft: $coachKeyDraft,
                        errorMessage: coachKeyError,
                        providerName: coachConfig.provider.displayName,
                        apiKeyURL: coachConfig.provider.apiKeyURL,
                        stepIndex: 6,
                        total: totalSteps
                    ).transition(stepTransition)
                    default: DoneStep(metric: metric,
                                      unit: unit,
                                      targetKm: targetKm,
                                      targetCount: targetCount,
                                      targetElev: targetElev).transition(stepTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)

                navigationBar
                    .padding(.horizontal, 36)
                    .padding(.vertical, 22)
            }
        }
        .frame(width: 720, height: 580)
        .preferredColorScheme(.light)
        // The first Strava sync is async. Two race conditions used to
        // strand BYO users on the 40 km fallback:
        //   1. Sync lands before they advance to Goal (count change fired
        //      while step == 3, so an earlier "step == 4" guard skipped it).
        //   2. Sync lands after, but they advance to step 4 and never see
        //      another count change to trigger the seed.
        // Listening regardless of step + bailing only on suggestionSeeded /
        // metric handles both: the seed is idempotent and the ceil/cap math
        // produces the same answer no matter when it runs.
        .onChange(of: store.activities.count) { _, _ in
            if !suggestionSeeded && metric == .distance {
                seedSuggestedGoalIfPossible()
            }
        }
        .onAppear {
            // SwiftUI Window scene reuses this view between open/close, so
            // the @State `step` lingers at the Done screen after the user
            // finished once. The Settings "Restart onboarding" button bumps
            // restartToken; we read it on appear and reset to step 0 if it
            // changed since we last looked.
            if restartToken != lastSeenRestartToken {
                step = 0
                suggestionSeeded = false
                suggestionAvgKm = nil
                coachKeyDraft = ""
                coachKeyError = nil
                raceEnabled = false
                raceName = ""
                lastSeenRestartToken = restartToken
            }
            if !suggestionSeeded && metric == .distance {
                seedSuggestedGoalIfPossible()
            }
        }
    }

    // MARK: - Sections

    private var background: some View {
        ZStack {
            Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xEE / 255) // --color-ivory
            // paper grain
            GeometryReader { geo in
                Canvas { ctx, size in
                    // very subtle dot pattern
                    let step: CGFloat = 3
                    var x: CGFloat = 0
                    while x < size.width {
                        var y: CGFloat = 0
                        while y < size.height {
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                                with: .color(.black.opacity(0.025))
                            )
                            y += step
                        }
                        x += step
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            // wordmark
            HStack(spacing: 4) {
                Text("Run")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .italic()
                Text("Bar")
                    .font(.system(size: 16, weight: .medium))
                Circle().fill(RunBarColor.terra).frame(width: 5, height: 5)
                    .offset(y: -6)
            }
            Spacer()
            // step counter
            Text("Step \(min(step + 1, totalSteps)) of \(totalSteps)")
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(RunBarColor.mutedInk(dark: false))
        }
    }

    private var hairlineProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RunBarColor.faintInk(dark: false))
                    .frame(height: 1)
                Rectangle()
                    .fill(RunBarColor.terra)
                    .frame(
                        width: geo.size.width * CGFloat(min(step + 1, totalSteps)) / CGFloat(totalSteps),
                        height: 1
                    )
                    .animation(.easeOut(duration: 0.35), value: step)
            }
        }
        .frame(height: 1)
    }

    private var navigationBar: some View {
        VStack(spacing: 14) {
            hairlineProgress

            HStack {
                if step > 0 && step < totalSteps - 1 {
                    Button { withAnimation { step -= 1 } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("onboarding.back", bundle: .runBarResources)
                                .underline()
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                    .font(.system(size: 13))
                } else {
                    Spacer().frame(height: 1)
                }
                Spacer()
                primaryButton
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        let isLast = step == totalSteps - 1
        Button(action: handleNext) {
            HStack(spacing: 8) {
                Text(primaryButtonKey, bundle: .runBarResources)
                    .font(.system(size: 13, weight: .semibold))
                if !isLast {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(RunBarColor.slate)
            )
            .foregroundStyle(Color(red: 0xFB / 255, green: 0xF9 / 255, blue: 0xF4 / 255)) // paper
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var primaryButtonKey: LocalizedStringKey {
        switch step {
        case 0: return "onboarding.welcome.cta"
        case totalSteps - 1: return "onboarding.done.cta"
        case 3: return coordinator.stravaConnected ? "onboarding.next" : "onboarding.connect.skip"
        case 5: return raceEnabled ? "onboarding.next" : "onboarding.race.skip"
        case 6:
            return coachKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty
                ? "onboarding.coach.skip"
                : "onboarding.next"
        default: return "onboarding.next"
        }
    }

    private func handleNext() {
        // From Strava → Goal: seed a suggested target if we have history.
        if step == 3 {
            seedSuggestedGoalIfPossible()
        }
        // Leaving Goal → Race: commit the goal so race step can update it in-place.
        if step == 4 {
            commitGoal()
        }
        // Leaving Race → Coach: persist race fields (or clear them).
        if step == 5 {
            commitRace()
        }
        // Leaving Coach → Done: persist key if user typed one.
        if step == 6 {
            if !commitCoachKey() { return }
        }
        if step == totalSteps - 1 {
            onFinish()
            return
        }
        withAnimation { step += 1 }
    }

    /// Sauvegarde la clé Gemini si non vide ; active le coach automatiquement.
    /// Retourne false si l'enregistrement Keychain échoue (laisse l'utilisateur
    /// corriger plutôt que d'avancer en silence).
    private func commitCoachKey() -> Bool {
        let trimmed = coachKeyDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            coachKeyError = nil
            return true
        }
        do {
            try coachConfig.setKey(trimmed)
            coachConfig.enabled = true
            coachKeyError = nil
            return true
        } catch {
            coachKeyError = error.localizedDescription
            return false
        }
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

    private func commitRace() {
        if raceEnabled {
            let trimmed = raceName.trimmingCharacters(in: .whitespaces)
            store.goal.raceName = trimmed.isEmpty ? nil : trimmed
            store.goal.raceDate = raceDate
        } else {
            store.goal.raceName = nil
            store.goal.raceDate = nil
        }
    }

    /// Suggests a weekly km target from the user's recent running history.
    /// Adds a +10% buffer (rounded to nearest 5) so the goal pushes slightly
    /// above their current pace. No-op if metric ≠ distance or no usable data.
    ///
    /// Data sources, in priority order:
    ///
    /// 1. `WeeklySnapshot` — derived weekly aggregates persisted by
    ///    `SettingsCoordinator.seedHistoricalSnapshots()` at connect time.
    ///    Reaches back beyond the 7-day cache window because we fetch +
    ///    aggregate + persist-only-the-aggregates (Strava API Agreement
    ///    explicitly permits derived data beyond 7 days). Best signal,
    ///    used whenever available.
    ///
    /// 2. `store.activities` — only ~7 days of raw activities (rolling
    ///    cache). Fallback when snapshots haven't been seeded yet (e.g.
    ///    first sync still in flight, no Strava connection at all). The
    ///    divisor adapts to the actual span of data so we don't divide
    ///    one week of runs by a hard-coded 4.
    ///
    /// In both branches we exclude the in-progress ISO week — it's by
    /// definition partial and would drag the average down on a Monday.
    private func seedSuggestedGoalIfPossible() {
        guard metric == .distance else { return }
        let cal = Calendar.iso8601Monday
        let now = Date.now
        guard let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start,
              let cutoff = cal.date(byAdding: .day, value: -28, to: currentWeekStart) else { return }

        // Branch 1: prefer the derived weekly snapshots when present.
        let completedWeekSnapshots = snapshots.snapshots.filter {
            $0.metric == .distance && $0.weekStart >= cutoff && $0.weekStart < currentWeekStart
        }
        if !completedWeekSnapshots.isEmpty {
            let totalKm = completedWeekSnapshots.reduce(0.0) { $0 + $1.achieved }
            let avgKm = totalKm / Double(completedWeekSnapshots.count)
            applySeed(avgKm: avgKm)
            return
        }

        // Branch 2: fall back to the rolling 7-day raw activities.
        let completedWeekRuns = store.activities.filter {
            $0.startDate >= cutoff && $0.startDate < currentWeekStart
        }
        let recent: [Activity]
        let upperBound: Date
        if !completedWeekRuns.isEmpty {
            recent = completedWeekRuns
            upperBound = currentWeekStart
        } else {
            recent = store.activities.filter { $0.startDate >= cutoff }
            guard !recent.isEmpty else { return }
            upperBound = now
        }
        let totalKm = recent.reduce(0) { $0 + ($1.distance / 1000.0) }
        let oldestDate = recent.map(\.startDate).min() ?? cutoff
        let weeksSpan = max(1.0, min(4.0, upperBound.timeIntervalSince(oldestDate) / (7 * 24 * 3600)))
        applySeed(avgKm: totalKm / weeksSpan)
    }

    private func applySeed(avgKm: Double) {
        guard avgKm > 0.5 else { return }
        let raw = ceil(avgKm * 1.1 / 5) * 5
        let suggested = min(150, max(10, raw))
        targetKm = suggested
        suggestionAvgKm = avgKm
        suggestionSeeded = true
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
        VStack(spacing: 26) {
            Spacer()

            // editorial wordmark, oversized
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Run")
                        .font(.system(size: 76, weight: .medium, design: .serif))
                        .italic()
                        .tracking(-3)
                        .foregroundStyle(RunBarColor.slate)
                    Text("Bar")
                        .font(.system(size: 76, weight: .medium))
                        .tracking(-3)
                        .foregroundStyle(RunBarColor.slate)
                    Circle()
                        .fill(RunBarColor.terra)
                        .frame(width: 14, height: 14)
                        .offset(y: -34)
                }
                Text("— a runner in your menu bar.")
                    .font(.system(size: 18, design: .serif))
                    .italic()
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
            }

            // animated runner under a hairline horizon
            ZStack {
                VStack(spacing: 10) {
                    RunnerView(state: .jogging, color: RunBarColor.slate)
                        .frame(width: 90, height: 90)
                        .offset(y: pulse ? -3 : 0)
                        .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: pulse)

                    Rectangle()
                        .fill(RunBarColor.faintInk(dark: false))
                        .frame(width: 220, height: 1)

                    HStack(spacing: 16) {
                        Text("0")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                        Text("·")
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                        Text("week")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                        Text("·")
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                        Text("∞")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(RunBarColor.terra)
                    }
                }
            }
            .padding(.top, 6)
            .onAppear { pulse = true }

            // subtitle
            Text("onboarding.welcome.subtitle", bundle: .runBarResources)
                .font(.system(size: 14))
                .foregroundStyle(RunBarColor.mutedInk(dark: false))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Spacer()

            // colophon
            HStack(spacing: 14) {
                Text("MIT · 2026")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false).opacity(0.6))
                Rectangle()
                    .fill(RunBarColor.faintInk(dark: false))
                    .frame(width: 22, height: 1)
                Text("local-first")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false).opacity(0.6))
            }
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Step 1 — Unit (km vs mi)

private struct UnitStep: View {
    @Binding var unitRaw: String
    let stepIndex: Int
    let total: Int

    var body: some View {
        VStack(spacing: 24) {
            stepHeader(
                stepIndex: stepIndex,
                total: total,
                kicker: "onboarding.unit.title",
                italicWord: "Choose.",
                subtitleKey: "onboarding.unit.subtitle"
            )

            HStack(spacing: 14) {
                unitCard(.km, caption: "settings.general.unit.km")
                unitCard(.mi, caption: "settings.general.unit.mi")
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }

    @ViewBuilder
    private func unitCard(_ value: DistanceUnit, caption: LocalizedStringKey) -> some View {
        let isOn = unitRaw == value.rawValue
        Button {
            withAnimation(.spring(response: 0.3)) { unitRaw = value.rawValue }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // top row: glyph + accent dot
                HStack {
                    Text("0\(value == .km ? "1" : "2")")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(isOn ? RunBarColor.cream.opacity(0.7) : RunBarColor.mutedInk(dark: false))
                    Spacer()
                    Circle()
                        .fill(isOn ? RunBarColor.terra : Color.clear)
                        .frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
                Text(value == .km ? "10" : "6.2")
                    .font(.system(size: 56, weight: .medium, design: .monospaced))
                    .tracking(-2)
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                Text(caption, bundle: .runBarResources)
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(isOn ? RunBarColor.cream.opacity(0.85) : RunBarColor.mutedInk(dark: false))
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOn ? RunBarColor.slate : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isOn ? RunBarColor.slate : RunBarColor.faintInk(dark: false), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isOn ? 0.18 : 0), radius: isOn ? 16 : 0, y: isOn ? 8 : 0)
            .scaleEffect(isOn ? 1.02 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Step 2 — Metric

private struct MetricStep: View {
    @Binding var selected: GoalMetric
    let unit: DistanceUnit
    let stepIndex: Int
    let total: Int

    var body: some View {
        VStack(spacing: 22) {
            stepHeader(
                stepIndex: stepIndex,
                total: total,
                kicker: "onboarding.metrics.title",
                italicWord: "What counts?",
                subtitleKey: "onboarding.metrics.subtitle"
            )

            HStack(spacing: 12) {
                metricCard(.distance,  num: "01", icon: "ruler",      title: "settings.tab.goals", example: distanceExample)
                metricCard(.count,     num: "02", icon: "calendar",   title: "popover.outings",    example: "4 / wk")
                metricCard(.elevation, num: "03", icon: "mountain.2", title: "settings.display.trail_mode", example: "1000 m+ / wk")
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    private var distanceExample: String {
        let value = Int(unit.valueFromKilometers(60).rounded())
        return "\(value) \(unit.symbol) / wk"
    }

    @ViewBuilder
    private func metricCard(_ value: GoalMetric, num: String, icon: String, title: LocalizedStringKey, example: String) -> some View {
        let isOn = selected == value
        Button { withAnimation(.spring(response: 0.3)) { selected = value } } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(num)
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(isOn ? RunBarColor.cream.opacity(0.7) : RunBarColor.mutedInk(dark: false))
                    Spacer()
                    Circle()
                        .fill(isOn ? RunBarColor.terra : Color.clear)
                        .frame(width: 6, height: 6)
                }
                Spacer(minLength: 6)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title, bundle: .runBarResources)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isOn ? RunBarColor.cream : RunBarColor.slate)
                    Text(example)
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(isOn ? RunBarColor.cream.opacity(0.7) : RunBarColor.mutedInk(dark: false))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOn ? RunBarColor.slate : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isOn ? RunBarColor.slate : RunBarColor.faintInk(dark: false), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isOn ? 0.18 : 0), radius: isOn ? 16 : 0, y: isOn ? 8 : 0)
            .scaleEffect(isOn ? 1.02 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Step 3 — Goal value

private struct GoalStep: View {
    let metric: GoalMetric
    let unit: DistanceUnit
    @Binding var targetKm: Double
    @Binding var targetCount: Double
    @Binding var targetElev: Double
    let suggestionSeeded: Bool
    let suggestionAvgKm: Double?
    let stepIndex: Int
    let total: Int

    private var tier: RunnerTier {
        switch metric {
        case .distance:  return RunnerTier.tier(forKm: targetKm)
        case .count:     return RunnerTier.tier(forKm: targetCount * 8)
        case .elevation: return RunnerTier.tier(forKm: targetElev / 20)
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                stepIndex: stepIndex,
                total: total,
                kicker: "onboarding.goal.title",
                italicWord: "Set the line.",
                subtitleKey: "onboarding.goal.subtitle"
            )

            if suggestionSeeded, let avg = suggestionAvgKm {
                suggestionBanner(avg: avg)
                    .padding(.horizontal, 48)
            }

            // big numeric display
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatted)
                    .font(.system(size: 78, weight: .medium, design: .monospaced))
                    .tracking(-2)
                    .foregroundStyle(RunBarColor.slate)
                    .contentTransition(.numericText())
                Text(unitLabel)
                    .font(.system(size: 14, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
            }
            .padding(.top, 2)

            sliderForCurrent
                .padding(.horizontal, 56)

            tierBadge
                .padding(.horizontal, 48)
                .padding(.top, 2)

            Spacer()
        }
    }

    @ViewBuilder
    private func suggestionBanner(avg: Double) -> some View {
        let displayAvg = Int(unit.valueFromKilometers(avg).rounded())
        let displayTarget = Int(unit.valueFromKilometers(targetKm).rounded())
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RunBarColor.terra)
            VStack(alignment: .leading, spacing: 2) {
                Text("Based on your last 4 weeks")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                Text("Avg \(displayAvg) \(unit.symbol)/wk · suggesting \(displayTarget) \(unit.symbol). Slide to override.")
                    .font(.system(size: 12))
                    .foregroundStyle(RunBarColor.slate)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RunBarColor.terra.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(RunBarColor.terra.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var sliderForCurrent: some View {
        switch metric {
        case .distance:
            let displayValue = unit.valueFromKilometers(targetKm)
            let displayMin = unit.valueFromKilometers(10)
            let displayMax = unit.valueFromKilometers(150)
            Slider(value: Binding(
                get: { displayValue },
                set: { targetKm = unit.toKilometers($0) }
            ), in: displayMin...displayMax, step: unit == .km ? 5 : 1)
                .tint(RunBarColor.terra)
        case .count:
            Slider(value: $targetCount, in: 1...10, step: 1)
                .tint(RunBarColor.terra)
        case .elevation:
            Slider(value: $targetElev, in: 100...3000, step: 100)
                .tint(RunBarColor.terra)
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
        case .count:     return "/ week"
        case .elevation: return "m+"
        }
    }

    private var tierBadge: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tier.color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(tier.color.opacity(0.4), lineWidth: 1)
                    )
                Image(systemName: tier.symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(tier.color)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Tier")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(RunBarColor.mutedInk(dark: false))
                    Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(width: 16, height: 1)
                }
                Text(tier.labelKey, bundle: .runBarResources)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(RunBarColor.slate)
                Text(tier.blurb(unit: unit))
                    .font(.system(size: 12))
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                    .frame(maxWidth: 320, alignment: .leading)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(RunBarColor.faintInk(dark: false), lineWidth: 1)
        )
        .animation(.spring(response: 0.4), value: tier)
    }
}

// MARK: - Step 4 — Connect (Bring-Your-Own Strava app)
//
// Pourquoi BYO par défaut : l'app partagée RunBar est en "Single Player Mode"
// (1 athlète max) tant que Strava n'a pas validé l'augmentation de quota. Tout
// nouvel utilisateur qui clique sur le bouton standard "Connect with Strava"
// se prendrait un 403. On guide donc directement vers la création d'une app
// perso (gratuit, 2 minutes), et le bouton "Save & Connect" enchaîne sur le
// vrai OAuth flow avec ses propres credentials.

private struct ConnectStep: View {
    @ObservedObject var coordinator: SettingsCoordinator
    let stepIndex: Int
    let total: Int

    @State private var clientID: String = StravaUserCredentialsStore.clientID
    @State private var clientSecret: String = StravaUserCredentialsStore.clientSecret
    @State private var saving: Bool = false

    private var canSaveAndConnect: Bool {
        !saving
            && !clientID.trimmingCharacters(in: .whitespaces).isEmpty
            && !clientSecret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 14) {
            stepHeader(
                stepIndex: stepIndex,
                total: total,
                kicker: "onboarding.connect.title",
                italicWord: "Connect Strava.",
                subtitleKey: "onboarding.connect.byo.subtitle"
            )

            ScrollView(.vertical, showsIndicators: false) {
                if coordinator.stravaConnected {
                    successCard
                } else {
                    setupCard
                }
            }
            .frame(maxWidth: 480)
        }
    }

    private var successCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            stravaHeaderRow(connected: true)
            Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(height: 1)
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RunBarColor.moss)
                Text("settings.sources.connected", bundle: .runBarResources)
                    .font(.system(size: 13))
                    .foregroundStyle(RunBarColor.slate)
                Spacer()
                Text(coordinator.stravaUsesUserAccount
                     ? LocalizedStringKey("onboarding.connect.byo.success_own")
                     : LocalizedStringKey("onboarding.connect.byo.success_shared"),
                     bundle: .runBarResources)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            stravaHeaderRow(connected: false)

            Text("onboarding.connect.byo.intro", bundle: .runBarResources)
                .font(.system(size: 12))
                .foregroundStyle(RunBarColor.slate)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                stepLine(num: "1", textKey: "onboarding.connect.byo.step1")
                stepLine(num: "2", textKey: "onboarding.connect.byo.step2")
                stepLine(num: "3", textKey: "onboarding.connect.byo.step3")
                stepLine(num: "4", textKey: "onboarding.connect.byo.step4")
            }

            Button {
                NSWorkspace.shared.open(URL(string: "https://www.strava.com/settings/api")!)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11))
                    Text("onboarding.connect.byo.open_strava", bundle: .runBarResources)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().stroke(RunBarColor.faintInk(dark: false), lineWidth: 1))
                .foregroundStyle(RunBarColor.slate)
            }
            .buttonStyle(PressableButtonStyle())

            Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(height: 1).padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.connect.byo.client_id", bundle: .runBarResources)
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                TextField("", text: $clientID, prompt: Text("123456"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))

                Text("onboarding.connect.byo.client_secret", bundle: .runBarResources)
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                    .padding(.top, 2)
                SecureField("", text: $clientSecret, prompt: Text("a1b2c3…"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            HStack {
                Spacer()
                Button(action: saveAndConnect) {
                    HStack(spacing: 8) {
                        if saving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("onboarding.connect.byo.save_and_connect", bundle: .runBarResources)
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(canSaveAndConnect ? RunBarColor.terra : RunBarColor.terra.opacity(0.45)))
                    .foregroundStyle(Color.white)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canSaveAndConnect)
            }
            .padding(.top, 4)

            if let err = coordinator.stravaError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(RunBarColor.terra)
            }

            Text("onboarding.connect.byo.later_hint", bundle: .runBarResources)
                .font(.system(size: 11))
                .foregroundStyle(RunBarColor.mutedInk(dark: false))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(cardBackground)
        .overlay(cardBorder)
    }

    private func stravaHeaderRow(connected: Bool) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: "https://d3nn82uaxijpm6.cloudfront.net/icon-strava-chrome-192.png")) { img in
                img.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 5).fill(.quaternary)
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            Text("Strava")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RunBarColor.slate)

            Spacer()

            Text(connected ? "connected" : "needs your api app")
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(connected ? RunBarColor.moss : RunBarColor.mutedInk(dark: false))
        }
    }

    private func stepLine(num: String, textKey: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(RunBarColor.terra)
                .frame(width: 14, alignment: .leading)
            Text(textKey, bundle: .runBarResources)
                .font(.system(size: 12))
                .foregroundStyle(RunBarColor.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.55))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(RunBarColor.faintInk(dark: false), lineWidth: 1)
    }

    private func saveAndConnect() {
        Task {
            saving = true
            await coordinator.saveUserStravaCredentials(
                clientID: clientID,
                clientSecret: clientSecret
            )
            if coordinator.stravaError == nil {
                await coordinator.connectStrava()
                // Once OAuth succeeds, fetch four weeks of running history
                // and persist the weekly aggregates. This bypasses the
                // rolling 7-day cache for the goal-seeding step (and for
                // the 8-week sparkline) while keeping us within § 7.1:
                // the raw fetch lives only in memory, only derived
                // aggregates ever hit disk.
                if coordinator.stravaConnected {
                    await coordinator.seedHistoricalSnapshots(daysBack: 56)
                }
            }
            saving = false
        }
    }
}

// MARK: - Step 5 — Upcoming race (optional)

private struct RaceStep: View {
    let unit: DistanceUnit
    @Binding var enabled: Bool
    @Binding var name: String
    @Binding var date: Date
    let stepIndex: Int
    let total: Int

    private var daysAway: Int {
        let cal = Calendar.iso8601Monday
        let today = cal.startOfDay(for: .now)
        let race = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: today, to: race).day ?? 0
    }

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                stepIndex: stepIndex,
                total: total,
                kicker: "onboarding.race.title",
                italicWord: "Race.",
                subtitleKey: "onboarding.race.subtitle"
            )

            VStack(alignment: .leading, spacing: 16) {
                // toggle row
                HStack {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(enabled ? RunBarColor.terra : RunBarColor.mutedInk(dark: false))
                    Text("onboarding.race.enable", bundle: .runBarResources)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RunBarColor.slate)
                    Spacer()
                    Toggle("", isOn: $enabled.animation(.spring(response: 0.3)))
                        .labelsHidden()
                        .tint(RunBarColor.terra)
                }

                if enabled {
                    Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(height: 1)

                    // race name
                    HStack(spacing: 14) {
                        Text("Name")
                            .font(.system(size: 10, design: .monospaced))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                            .frame(width: 64, alignment: .leading)
                        TextField("", text: $name, prompt: Text("London Marathon · Boston · …"))
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .serif))
                            .italic()
                            .foregroundStyle(RunBarColor.slate)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RunBarColor.faintInk(dark: false), lineWidth: 1)
                    )

                    // date
                    HStack(spacing: 14) {
                        Text("Date")
                            .font(.system(size: 10, design: .monospaced))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                            .frame(width: 64, alignment: .leading)
                        DatePicker("", selection: $date, in: Date.now..., displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                    }

                    // countdown summary
                    HStack(spacing: 10) {
                        Text("\(daysAway)")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundStyle(RunBarColor.terra)
                        Text(daysAway == 1 ? "day to go" : "days to go")
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                        Spacer()
                        if daysAway > 30 {
                            Text("subtle banner · vivid at ≤ 30")
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(RunBarColor.mutedInk(dark: false).opacity(0.7))
                        } else {
                            Text("vivid banner active")
                                .font(.system(size: 9, design: .monospaced))
                                .tracking(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(RunBarColor.moss)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(RunBarColor.faintInk(dark: false), lineWidth: 1)
            )

            Spacer()
        }
    }
}

// MARK: - Step 6 — Coach (optional)

private struct CoachStep: View {
    @Binding var keyDraft: String
    let errorMessage: String?
    let providerName: String
    let apiKeyURL: URL
    let stepIndex: Int
    let total: Int

    @State private var masked: Bool = true

    var body: some View {
        VStack(spacing: 18) {
            stepHeader(
                stepIndex: stepIndex,
                total: total,
                kicker: "onboarding.coach.title",
                italicWord: "AI coach.",
                subtitleKey: "onboarding.coach.subtitle"
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("onboarding.coach.provider_label", bundle: .runBarResources)
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                Text(providerName)
                    .font(.system(size: 14, weight: .medium, design: .serif).italic())
                    .foregroundStyle(RunBarColor.slate)

                Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(height: 1)

                HStack(spacing: 8) {
                    Group {
                        if masked {
                            SecureField("", text: $keyDraft, prompt: Text("AI…"))
                        } else {
                            TextField("", text: $keyDraft, prompt: Text("AI…"))
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RunBarColor.faintInk(dark: false), lineWidth: 1)
                    )
                    Button(action: { masked.toggle() }) {
                        Image(systemName: masked ? "eye" : "eye.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(RunBarColor.mutedInk(dark: false))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(RunBarColor.terra)
                }

                Link(destination: apiKeyURL) {
                    Text("onboarding.coach.get_key", bundle: .runBarResources)
                        .font(.system(size: 11))
                        .underline()
                }

                Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(height: 1)

                Text("onboarding.coach.privacy", bundle: .runBarResources)
                    .font(.system(size: 11))
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 460)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(RunBarColor.faintInk(dark: false), lineWidth: 1)
            )

            Spacer()
        }
    }
}

// MARK: - Step 7 — Done

private struct DoneStep: View {
    let metric: GoalMetric
    let unit: DistanceUnit
    let targetKm: Double
    let targetCount: Double
    let targetElev: Double

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Editorial running scene — hairline track with 5 ticks,
            // runner planted on the rule, finish flag at the right edge.
            runnerScene
                .frame(width: 380, height: 64)

            VStack(spacing: 14) {
                // editorial title
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Done")
                        .font(.system(size: 44, weight: .medium, design: .serif))
                        .italic()
                        .tracking(-1.5)
                        .foregroundStyle(RunBarColor.slate)
                    Text(".")
                        .font(.system(size: 44, weight: .medium, design: .serif))
                        .foregroundStyle(RunBarColor.terra)
                }

                Text(summary)
                    .font(.system(size: 13, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.slate)

                Text("onboarding.done.subtitle", bundle: .runBarResources)
                    .font(.system(size: 13))
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Spacer()

            // Colophon — éditorial, mono small-caps.
            HStack(spacing: 10) {
                Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(width: 28, height: 0.6)
                Text(colophonText)
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: false))
                Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(width: 28, height: 0.6)
            }
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var runnerScene: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let runnerSize: CGFloat = 28
            let trackY = geo.size.height - 18

            ZStack(alignment: .topLeading) {
                // 5 ticks
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        Rectangle()
                            .fill(RunBarColor.faintInk(dark: false))
                            .frame(width: 0.8, height: 8)
                        if i < 4 { Spacer(minLength: 0) }
                    }
                }
                .frame(width: width)
                .offset(y: trackY - 4)

                // Hairline rule
                Rectangle()
                    .fill(RunBarColor.faintInk(dark: false))
                    .frame(width: width, height: 0.8)
                    .offset(y: trackY)

                // Vermillon progress hairline (full width — week complete)
                Rectangle()
                    .fill(RunBarColor.terra)
                    .frame(width: width - 12, height: 1.2)
                    .offset(y: trackY)

                // Runner planted near the finish
                RunnerView(state: .victory, color: RunBarColor.slate, animated: true)
                    .frame(width: runnerSize, height: runnerSize)
                    .offset(x: width - runnerSize - 18, y: trackY - runnerSize + 2)

                // Finish flag at far right
                FinishFlagView(size: 18, dark: false, waving: true)
                    .frame(width: 18, height: 18)
                    .offset(x: width - 18, y: trackY - 22)
            }
        }
    }

    private var colophonText: String {
        let week = Calendar.iso8601Monday.component(.weekOfYear, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        return "RUNBAR · WK \(week) / \(year) · READY"
    }

    private var summary: String {
        switch metric {
        case .distance:
            let value = DistanceFormatter.number(unit.valueFromKilometers(targetKm), fractionDigits: 0)
            let key = unit == .km ? "onboarding.goal.summary_km" : "onboarding.goal.summary_mi"
            return String(format: String(localized: String.LocalizationValue(key), bundle: .runBarResources), value)
        case .count:
            return String(format: String(localized: "onboarding.goal.summary_count", bundle: .runBarResources), Int(targetCount))
        case .elevation:
            return String(format: String(localized: "onboarding.goal.summary_elevation", bundle: .runBarResources), Int(targetElev))
        }
    }
}

// MARK: - Helpers

@ViewBuilder
private func stepHeader(
    stepIndex: Int,
    total: Int,
    kicker: LocalizedStringKey,
    italicWord: String,
    subtitleKey: LocalizedStringKey
) -> some View {
    VStack(alignment: .center, spacing: 10) {
        // eyebrow
        HStack(spacing: 12) {
            Text(String(format: "Step %02d / %02d", stepIndex + 1, total))
                .font(.system(size: 10, design: .monospaced))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(RunBarColor.mutedInk(dark: false))
            Rectangle().fill(RunBarColor.faintInk(dark: false)).frame(width: 18, height: 1)
            Text(kicker, bundle: .runBarResources)
                .font(.system(size: 10, design: .monospaced))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(RunBarColor.slate)
        }

        // italic display word + subtitle
        VStack(spacing: 4) {
            Text(italicWord)
                .font(.system(size: 36, weight: .medium, design: .serif))
                .italic()
                .tracking(-1.2)
                .foregroundStyle(RunBarColor.slate)
            Text(subtitleKey, bundle: .runBarResources)
                .font(.system(size: 13))
                .foregroundStyle(RunBarColor.mutedInk(dark: false))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }

        Rectangle()
            .fill(RunBarColor.faintInk(dark: false))
            .frame(width: 80, height: 1)
            .padding(.top, 6)
    }
    .padding(.top, 14)
    .padding(.horizontal, 36)
}

private extension String {
    var asLocalizedKey: LocalizedStringKey { LocalizedStringKey(self) }
}
