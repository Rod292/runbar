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
            statusBanner
            if let days = goal.daysUntilRace(), days >= 0 {
                raceCountdownBanner(
                    days: days,
                    name: goal.raceName ?? String(localized: "settings.goals.race_section", bundle: .module),
                    accent: accent
                )
            }
            statsBlock(value: value, goal: goal, pctLabel: pctLabel, mode: mode, accent: accent)
            progressRibbon(pct: pct, mode: mode, accent: accent)
            historyBlock(accent: accent)
            divider
            sortiesList(runs: runs, mode: mode, accent: accent)
            footer(accent: accent)
        }
        .frame(width: 320, height: 460)
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
        let weekNumber = Date().isoWeekOfYear()
        let dateLabel = DateFormatter.editorialMonthDay.string(from: Date()).uppercased()

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dateLabel) — 2026 · WK \(weekNumber)")
                        .eyebrowStyle(dark: isDark)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("This")
                            .font(.system(size: 22, weight: .regular, design: .serif).italic())
                            .foregroundStyle(RunBarColor.ink(dark: isDark))
                        Text("week.")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(RunBarColor.ink(dark: isDark))
                        if viewModel.currentStreak >= 2 {
                            StreakBadge(count: viewModel.currentStreak, dark: isDark)
                                .padding(.leading, 4)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 4) {
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
    private func headerIcon(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Status banner

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
                    Button(action: { viewModel.connectStrava() }) {
                        Text("settings.sources.connect", bundle: .module)
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(RunBarColor.mossDeep))
                            .foregroundStyle(RunBarColor.ivory)
                    }
                    .buttonStyle(.plain)
                } else if kind == .error {
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
        case .ready: return "checkmark.circle.fill"
        }
    }

    private func statusColor(_ kind: PopoverStatusKind) -> Color {
        switch kind {
        case .needsConnection, .waitingForSync: return RunBarColor.gold
        case .error: return RunBarColor.vermillonDeep
        case .syncing, .ready: return RunBarColor.vermillon
        }
    }

    // MARK: Race countdown

    @ViewBuilder
    private func raceCountdownBanner(days: Int, name: String, accent: Color) -> some View {
        let imminent = days <= 30
        let tone = imminent ? RunBarColor.vermillon : RunBarColor.mutedInk(dark: isDark)
        let template = String(localized: "popover.race_in_n_days", bundle: .module)

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
                    Text("\(Int(displayTarget.rounded())) \(unit.symbol)")
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
                }
                .padding(.leading, 8)

                Spacer()

                Text("\(pctLabel)%")
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .tracking(-0.4)
                    .foregroundStyle(mode == .victory ? RunBarColor.vermillonDeep : RunBarColor.inkSoft(dark: isDark))
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

    private func dataline(value: Double, remaining: Double, mode: PopoverMode,
                          goal: WeeklyGoal, daysLeft: Int) -> String {
        let kicker: String
        switch mode {
        case .victory:
            kicker = String(localized: "week.status.complete", bundle: .module)
        case .empty:
            kicker = String(localized: "week.status.start", bundle: .module)
        case .normal:
            kicker = String(localized: "week.status.in_progress", bundle: .module)
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

    // MARK: History block (8 weeks with Y-axis + goal line)

    @ViewBuilder
    private func historyBlock(accent: Color) -> some View {
        WeeklyHistoryStrip(
            snapshots: viewModel.recentSnapshots,
            goal: viewModel.goal,
            dark: isDark
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
                            accent: RunBarColor.vermillon
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

            Text(viewModel.stravaConnected
                 ? LocalizedStringKey("popover.no_outing_subtitle")
                 : LocalizedStringKey("popover.connect_strava_cta"),
                 bundle: .module)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(RunBarColor.inkSoft(dark: isDark))
                .frame(maxWidth: 260)

            if !viewModel.stravaConnected {
                Button(action: { viewModel.connectStrava() }) {
                    HStack(spacing: 6) {
                        AsyncImage(url: URL(string: "https://d3nn82uaxijpm6.cloudfront.net/icon-strava-chrome-192.png")) { img in
                            img.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: { Color.clear }
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("popover.connect_strava_cta", bundle: .module)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(RunBarColor.mossDeep)
                    )
                    .foregroundStyle(RunBarColor.ivory)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: Footer — colophon

    @ViewBuilder
    private func footer(accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.lastError != nil ? RunBarColor.vermillonDeep : RunBarColor.vermillon)
                .frame(width: 5, height: 5)
            Text(viewModel.lastSyncLabel.uppercased() + " · STRAVA")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .tracking(0.8)
                .lineLimit(1)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
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

    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .km }

    private var ordered: [WeeklySnapshot] {
        Array(snapshots.sorted(by: { $0.weekStart < $1.weekStart }).suffix(8))
    }

    /// Scale max — 1.5× le target pour qu'une bonne semaine ait du headroom.
    private var maxValue: Double {
        let goalValue = goal.target
        let achievedMax = ordered.map(\.achieved).max() ?? 0
        return max(goalValue * 1.5, achievedMax * 1.05, goalValue)
    }

    /// 4 graduations Y : 0, target/2, target, target*1.5
    private var yLabels: [(value: Double, label: String)] {
        let t = goal.target
        let unitForLabel = goal.metric == .distance ? unit.symbol : goal.metric.unit
        let asInt = { (v: Double) -> String in
            let display = goal.metric == .distance ? unit.valueFromKilometers(v) : v
            return "\(Int(display.rounded())) \(unitForLabel)"
        }
        return [
            (t * 1.5, asInt(t * 1.5)),
            (t,        asInt(t)),
            (t * 0.5,  asInt(t * 0.5)),
            (0,        "0 \(unitForLabel)"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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

            // Chart frame
            chartFrame
                .frame(height: 88)

            // X-axis labels
            xAxis
        }
    }

    @ViewBuilder
    private var chartFrame: some View {
        GeometryReader { geo in
            let yAxisWidth: CGFloat = 42
            let chartW = geo.size.width - yAxisWidth
            let chartH = geo.size.height
            let scale = maxValue
            let labelH: CGFloat = 10

            HStack(spacing: 0) {
                // Bars area (left)
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

                    // Bars
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(barSlots().enumerated()), id: \.offset) { idx, snap in
                            barView(snap: snap, isCurrent: idx == 7, scale: scale, height: chartH)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: chartW, height: chartH)

                // Y-axis labels (right) — centered on their tick, clamped to chart frame.
                ZStack(alignment: .topTrailing) {
                    ForEach(yLabels, id: \.label) { tick in
                        let y = scale > 0 ? chartH * (1 - CGFloat(tick.value / scale)) : 0
                        let clamped = min(chartH - labelH, Swift.max(0, y - labelH / 2))
                        Text(tick.label)
                            .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                            .tracking(0.4)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                            .frame(width: yAxisWidth - 4, height: labelH, alignment: .trailing)
                            .offset(y: clamped)
                    }
                }
                .frame(width: yAxisWidth, height: chartH)
            }
        }
    }

    @ViewBuilder
    private func barView(snap: WeeklySnapshot?, isCurrent: Bool, scale: Double, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let snap, scale > 0 {
                let h = height * CGFloat(min(1.0, snap.achieved / scale))
                let isComplete = snap.completed
                let fill: Color = {
                    if isCurrent {
                        return isComplete ? RunBarColor.vermillon : RunBarColor.vermillon.opacity(0.7)
                    }
                    return isComplete ? RunBarColor.inkSoft(dark: dark) : RunBarColor.mutedInk(dark: dark).opacity(0.55)
                }()
                Rectangle()
                    .fill(fill)
                    .frame(width: 5, height: Swift.max(2, h))
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
            return String(localized: "popover.history.waiting", bundle: .module)
        }
        let previous = ordered.dropLast().last
        guard let previous else { return "" }
        let delta = goal.metric == .distance
            ? unit.valueFromKilometers(ordered.last?.achieved ?? 0) - unit.valueFromKilometers(previous.achieved)
            : (ordered.last?.achieved ?? 0) - previous.achieved
        if abs(delta) < 0.1 {
            return String(localized: "popover.history.stable", bundle: .module)
        }
        let key = delta > 0 ? "popover.history.up" : "popover.history.down"
        let value = abs(delta)
        let symbol = goal.metric == .distance ? unit.symbol : goal.metric.unit
        return String(format: String(localized: String.LocalizationValue(key), bundle: .module), DistanceFormatter.number(value), symbol)
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
