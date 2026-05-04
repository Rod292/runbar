import SwiftUI

/// Typo RunBar — SF par défaut côté UI, mono pour les chiffres et métadonnées.
/// Le design cible Inter/JetBrains Mono mais on reste en système pour ne pas
/// embarquer de fonts custom — SF Pro et SF Mono couvrent les mêmes rôles.
enum RunBarFont {
    static func ui(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Italique serif — pour les mots éditoriaux ("This", "Waiting.", etc.).
    static func italicSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }

    // Numerics / display
    static let bigNumber = ui(size: 28, weight: .semibold)
    static let percent = ui(size: 36, weight: .semibold)

    // Editorial display — italique serif pour les "mots accent".
    static let displayWord = italicSerif(size: 22, weight: .regular)

    // Header popover
    static let headerTitle = ui(size: 13, weight: .semibold)

    // Eyebrows / axes / colophons — mono small-caps tracking.
    static let eyebrow  = mono(size: 9.5, weight: .medium)
    static let axis     = mono(size: 9, weight: .regular)
    static let colophon = mono(size: 9, weight: .regular)
    static let capLabel = mono(size: 10)
}

extension Text {
    /// Chiffres tabulaires pour stabiliser les sauts visuels.
    func tabularNums() -> Text { self.monospacedDigit() }

    /// Eyebrow uppercase + tracking large (mono small-caps).
    func eyebrowStyle(dark: Bool) -> some View {
        self.font(RunBarFont.eyebrow)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(RunBarColor.mutedInk(dark: dark))
    }
}
