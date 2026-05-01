import SwiftUI

/// Palette RunBar — inspirée trail bretagne (mousse, terre cuite, or, granite).
/// Sourced from `RunBar Design.html` — section Foundations.
enum RunBarColor {
    static let moss     = Color(red: 0x2D / 255, green: 0x7A / 255, blue: 0x3E / 255)
    static let terra    = Color(red: 0xC7 / 255, green: 0x5D / 255, blue: 0x2C / 255)
    static let gold     = Color(red: 0xD4 / 255, green: 0xA2 / 255, blue: 0x4C / 255)
    static let granite  = Color(red: 0x4A / 255, green: 0x4A / 255, blue: 0x4A / 255)
    static let cream    = Color(red: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE6 / 255)
    static let slate    = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let inkLight = Color(red: 0xF2 / 255, green: 0xEF / 255, blue: 0xE7 / 255)

    /// Surface du popover — auto light/dark.
    static func surface(dark: Bool) -> Color { dark ? slate : cream }

    /// Encre principale — auto light/dark.
    static func ink(dark: Bool) -> Color { dark ? inkLight : slate }

    static func mutedInk(dark: Bool) -> Color {
        dark ? Color(white: 1, opacity: 0.55) : Color(white: 0, opacity: 0.55)
    }

    static func faintInk(dark: Bool) -> Color {
        dark ? Color(white: 1, opacity: 0.10) : Color(white: 0, opacity: 0.10)
    }

    static func surfaceTint(dark: Bool) -> Color {
        dark ? Color(white: 1, opacity: 0.03) : Color(white: 0, opacity: 0.025)
    }

    /// Couleur d'accent dérivée de l'état du runner.
    static func accent(for state: RunnerState) -> Color {
        switch state {
        case .victory: return gold
        case .tired:   return terra
        default:       return moss
        }
    }
}
