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

    var body: some View {
        HStack(spacing: 10) {
            Text(day)
                .font(.system(size: 10, weight: .bold).monospaced())
                .tracking(0.6)
                .foregroundStyle(highlight ? accent : RunBarColor.mutedInk(dark: dark))
                .frame(width: 32, alignment: .leading)

            Text(name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(RunBarColor.ink(dark: dark))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 1) {
                let unit = UnitPreferences.current
                let displayDistance = unit.valueFromKilometers(distanceKm)
                Text(DistanceFormatter.number(displayDistance))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(RunBarColor.ink(dark: dark).opacity(0.85))
                Text(" \(unit.symbol)")
                    .font(.system(size: 10))
                    .foregroundStyle(RunBarColor.mutedInk(dark: dark))
            }
            .frame(width: 60, alignment: .trailing)

            if RunBarPreferences.trailMode {
                Text("+\(Int(elevationGain.rounded()))m")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                    .frame(width: 48, alignment: .trailing)
            } else {
                Text(timeLabel)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(RunBarColor.mutedInk(dark: dark))
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(highlight ? RunBarColor.gold.opacity(0.12) : .clear)
        )
    }
}
