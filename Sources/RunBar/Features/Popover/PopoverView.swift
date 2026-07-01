import SwiftUI

/// Popover principal du menu bar — 320×460 (refonte éditoriale).
/// Direction Pristine Light Mode — ivory + ink + vermillon, hairlines, italiques
/// serif, mono small-caps. Aligné sur le site et l'onboarding.
public struct PopoverView: View {
    @ObservedObject var viewModel: PopoverViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @AppStorage("runbar.onboardingDone") private var onboardingDone: Bool = false
    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    @State private var didTriggerOnboarding = false

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .km }

    public init(viewModel: PopoverViewModel) {
        self.viewModel = viewModel
    }

    private var isDark: Bool { colorScheme == .dark }

    public var body: some View {
        let mode = viewModel.mode
        let runs = viewModel.activitiesThisWeek
        let goal = viewModel.goal
        let value = viewModel.currentValue
        let pct = viewModel.progress
        let pctLabel = Int(round(pct * 100))
        let runner = viewModel.runnerState
        let accent = RunBarColor.accent(for: runner)

        VStack(spacing: 0) {
            header()
            if viewModel.isViewingCurrentWeek {
                onboardingResumeBanner
                statusBanner
                suggestionBanner
                coachBanner
                if let days = goal.daysUntilRace(), days >= 0 {
                    raceCountdownBanner(
                        days: days,
                        name: goal.raceName ?? String(localized: "settings.goals.race_section", bundle: .runBarResources),
                        accent: accent
                    )
                }
                statsBlock(value: value, goal: goal, pctLabel: pctLabel, mode: mode, accent: accent)
                progressRibbon(pct: pct, mode: mode, accent: accent)
                historyBlock(accent: accent)
                divider
                sortiesList(runs: runs, mode: mode, accent: accent)
            } else {
                // Semaine passée : agrégats dérivés uniquement — les activités
                // détaillées sont purgées après 7 jours (Strava § 7.1).
                pastWeekBlock
                historyBlock(accent: accent)
                divider
                pastWeekArchiveNote
            }
            footer(accent: accent)
        }
        .frame(width: 320)
        .frame(minHeight: 460)
        .fixedSize(horizontal: false, vertical: true)
        .background(RunBarColor.surface(dark: isDark))
        .foregroundStyle(RunBarColor.ink(dark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(isDark ? 0.45 : 0.10), radius: 24, x: 0, y: 12)
        .onAppear {
            guard !onboardingDone, !didTriggerOnboarding else { return }
            didTriggerOnboarding = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                openWindow(id: "onboarding")
            }
        }
    }

    // MARK: Header (eyebrow + italic-serif "This week.")

    @ViewBuilder
    private func header() -> some View {
        let viewingCurrent = viewModel.isViewingCurrentWeek
        let refDate = viewingCurrent ? Date() : viewModel.displayedWeekStart
        let weekNumber = refDate.isoWeekOfYear()
        let year = Calendar.iso8601Monday.component(.yearForWeekOfYear, from: refDate)
        let dateLabel = DateFormatter.editorialMonthDay.string(from: refDate).uppercased()

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dateLabel) — \(String(year)) · WK \(weekNumber)")
                        .eyebrowStyle(dark: isDark)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(viewingCurrent ? "This" : "That")
                            .font(.system(size: 22, weight: .regular, design: .serif).italic())
                            .foregroundStyle(RunBarColor.ink(dark: isDark))
                        Text("week.")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(RunBarColor.ink(dark: isDark))
                        if viewingCurrent, viewModel.currentStreak >= 2 {
                            StreakBadge(count: viewModel.currentStreak, dark: isDark)
                                .padding(.leading, 4)
                        }
                        if !viewingCurrent {
                            Button(action: { viewModel.returnToCurrentWeek() }) {
                                Text("NOW")
                                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                    .tracking(0.8)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .overlay(
                                        Capsule().strokeBorder(RunBarColor.vermillon.opacity(0.45), lineWidth: 0.7)
                                    )
                                    .foregroundStyle(RunBarColor.vermillon)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 4)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    if viewModel.canGoToPreviousWeek || !viewingCurrent {
                        headerIcon(
                            systemName: "chevron.left",
                            disabled: !viewModel.canGoToPreviousWeek,
                            action: { viewModel.goToPreviousWeek() }
                        )
                        headerIcon(
                            systemName: "chevron.right",
                            disabled: !viewModel.canGoToNextWeek,
                            action: { viewModel.goToNextWeek() }
                        )
                    }
                    headerIcon(systemName: "gearshape", action: {
                        viewModel.openSettings()
                        openSettings()
                    })
                    headerIcon(systemName: "xmark", action: { viewModel.close() })
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RunBarColor.hairline(dark: isDark))
                .frame(height: 0.6)
        }
    }

    @ViewBuilder
    private func headerIcon(systemName: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                .opacity(disabled ? 0.35 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: Status banner

    @ViewBuilder
    private var onboardingResumeBanner: some View {
        if !onboardingDone {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "onboarding")
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("popover.onboarding.resume_title", bundle: .runBarResources)
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("popover.onboarding.resume_detail", bundle: .runBarResources)
                            .font(.system(size: 10.5))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .foregroundStyle(RunBarColor.ink(dark: isDark))
                .background(RunBarColor.moss.opacity(isDark ? 0.18 : 0.10))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(RunBarColor.hairline(dark: isDark)).frame(height: 0.6)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        let kind = viewModel.statusKind
        if kind != .ready {
            HStack(spacing: 9) {
                Image(systemName: statusIcon(kind))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor(kind))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.statusTitle)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(RunBarColor.ink(dark: isDark))
                    Text(viewModel.statusDetail)
                        .font(.system(size: 10.5))
                        .lineLimit(1)
                        .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                }
                Spacer(minLength: 8)
                if kind == .needsConnection {
                    StravaConnectButton(size: .compact, action: { viewModel.connectStrava() })
                } else if kind == .error || kind == .noActivities {
                    Button(action: { viewModel.syncNow() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(RunBarColor.faintInk(dark: isDark)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RunBarColor.ink(dark: isDark))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(statusColor(kind).opacity(isDark ? 0.16 : 0.08))
            .overlay(alignment: .bottom) {
                Rectangle().fill(RunBarColor.hairline(dark: isDark)).frame(height: 0.6)
            }
        }
    }

    private func statusIcon(_ kind: PopoverStatusKind) -> String {
        switch kind {
        case .needsConnection: return "link.badge.plus"
        case .error: return "exclamationmark.triangle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .waitingForSync: return "clock"
        case .noActivities: return "magnifyingglass"
        case .ready: return "checkmark.circle.fill"
        }
    }

    private func statusColor(_ kind: PopoverStatusKind) -> Color {
        switch kind {
        case .needsConnection, .waitingForSync, .noActivities: return RunBarColor.gold
        case .error: return RunBarColor.vermillonDeep
        case .syncing, .ready: return RunBarColor.vermillon
        }
    }

    // MARK: Suggestion banner

    @ViewBuilder
    private var suggestionBanner: some View {
        if let s = viewModel.pendingSuggestion {
            let isIncrease = s.direction == .increase
            let icon = isIncrease ? "arrow.up.right" : "arrow.down.right"
            let tone = isIncrease ? RunBarColor.mossDeep : RunBarColor.gold
            let displayCurrent = unit.valueFromKilometers(s.currentTarget)
            let displaySuggested = unit.valueFromKilometers(s.suggestedTarget)
            let displayAvg = unit.valueFromKilometers(s.baselineAvgKm)
            let titleKey: LocalizedStringKey = isIncrease
                ? "popover.suggestion.title_up"
                : "popover.suggestion.title_down"
            let detailTemplate = String(
                localized: "popover.suggestion.detail",
                bundle: .runBarResources
            )
            let detail = String(
                format: detailTemplate,
                DistanceFormatter.number(displayAvg),
                unit.symbol,
                Int(displayCurrent.rounded()),
                Int(displaySuggested.rounded()),
                unit.symbol
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tone)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(titleKey, bundle: .runBarResources)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(RunBarColor.ink(dark: isDark))
                        Text(detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                }
                HStack(spacing: 6) {
                    Spacer()
                    Button(action: { viewModel.dismissSuggestion() }) {
                        Text("popover.suggestion.later", bundle: .runBarResources)
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.openSettings()
                        openSettings()
                    }) {
                        Text("popover.suggestion.edit", bundle: .runBarResources)
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().stroke(RunBarColor.hairline(dark: isDark), lineWidth: 0.8)
                            )
                            .foregroundStyle(RunBarColor.ink(dark: isDark))
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.acceptSuggestion() }) {
                        Text("popover.suggestion.accept", bundle: .runBarResources)
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(tone))
                            .foregroundStyle(RunBarColor.ivory)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(tone.opacity(isDark ? 0.16 : 0.07))
            .overlay(alignment: .bottom) {
                Rectangle().fill(RunBarColor.hairline(dark: isDark)).frame(height: 0.6)
            }
        }
    }

    // MARK: Coach banner

    @ViewBuilder
    private var coachBanner: some View {
        if let m = viewModel.coachMessage {
            VStack(alignment: .leading, spacing: 6) {
                Text(m.text)
                    .font(.system(size: 12, weight: .regular, design: .serif).italic())
                    .foregroundStyle(RunBarColor.ink(dark: isDark))
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("popover.coach.byline", bundle: .runBarResources)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                    Text("·")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                    Text(m.providerLabel)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                    Spacer()
                    Button(action: { viewModel.refreshCoach() }) {
                        Image(systemName: viewModel.coachIsFetching
                              ? "arrow.triangle.2.circlepath"
                              : "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.coachIsFetching)
                    Button(action: { viewModel.dismissCoach() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RunBarColor.faintInk(dark: isDark).opacity(0.5))
            .overlay(alignment: .bottom) {
                Rectangle().fill(RunBarColor.hairline(dark: isDark)).frame(height: 0.6)
            }
        }
    }

    // MARK: Race countdown

    @ViewBuilder
    private func raceCountdownBanner(days: Int, name: String, accent: Color) -> some View {
        let imminent = days <= 30
        let tone = imminent ? RunBarColor.vermillon : RunBarColor.mutedInk(dark: isDark)
        let template = String(localized: "popover.race_in_n_days", bundle: .runBarResources)

        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tone)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .regular, design: .serif).italic())
                    .foregroundStyle(RunBarColor.ink(dark: isDark))
                    .lineLimit(1)
                Text(String(format: template, days))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
            }
            Spacer()
            Text("D\(days == 0 ? "" : "-\(days)")")
                .font(.system(size: imminent ? 22 : 18, weight: .bold).monospacedDigit())
                .tracking(-0.5)
                .foregroundStyle(tone)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Group {
                if imminent {
                    LinearGradient(
                        colors: [RunBarColor.vermillon.opacity(0.10), RunBarColor.vermillon.opacity(0.02)],
                        startPoint: .leading, endPoint: .trailing
                    )
                } else {
                    RunBarColor.faintInk(dark: isDark).opacity(0.5)
                }
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(RunBarColor.hairline(dark: isDark)).frame(height: 0.6)
        }
    }

    // MARK: Stats block (big number + italic-serif target + subtle %)

    @ViewBuilder
    private func statsBlock(value: Double, goal: WeeklyGoal, pctLabel: Int,
                            mode: PopoverMode, accent: Color) -> some View {
        let displayValue = unit.valueFromKilometers(value)
        let displayTarget = unit.valueFromKilometers(goal.target)
        let remainingKm = max(0, goal.target - value)
        let displayRemaining = unit.valueFromKilometers(remainingKm)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(DistanceFormatter.number(displayValue))
                    .font(.system(size: 36, weight: .semibold).monospacedDigit())
                    .tracking(-1.2)
                    .foregroundStyle(RunBarColor.ink(dark: isDark))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("of")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                    targetEditMenu(displayTarget: displayTarget, goal: goal)
                }
                .padding(.leading, 8)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(pctLabel)%")
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .tracking(-0.4)
                        .foregroundStyle(mode == .victory ? RunBarColor.vermillonDeep : RunBarColor.inkSoft(dark: isDark))
                    // State label — explique l'animation du runner aux nouveaux
                    // utilisateurs ("Warming up", "Sprinting", etc.).
                    Text(viewModel.runnerState.label)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(accent)
                }
            }

            // Dataline mono — éditorial.
            Text(dataline(value: displayValue, remaining: displayRemaining,
                          mode: mode, goal: goal, daysLeft: daysLeftInWeek()))
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Bouton-menu autour du target affiché. Pour `.distance`, propose des
    /// deltas rapides (±2, ±5) plus un raccourci vers Settings. Pour les autres
    /// métriques on ouvre directement Settings (les raccourcis n'ont pas
    /// d'unité commune).
    @ViewBuilder
    private func targetEditMenu(displayTarget: Double, goal: WeeklyGoal) -> some View {
        let label = Text("\(Int(displayTarget.rounded())) \(unit.symbol)")
            .font(.system(size: 14).monospacedDigit())
            .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
            .underline(true, pattern: .dot, color: RunBarColor.hairline(dark: isDark))
        if goal.metric == .distance {
            Menu {
                Button(action: { bumpTargetKm(-5) }) {
                    Text("popover.target.minus_5", bundle: .runBarResources)
                }
                Button(action: { bumpTargetKm(-2) }) {
                    Text("popover.target.minus_2", bundle: .runBarResources)
                }
                Button(action: { bumpTargetKm(2) }) {
                    Text("popover.target.plus_2", bundle: .runBarResources)
                }
                Button(action: { bumpTargetKm(5) }) {
                    Text("popover.target.plus_5", bundle: .runBarResources)
                }
                Divider()
                Button(action: {
                    viewModel.openSettings()
                    openSettings()
                }) {
                    Text("popover.target.edit_in_settings", bundle: .runBarResources)
                }
            } label: {
                label
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            Button(action: {
                viewModel.openSettings()
                openSettings()
            }) {
                label
            }
            .buttonStyle(.plain)
        }
    }

    /// Applique un delta km au target courant via le ViewModel (clamp 5...300).
    private func bumpTargetKm(_ deltaKm: Double) {
        viewModel.setGoalTargetKm(viewModel.goal.target + deltaKm)
    }

    private func dataline(value: Double, remaining: Double, mode: PopoverMode,
                          goal: WeeklyGoal, daysLeft: Int) -> String {
        let kicker: String
        switch mode {
        case .victory:
            kicker = String(localized: "week.status.complete", bundle: .runBarResources)
        case .empty:
            kicker = String(localized: "week.status.start", bundle: .runBarResources)
        case .normal:
            kicker = String(localized: "week.status.in_progress", bundle: .runBarResources)
        }
        let runText  = "\(DistanceFormatter.number(value)) \(unit.symbol) RUN"
        let leftText = "\(DistanceFormatter.number(remaining)) \(unit.symbol) TO GO"
        let daysText = daysLeft == 1 ? "1 DAY LEFT" : "\(daysLeft) DAYS LEFT"
        return "\(kicker) · \(runText) · \(leftText) · \(daysText)"
    }

    private func daysLeftInWeek() -> Int {
        let cal = Calendar.iso8601Monday
        let weekday = cal.component(.weekday, from: Date()) // 1=Sun..7=Sat
        let mondayWeekday = (weekday + 5) % 7 // 0=Mon..6=Sun
        return max(0, 6 - mondayWeekday)
    }

    // MARK: Progress ribbon — hairline + ticks + runner

    @ViewBuilder
    private func progressRibbon(pct: Double, mode: PopoverMode, accent: Color) -> some View {
        GeometryReader { geo in
            let progress = mode == .empty ? 0 : min(1, max(0, pct))
            let width = geo.size.width
            let runnerSize: CGFloat = 18
            let runnerX = max(0, min(width - runnerSize, width * progress - runnerSize / 2))

            ZStack(alignment: .leading) {
                // Hairline rule
                Rectangle()
                    .fill(RunBarColor.hairline(dark: isDark))
                    .frame(height: 0.8)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Ticks (5 graduations: 0/25/50/75/100)
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        Rectangle()
                            .fill(RunBarColor.hairline(dark: isDark))
                            .frame(width: 0.8, height: 6)
                        if i < 4 { Spacer(minLength: 0) }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)

                // Progress overlay (vermillon line up to runner)
                Rectangle()
                    .fill(RunBarColor.vermillon)
                    .frame(width: max(0, runnerX + runnerSize / 2), height: 1.2)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Runner planted on the rule
                RunnerView(state: viewModel.runnerState, color: RunBarColor.ink(dark: isDark), animated: true)
                    .frame(width: runnerSize, height: runnerSize)
                    .offset(x: runnerX, y: -1)

                // Finish flag at far right
                FinishFlagView(size: 16, dark: isDark, waving: mode == .victory)
                    .frame(width: 16, height: 16)
                    .offset(x: width - 14, y: -8)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: Past week (agrégats dérivés — les activités sont purgées à 7 jours)

    @ViewBuilder
    private var pastWeekBlock: some View {
        if let snap = viewModel.displayedSnapshot {
            let isDistance = snap.metric == .distance
            let displayValue = isDistance ? unit.valueFromKilometers(snap.achieved) : snap.achieved
            let displayTarget = isDistance ? unit.valueFromKilometers(snap.target) : snap.target
            let unitLabel = isDistance ? unit.symbol : snap.metric.unit
            let digits = isDistance ? 1 : 0
            let pct = Int((snap.progress * 100).rounded())
            let shortfall = max(0, displayTarget - displayValue)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(DistanceFormatter.number(displayValue, fractionDigits: digits))
                        .font(.system(size: 36, weight: .semibold).monospacedDigit())
                        .tracking(-1.2)
                        .foregroundStyle(RunBarColor.ink(dark: isDark))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("of")
                            .font(.system(size: 14, weight: .regular, design: .serif).italic())
                            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                        Text("\(Int(displayTarget.rounded())) \(unitLabel)")
                            .font(.system(size: 14).monospacedDigit())
                            .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
                    }
                    .padding(.leading, 8)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(pct)%")
                            .font(.system(size: 18, weight: .semibold).monospacedDigit())
                            .tracking(-0.4)
                            .foregroundStyle(snap.completed ? RunBarColor.vermillonDeep : RunBarColor.inkSoft(dark: isDark))
                        Text(snap.completed
                             ? String(localized: "popover.pastweek.reached", bundle: .runBarResources)
                             : String(localized: "popover.pastweek.short", bundle: .runBarResources))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(0.9)
                            .textCase(.uppercase)
                            .foregroundStyle(snap.completed ? RunBarColor.vermillon : RunBarColor.mutedInk(dark: isDark))
                    }
                }

                Text(pastWeekDataline(completed: snap.completed,
                                      shortfall: shortfall,
                                      digits: digits,
                                      unitLabel: unitLabel))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        } else {
            VStack(spacing: 6) {
                Text("Quiet.")
                    .font(.system(size: 22, weight: .regular, design: .serif).italic())
                    .foregroundStyle(RunBarColor.ink(dark: isDark))
                Text("popover.pastweek.no_data", bundle: .runBarResources)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private func pastWeekDataline(completed: Bool, shortfall: Double,
                                  digits: Int, unitLabel: String) -> String {
        let cal = Calendar.iso8601Monday
        let start = viewModel.displayedWeekStart
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let f = DateFormatter.editorialMonthDay
        let range = "\(f.string(from: start)) — \(f.string(from: end))".uppercased()
        if completed {
            let kicker = String(localized: "week.status.complete", bundle: .runBarResources)
            return "\(kicker) · \(range)"
        }
        let missing = "\(DistanceFormatter.number(shortfall, fractionDigits: digits)) \(unitLabel) SHORT"
        return "\(missing) · \(range)"
    }

    @ViewBuilder
    private var pastWeekArchiveNote: some View {
        VStack(spacing: 6) {
            Text("Archive.")
                .font(.system(size: 22, weight: .regular, design: .serif).italic())
                .foregroundStyle(RunBarColor.ink(dark: isDark))
            Text("popover.pastweek.note", bundle: .runBarResources)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: History block (8 weeks with Y-axis + goal line)

    @ViewBuilder
    private func historyBlock(accent: Color) -> some View {
        WeeklyHistoryStrip(
            snapshots: viewModel.recentSnapshots,
            goal: viewModel.goal,
            dark: isDark,
            selectedOffset: viewModel.weekOffset,
            onSelectWeek: { offset in
                viewModel.weekOffset = max(-52, min(0, offset))
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(RunBarColor.hairline(dark: isDark))
            .frame(height: 0.6)
    }

    // MARK: Outings list

    @ViewBuilder
    private func sortiesList(runs: [Activity], mode: PopoverMode, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                let countText = String(format: "%02d", runs.count)
                Text("RUNS — \(countText)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                Spacer()
                if !runs.isEmpty {
                    Text(viewModel.averagePaceLabel)
                        .monospacedDigit()
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
                }
            }
            .padding(.bottom, 8)

            if runs.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(runs.enumerated()), id: \.element.id) { idx, run in
                        ActivityRowView(
                            day: run.dayLabel(),
                            name: run.name,
                            distanceKm: run.distanceKm,
                            elevationGain: run.elevationGain,
                            timeLabel: viewModel.timeLabel(for: run),
                            dark: isDark,
                            highlight: mode == .victory && idx == runs.count - 1,
                            accent: RunBarColor.vermillon,
                            stravaURL: run.source == .strava
                                ? URL(string: "https://www.strava.com/activities/\(run.id)")
                                : nil
                        )
                        if idx < runs.count - 1 {
                            Rectangle()
                                .fill(RunBarColor.hairline(dark: isDark))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Waiting.")
                .font(.system(size: 22, weight: .regular, design: .serif).italic())
                .foregroundStyle(RunBarColor.ink(dark: isDark))

            Text(emptySubtitleKey, bundle: .runBarResources)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
                .frame(maxWidth: 260)

            if !viewModel.stravaConnected {
                StravaConnectButton(size: .compact, action: { viewModel.connectStrava() })
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var emptySubtitleKey: LocalizedStringKey {
        if !viewModel.stravaConnected {
            return LocalizedStringKey("popover.connect_strava_cta")
        }
        if viewModel.statusKind == .noActivities {
            return LocalizedStringKey("popover.no_strava_activities_subtitle")
        }
        return LocalizedStringKey("popover.no_outing_subtitle")
    }

    // MARK: Footer — colophon

    @ViewBuilder
    private func footer(accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.lastError != nil ? RunBarColor.vermillonDeep : RunBarColor.vermillon)
                .frame(width: 5, height: 5)
            Text(viewModel.lastSyncLabel.uppercased())
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .tracking(0.8)
                .lineLimit(1)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
            Text("·")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
            PoweredByStravaTag()
            Spacer()
            Button(action: { viewModel.syncNow() }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .medium))
                    Text("SYNC")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    Capsule().strokeBorder(RunBarColor.hairline(dark: isDark), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(RunBarColor.ink(dark: isDark))
            .disabled(viewModel.isSyncing)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RunBarColor.hairline(dark: isDark))
                .frame(height: 0.6)
        }
    }
}

// MARK: - WeeklyHistoryStrip (8 weeks, Y-axis, goal line, taller bars)

private struct WeeklyHistoryStrip: View {
    let snapshots: [WeeklySnapshot]
    let goal: WeeklyGoal
    let dark: Bool
    /// Décalage de la semaine affichée dans le popover (0 = courante) —
    /// la barre correspondante est surlignée.
    var selectedOffset: Int = 0
    /// Tap sur une barre → navigation vers cette semaine (offset ≤ 0).
    var onSelectWeek: ((Int) -> Void)? = nil

    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    @State private var hoveredIndex: Int? = nil

    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .km }

    private var ordered: [WeeklySnapshot] {
        Array(snapshots.sorted(by: { $0.weekStart < $1.weekStart }).suffix(8))
    }

    /// Échelle Y — top = max(goal, achievedMax) × 1.05, ceil au palier "nice".
    /// Multiplier serré (5%) pour rester collé au max + paliers fins jusqu'à
    /// 200 km : un goal de 95 km avec max 90 km donne 100 km au top, pas 125.
    private var maxValue: Double {
        let achievedMax = ordered.map(\.achieved).max() ?? 0
        let raw = Swift.max(goal.target, achievedMax) * 1.05
        return niceCeil(raw)
    }

    private func niceCeil(_ v: Double) -> Double {
        guard v > 0 else { return 10 }
        let step: Double
        switch v {
        case ..<25:    step = 5
        case ..<200:   step = 10
        case ..<500:   step = 25
        case ..<2000:  step = 50
        default:       step = 100
        }
        return (v / step).rounded(.up) * step
    }

    /// 4 graduations Y : 0, top/3, 2·top/3, top — alignées sur l'échelle.
    private var yLabels: [(value: Double, label: String)] {
        let top = maxValue
        let unitForLabel = goal.metric == .distance ? unit.symbol : goal.metric.unit
        let asInt = { (v: Double) -> String in
            let display = goal.metric == .distance ? unit.valueFromKilometers(v) : v
            return "\(Int(display.rounded())) \(unitForLabel)"
        }
        return [
            (top,         asInt(top)),
            (top * 2 / 3, asInt(top * 2 / 3)),
            (top / 3,     asInt(top / 3)),
            (0,           "0 \(unitForLabel)"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let snap = hoveredSnapshot {
                    Text(hoverDetail(snap))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .foregroundStyle(RunBarColor.ink(dark: dark))
                        .transition(.opacity)
                    Spacer()
                } else {
                    Text("EIGHT WEEKS")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                    Spacer()
                    Text(insight)
                        .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                }
            }
            .animation(.easeOut(duration: 0.12), value: hoveredIndex)

            // Chart frame
            chartFrame
                .frame(height: 88)

            // X-axis labels
            xAxis
        }
    }

    private var hoveredSnapshot: WeeklySnapshot? {
        guard let idx = hoveredIndex else { return nil }
        let slots = barSlots()
        guard idx < slots.count else { return nil }
        return slots[idx]
    }

    private func hoverDetail(_ snap: WeeklySnapshot) -> String {
        let cal = Calendar.iso8601Monday
        let week = cal.component(.weekOfYear, from: snap.weekStart)
        let weekEnd = cal.date(byAdding: .day, value: 6, to: snap.weekStart) ?? snap.weekStart
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        let range = "\(f.string(from: snap.weekStart)) — \(f.string(from: weekEnd))"

        let unitForLabel = goal.metric == .distance ? unit.symbol : goal.metric.unit
        let displayAchieved = goal.metric == .distance
            ? unit.valueFromKilometers(snap.achieved)
            : snap.achieved
        let valueText = "\(DistanceFormatter.number(displayAchieved)) \(unitForLabel)"
        let pct = Int((snap.progress * 100).rounded())
        return "W\(week) · \(range.uppercased()) · \(valueText) · \(pct)%"
    }

    @ViewBuilder
    private var chartFrame: some View {
        GeometryReader { geo in
            let yAxisWidth: CGFloat = 42
            let chartW = geo.size.width - yAxisWidth
            let chartH = geo.size.height
            let scale = maxValue
            let labelH: CGFloat = 10

            // Single ZStack so the Y-axis labels can be absolutely positioned
            // in the same coordinate system as the bars — guarantees they
            // line up with the goal line / baseline regardless of parent
            // layout pressure.
            ZStack(alignment: .topLeading) {
                // Bars area (left portion)
                ZStack(alignment: .bottomLeading) {
                    // Goal line — pointillé hairline
                    if scale > 0 {
                        let goalY = chartH * (1 - CGFloat(goal.target / scale))
                        DashedLine()
                            .stroke(RunBarColor.vermillon.opacity(0.55), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                            .frame(height: 0.8)
                            .offset(y: goalY)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    // Half-goal subtle hairline
                    if scale > 0 {
                        let halfY = chartH * (1 - CGFloat(goal.target * 0.5 / scale))
                        Rectangle()
                            .fill(RunBarColor.hairline(dark: dark).opacity(0.6))
                            .frame(height: 0.5)
                            .offset(y: halfY)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    // Baseline
                    Rectangle()
                        .fill(RunBarColor.hairline(dark: dark))
                        .frame(height: 0.8)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)

                    // Bars — each slot is a full-column hit area for hover + tap.
                    HStack(spacing: 0) {
                        ForEach(Array(barSlots().enumerated()), id: \.offset) { idx, snap in
                            let isSelected = (idx - 7) == selectedOffset
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(hoveredIndex == idx || isSelected
                                          ? RunBarColor.hairline(dark: dark).opacity(0.5)
                                          : Color.clear)
                                    .frame(maxHeight: .infinity)
                                barView(
                                    snap: snap,
                                    isCurrent: idx == 7,
                                    isHovered: hoveredIndex == idx || isSelected,
                                    scale: scale,
                                    height: chartH
                                )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                hoveredIndex = hovering ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
                            }
                            .onTapGesture { onSelectWeek?(idx - 7) }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: chartW, height: chartH)

                // Y-axis labels — absolutely positioned via .position so each
                // label center sits exactly at its tick's y coordinate.
                ForEach(yLabels, id: \.label) { tick in
                    let y = scale > 0 ? chartH * (1 - CGFloat(tick.value / scale)) : 0
                    let cy = Swift.min(chartH - labelH / 2, Swift.max(labelH / 2, y))
                    Text(tick.label)
                        .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                        .tracking(0.4)
                        .lineLimit(1)
                        .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                        .frame(width: yAxisWidth - 6, height: labelH, alignment: .trailing)
                        .position(
                            x: chartW + (yAxisWidth - 6) / 2 + 3,
                            y: cy
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func barView(snap: WeeklySnapshot?, isCurrent: Bool, isHovered: Bool, scale: Double, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let snap, scale > 0 {
                let h = height * CGFloat(min(1.0, snap.achieved / scale))
                let isComplete = snap.completed
                let baseFill: Color = {
                    if isCurrent {
                        return isComplete ? RunBarColor.vermillon : RunBarColor.vermillon.opacity(0.7)
                    }
                    return isComplete ? RunBarColor.inkSoft(dark: dark) : RunBarColor.mutedInk(dark: dark).opacity(0.55)
                }()
                let fill = isHovered ? RunBarColor.vermillon : baseFill
                Rectangle()
                    .fill(fill)
                    .frame(width: isHovered ? 6 : 5, height: Swift.max(2, h))
                    .animation(.easeOut(duration: 0.12), value: isHovered)
            } else {
                Rectangle()
                    .fill(RunBarColor.hairline(dark: dark))
                    .frame(width: 5, height: 2)
            }
        }
    }

    @ViewBuilder
    private var xAxis: some View {
        let yAxisWidth: CGFloat = 36
        HStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(barSlots().enumerated()), id: \.offset) { idx, snap in
                    let weekText = snap.map { shortWeek($0.weekStart) } ?? ""
                    let isCurrent = idx == 7
                    Text(weekText)
                        .font(.system(size: 8.5,
                                      weight: isCurrent ? .semibold : .regular,
                                      design: isCurrent ? .serif : .monospaced))
                        .italic(isCurrent)
                        .tracking(isCurrent ? 0 : 0.4)
                        .foregroundStyle(isCurrent ? RunBarColor.ink(dark: dark) : RunBarColor.mutedInk(dark: dark))
                        .frame(maxWidth: .infinity)
                }
            }
            Spacer().frame(width: yAxisWidth)
        }
    }

    /// Toujours 8 slots — pad avec nil les semaines manquantes en début.
    private func barSlots() -> [WeeklySnapshot?] {
        let cal = Calendar.iso8601Monday
        let thisMonday = Date.now.startOfWeek()
        var result: [WeeklySnapshot?] = Array(repeating: nil, count: 8)
        for i in 0..<8 {
            let offset = -7 * (7 - i)
            guard let weekStart = cal.date(byAdding: .day, value: offset, to: thisMonday) else { continue }
            result[i] = ordered.first(where: { Calendar.iso8601Monday.isDate($0.weekStart, inSameDayAs: weekStart) })
        }
        return result
    }

    private var insight: String {
        guard ordered.count >= 2 else {
            return String(localized: "popover.history.waiting", bundle: .runBarResources)
        }
        let previous = ordered.dropLast().last
        guard let previous else { return "" }
        let delta = goal.metric == .distance
            ? unit.valueFromKilometers(ordered.last?.achieved ?? 0) - unit.valueFromKilometers(previous.achieved)
            : (ordered.last?.achieved ?? 0) - previous.achieved
        if abs(delta) < 0.1 {
            return String(localized: "popover.history.stable", bundle: .runBarResources)
        }
        let key = delta > 0 ? "popover.history.up" : "popover.history.down"
        let value = abs(delta)
        let symbol = goal.metric == .distance ? unit.symbol : goal.metric.unit
        return String(format: String(localized: String.LocalizationValue(key), bundle: .runBarResources), DistanceFormatter.number(value), symbol)
    }

    private func shortWeek(_ date: Date) -> String {
        let week = Calendar.iso8601Monday.component(.weekOfYear, from: date)
        return "W\(week)"
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Streak badge

private struct StreakBadge: View {
    let count: Int
    let dark: Bool

    private var color: Color {
        switch count {
        case ..<3:  return RunBarColor.gold
        case ..<6:  return RunBarColor.vermillon
        default:    return RunBarColor.vermillonDeep
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 8.5, weight: .bold))
            Text("STREAK \(String(format: "%02d", count))")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .overlay(
            Capsule().strokeBorder(color.opacity(0.45), lineWidth: 0.7)
        )
        .foregroundStyle(color)
    }
}

// MARK: - Helpers

private extension DateFormatter {
    static let editorialMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

private extension Text {
    func italic(_ active: Bool) -> Text {
        active ? self.italic() : self
    }
}

#if DEBUG
#Preview("Light · normal") {
    PopoverView(viewModel: PopoverViewModel.preview(.normal))
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.78, green: 0.82, blue: 0.75),
                                            Color(red: 0.64, green: 0.71, blue: 0.60)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
}

#Preview("Light · empty") {
    PopoverView(viewModel: PopoverViewModel.preview(.empty))
        .padding(20)
        .background(Color(red: 0.93, green: 0.91, blue: 0.86))
}

#Preview("Dark · victory") {
    PopoverView(viewModel: PopoverViewModel.preview(.victory))
        .padding(20)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
#endif
