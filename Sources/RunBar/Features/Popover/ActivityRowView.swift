import SwiftUI

/// Une ligne de la liste des sorties dans le popover.
struct ActivityRowView: View {
    let day: String
    let name: String
    let distanceKm: Double
    let elevationGain: Double
    let timeLabel: String
    let dark: Bool
    let highlight: Bool
    let accent: Color
    /// URL « View on Strava » — affichée pour les sorties Strava (Brand
    /// Guidelines : link to original data). Au tap, ouvre l'activité dans le
    /// navigateur. `nil` pour les autres sources (seed, futur HealthKit).
    let stravaURL: URL?

    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    @State private var hovered: Bool = false
    @Environment(\.openURL) private var openURL
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .km }

    init(
        day: String,
        name: String,
        distanceKm: Double,
        elevationGain: Double,
        timeLabel: String,
        dark: Bool,
        highlight: Bool,
        accent: Color,
        stravaURL: URL? = nil
    ) {
        self.day = day
        self.name = name
        self.distanceKm = distanceKm
        self.elevationGain = elevationGain
        self.timeLabel = timeLabel
        self.dark = dark
        self.highlight = highlight
        self.accent = accent
        self.stravaURL = stravaURL
    }

    var body: some View {
        let row = HStack(spacing: 10) {
            Text(day.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(highlight ? accent : RunBarColor.mutedInk(dark: dark))
                .frame(width: 30, alignment: .leading)

            Text(name)
                .font(.system(size: 12.5, weight: .regular, design: .serif).italic())
                .foregroundStyle(RunBarColor.ink(dark: dark))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Indicateur "View on Strava" — visible au hover si la sortie
            // vient de Strava. Tap n'importe où sur la ligne → ouvre.
            if stravaURL != nil, hovered {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StravaConnectButton.strava)
                    .accessibilityLabel(Text("View on Strava"))
            }

            HStack(spacing: 2) {
                let displayDistance = unit.valueFromKilometers(distanceKm)
                Text(DistanceFormatter.number(displayDistance))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(RunBarColor.ink(dark: dark))
                Text(unit.symbol)
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RunBarColor.mutedInk(dark: dark))
            }
            .frame(width: 56, alignment: .trailing)

            if RunBarPreferences.trailMode {
                Text("+\(Int(elevationGain.rounded()))m")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                    .frame(width: 44, alignment: .trailing)
            } else {
                Text(timeLabel)
                    .font(.system(size: 11, weight: .regular).monospacedDigit())
                    .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
        .background(
            highlight
                ? RunBarColor.vermillon.opacity(0.06)
                : (hovered && stravaURL != nil
                    ? StravaConnectButton.strava.opacity(0.05)
                    : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }

        if let url = stravaURL {
            Button(action: { openURL(url) }) { row }
                .buttonStyle(.plain)
                .help("View on Strava")
        } else {
            row
        }
    }
}
