import SwiftUI

/// Popover principal du menu bar — 320×420.
/// Réplique fidèle de `popover.jsx` : header, stats, track, sorties, footer.
public struct PopoverView: View {
    @ObservedObject var viewModel: PopoverViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @AppStorage("runbar.onboardingDone") private var onboardingDone: Bool = false
    @State private var didTriggerOnboarding = false

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
            header(accent: accent)
            if let days = goal.daysUntilRace(), days >= 0, days <= 30 {
                raceCountdownBanner(days: days, name: goal.raceName ?? String(localized: "settings.goals.race_section", bundle: .module), accent: accent)
            }
            statsBlock(value: value, goal: goal, pct: pct, pctLabel: pctLabel, mode: mode, accent: accent)
            trackBlock(pct: pct, runner: runner, mode: mode)
            divider
            sortiesList(runs: runs, mode: mode, accent: accent)
            footer(accent: accent)
        }
        .frame(width: 320, height: 420)
        .background(RunBarColor.surface(dark: isDark))
        .foregroundStyle(RunBarColor.ink(dark: isDark))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(isDark ? 0.45 : 0.18), radius: 20, x: 0, y: 16)
        .onAppear {
            guard !onboardingDone, !didTriggerOnboarding else { return }
            didTriggerOnboarding = true
            // Petit délai pour laisser le popover finir son animation d'ouverture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                openWindow(id: "onboarding")
            }
        }
    }

    // MARK: Header
    @ViewBuilder
    private func header(accent: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(RunBarColor.surfaceTint(dark: isDark))
                RunnerView(state: viewModel.runnerState, color: accent, animated: true)
                    .frame(width: 16, height: 16)
            }
            .frame(width: 18, height: 18)

            Text("popover.this_week", bundle: .module)
                .font(RunBarFont.headerTitle)

            if viewModel.currentStreak >= 2 {
                StreakBadge(count: viewModel.currentStreak, dark: isDark)
            }

            Spacer()

            Button(action: {
                viewModel.openSettings()
                openSettings()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))

            Button(action: { viewModel.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RunBarColor.faintInk(dark: isDark))
                .frame(height: 1)
        }
    }

    // MARK: Race countdown
    @ViewBuilder
    private func raceCountdownBanner(days: Int, name: String, accent: Color) -> some View {
        let template = String(localized: "popover.race_in_n_days", bundle: .module)
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(String(format: template, days))
                    .font(.system(size: 10))
                    .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
            }
            Spacer()
            Text("D\(days == 0 ? "" : "-\(days)")")
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .tracking(-0.5)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.12), accent.opacity(0.04)],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: Stats
    @ViewBuilder
    private func statsBlock(value: Double, goal: WeeklyGoal, pct: Double, pctLabel: Int, mode: PopoverMode, accent: Color) -> some View {
        let unit = UnitPreferences.current
        // `value` et `goal.target` sont en km — on convertit pour l'affichage.
        let displayValue = unit.valueFromKilometers(value)
        let displayTarget = unit.valueFromKilometers(goal.target)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(DistanceFormatter.number(displayValue))
                        .font(RunBarFont.bigNumber.monospacedDigit())
                        .tracking(-0.6)
                    Text("/ \(Int(displayTarget.rounded())) \(unit.symbol)")
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                }
                Spacer()
                Text("\(pctLabel)%")
                    .font(RunBarFont.percent.monospacedDigit())
                    .tracking(-1.2)
                    .foregroundStyle(accent)
            }
            Text(metaCaption(mode: mode, value: value, goal: goal, unit: unit))
                .font(.system(size: 11, weight: .medium))
                .tracking(0.2)
                .textCase(.uppercase)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func metaCaption(mode: PopoverMode, value: Double, goal: WeeklyGoal, unit: DistanceUnit) -> String {
        switch mode {
        case .victory:
            return String(localized: "week.status.complete", bundle: .module)
        case .empty:
            let template = String(localized: "popover.week_n", bundle: .module)
            let start = String(localized: "week.status.start", bundle: .module)
            return String(format: template, Date().isoWeekOfYear(), start)
        case .normal:
            let remainingKm = max(0, goal.target - value)
            let remaining = unit.valueFromKilometers(remainingKm)
            return remainingLabel(value: remaining, unit: unit)
        }
    }

    /// "Plus que X km" / "X km to go" — on garde la chaîne dans Localizable.
    private func remainingLabel(value: Double, unit: DistanceUnit) -> String {
        let formatted = DistanceFormatter.number(value)
        // Une seule clé dans Localizable, deux versions selon l'unité courante.
        // Pour rester simple, on reformatte ici directement avec la chaîne déjà localisée.
        let pattern: String = {
            switch unit {
            case .km: return String(localized: "week.status.in_progress", bundle: .module)
            case .mi: return String(localized: "week.status.in_progress", bundle: .module)
            }
        }()
        return "\(pattern) — \(formatted) \(unit.symbol)"
    }

    // MARK: Track
    @ViewBuilder
    private func trackBlock(pct: Double, runner: RunnerState, mode: PopoverMode) -> some View {
        TrackView(
            progress: mode == .empty ? 0 : pct,
            runnerState: runner,
            dark: isDark,
            victory: mode == .victory
        )
        .frame(height: 70)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(RunBarColor.faintInk(dark: isDark))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: Sorties
    @ViewBuilder
    private func sortiesList(runs: [Activity], mode: PopoverMode, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Text("popover.outings", bundle: .module)
                    Text("(\(runs.count))").monospacedDigit()
                }
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                Spacer()
                if !runs.isEmpty {
                    Text(viewModel.averagePaceLabel)
                        .monospacedDigit()
                        .font(.system(size: 11))
                        .foregroundStyle(RunBarColor.ink(dark: isDark).opacity(0.85))
                }
            }
            .padding(.bottom, 6)

            if runs.isEmpty {
                emptyState
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(runs.enumerated()), id: \.element.id) { idx, run in
                        ActivityRowView(
                            day: run.dayLabel(),
                            name: run.name,
                            distanceKm: run.distanceKm,
                            timeLabel: viewModel.timeLabel(for: run),
                            dark: isDark,
                            highlight: mode == .victory && idx == runs.count - 1,
                            accent: accent
                        )
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("popover.no_outing_yet", bundle: .module)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RunBarColor.ink(dark: isDark))
            Text(viewModel.stravaConnected
                 ? LocalizedStringKey("popover.no_outing_subtitle")
                 : LocalizedStringKey("popover.connect_strava_cta"),
                 bundle: .module)
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
                .frame(maxWidth: 240)

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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(RunBarColor.moss)
                    )
                    .foregroundStyle(RunBarColor.cream)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: Footer
    @ViewBuilder
    private func footer(accent: Color) -> some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                    .background(
                        Circle()
                            .stroke(accent.opacity(0.15), lineWidth: 2)
                    )
                Text(viewModel.lastSyncLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(RunBarColor.mutedInk(dark: isDark))
            }
            Spacer()
            Button(action: { viewModel.syncNow() }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("popover.button.sync", bundle: .module)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(RunBarColor.faintInk(dark: isDark))
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(RunBarColor.ink(dark: isDark))
            .disabled(viewModel.isSyncing)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(height: 40)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RunBarColor.faintInk(dark: isDark))
                .frame(height: 1)
        }
    }
}

/// Badge streak — flamme + nombre, intensité visuelle qui scale avec la durée.
private struct StreakBadge: View {
    let count: Int
    let dark: Bool

    private var color: Color {
        switch count {
        case ..<3:  return RunBarColor.gold
        case ..<6:  return RunBarColor.terra
        default:    return Color(red: 0.96, green: 0.32, blue: 0.13)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color.opacity(0.18))
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(0.4), lineWidth: 0.5)
        )
        .foregroundStyle(color)
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

#Preview("Dark · victory") {
    PopoverView(viewModel: PopoverViewModel.preview(.victory))
        .padding(20)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
#endif
