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

    @AppStorage("runbar.unit") private var unitRaw: String = DistanceUnit.systemDefault.rawValue
    private var unit: DistanceUnit { DistanceUnit(rawValue: unitRaw) ?? .km }

    var body: some View {
        HStack(spacing: 10) {
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
            highlight ? RunBarColor.vermillon.opacity(0.06) : .clear
        )
    }
}
