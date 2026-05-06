import SwiftUI

/// Bouton OAuth « Connect with Strava » — asset officiel Strava.
///
/// Source : https://developers.strava.com/guidelines/ → "Connect with
/// Strava Buttons" → orange. Embarqué dans `Resources/StravaBrand/`.
public struct StravaConnectButton: View {
    public enum Size { case standard, compact }

    private let action: () -> Void
    private let size: Size

    public init(size: Size = .standard, action: @escaping () -> Void) {
        self.size = size
        self.action = action
    }

    public static let strava = Color(red: 0xFC / 255, green: 0x52 / 255, blue: 0x00 / 255)

    public var body: some View {
        Button(action: action) {
            Image("btn_strava_connect_with_orange", bundle: .runBarResources)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: size == .compact ? 26 : 36)
                .accessibilityLabel("Connect with Strava")
        }
        .buttonStyle(.plain)
    }
}

/// Tag d'attribution « Powered by Strava » — asset officiel Strava (horizontal).
///
/// Choisit automatiquement la variante noire ou blanche en fonction du
/// `ColorScheme` ambiant (light / dark mode), pour rester lisible quel que
/// soit le fond de la surface qui l'héberge (popover, footer settings, etc.).
public struct PoweredByStravaTag: View {
    @Environment(\.colorScheme) private var colorScheme
    private let height: CGFloat

    public init(height: CGFloat = 14) {
        self.height = height
    }

    public var body: some View {
        Image(
            colorScheme == .dark
                ? "api_logo_pwrdBy_strava_horiz_white"
                : "api_logo_pwrdBy_strava_horiz_black",
            bundle: .runBarResources
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: height)
        .accessibilityLabel("Powered by Strava")
    }
}
