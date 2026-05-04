import SwiftUI

/// Palette RunBar — éditoriale (ivory/ink/vermillon) alignée sur le site.
/// Pristine Light Mode + équivalent dark.
enum RunBarColor {
    // MARK: Editorial tokens (canon, alignés sur website/app/globals.css)

    /// Surface principale light — ivoire.
    static let ivory          = Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xEE / 255)
    /// Surface secondaire light — papier (un cran plus clair que l'ivoire).
    static let paper          = Color(red: 0xFB / 255, green: 0xF9 / 255, blue: 0xF4 / 255)
    /// Encre principale.
    static let inkBlack       = Color(red: 0x0F / 255, green: 0x0F / 255, blue: 0x0E / 255)
    /// Encre douce — corps de texte secondaire.
    static let inkSoft        = Color(red: 0x46 / 255, green: 0x46 / 255, blue: 0x3F / 255)
    /// Encre sourdine — meta, eyebrows, axes.
    static let inkMute        = Color(red: 0x8A / 255, green: 0x88 / 255, blue: 0x7E / 255)
    /// Hairline — règles, séparateurs, ticks.
    static let hairlineLight  = Color(red: 0xDD / 255, green: 0xD7 / 255, blue: 0xCB / 255)
    /// Accent vermillon — finish lines, current week, % achievement.
    static let vermillon      = Color(red: 0xE5 / 255, green: 0x52 / 255, blue: 0x3D / 255)
    static let vermillonDeep  = Color(red: 0xB8 / 255, green: 0x3C / 255, blue: 0x28 / 255)
    /// Mousse — pour CTA secondaires (fond bouton "Connect Strava").
    static let mossDeep       = Color(red: 0x1F / 255, green: 0x2A / 255, blue: 0x22 / 255)

    // MARK: Legacy tokens (rétrocompatibilité — utilisés ailleurs dans l'app)

    static let moss     = Color(red: 0x2D / 255, green: 0x7A / 255, blue: 0x3E / 255)
    static let terra    = Color(red: 0xC7 / 255, green: 0x5D / 255, blue: 0x2C / 255)
    static let gold     = Color(red: 0xD4 / 255, green: 0xA2 / 255, blue: 0x4C / 255)
    static let granite  = Color(red: 0x4A / 255, green: 0x4A / 255, blue: 0x4A / 255)
    static let cream    = Color(red: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE6 / 255)
    static let slate    = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let inkLight = Color(red: 0xF2 / 255, green: 0xEF / 255, blue: 0xE7 / 255)

    // MARK: Editorial helpers (light + dark)

    /// Surface principale du popover.
    static func surface(dark: Bool) -> Color {
        dark ? Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x12 / 255) : ivory
    }

    /// Surface alternative (cards, blocs internes).
    static func paperSurface(dark: Bool) -> Color {
        dark ? Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x16 / 255) : paper
    }

    /// Encre principale.
    static func ink(dark: Bool) -> Color {
        dark ? Color(red: 0xF2 / 255, green: 0xEF / 255, blue: 0xE7 / 255) : inkBlack
    }

    /// Encre soft — body secondaire.
    static func inkSoft(dark: Bool) -> Color {
        dark ? Color(red: 0xC5 / 255, green: 0xC2 / 255, blue: 0xB7 / 255) : inkSoft
    }

    /// Encre muette — meta, eyebrows, axes.
    static func mutedInk(dark: Bool) -> Color {
        dark ? Color(red: 0x88 / 255, green: 0x86 / 255, blue: 0x7C / 255) : inkMute
    }

    /// Hairline — règles, séparateurs.
    static func hairline(dark: Bool) -> Color {
        dark ? Color(white: 1, opacity: 0.14) : hairlineLight
    }

    /// Hairline très discret (pour overlays internes).
    static func faintInk(dark: Bool) -> Color {
        dark ? Color(white: 1, opacity: 0.08) : Color(red: 0xDD / 255, green: 0xD7 / 255, blue: 0xCB / 255).opacity(0.55)
    }

    static func surfaceTint(dark: Bool) -> Color {
        dark ? Color(white: 1, opacity: 0.03) : Color(white: 0, opacity: 0.025)
    }

    /// Accent éditorial — vermillon par défaut, terra pour fatigue, deep pour victory.
    static func accent(for state: RunnerState) -> Color {
        switch state {
        case .victory: return vermillonDeep
        case .tired:   return Color(red: 0xC7 / 255, green: 0x5D / 255, blue: 0x2C / 255)
        default:       return vermillon
        }
    }
}
