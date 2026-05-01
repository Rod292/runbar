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

    /// Gros chiffre (42 km / 70%). Tabular nums + tracking serré.
    static let bigNumber = ui(size: 28, weight: .semibold)
    /// Pourcentage très large (36pt accent).
    static let percent = ui(size: 36, weight: .semibold)
    /// Titre header popover.
    static let headerTitle = ui(size: 13, weight: .semibold)
    /// Label CAPS (sections).
    static let capLabel = mono(size: 10)
}

extension Text {
    /// Chiffres tabulaires pour stabiliser les sauts visuels.
    func tabularNums() -> Text { self.monospacedDigit() }
}
