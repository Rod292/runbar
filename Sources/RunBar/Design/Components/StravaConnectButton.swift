import SwiftUI

/// Bouton OAuth « Connect with Strava » conforme aux Strava Brand Guidelines.
///
/// Couleur orange officielle Strava (#FC5200), texte exact, layout en capsule.
/// Pour une conformité 100% visuelle, remplacer le label par l'asset PNG
/// officiel téléchargé depuis :
///   https://developers.strava.com/guidelines/
///   (btn_strava_connectwith_orange.png + @2x)
/// et l'embarquer dans Resources.
public struct StravaConnectButton: View {
    public enum Size { case standard, compact }

    private let action: () -> Void
    private let size: Size

    public init(size: Size = .standard, action: @escaping () -> Void) {
        self.size = size
        self.action = action
    }

    /// Couleur orange Strava officielle.
    public static let strava = Color(red: 0xFC / 255, green: 0x52 / 255, blue: 0x00 / 255)

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                stravaGlyph
                Text("Connect with Strava")
                    .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, size == .compact ? 12 : 18)
            .padding(.vertical, size == .compact ? 7 : 10)
            .background(Capsule().fill(Self.strava))
        }
        .buttonStyle(.plain)
    }

    /// Glyph stylisé évoquant le chevron Strava — substitut au logo officiel
    /// jusqu'à ce que l'asset PNG soit embarqué.
    private var stravaGlyph: some View {
        Image(systemName: "chevron.up")
            .font(.system(size: size == .compact ? 11 : 13, weight: .heavy))
            .foregroundStyle(.white)
    }
}

/// Tag d'attribution « Powered by Strava » — affiché là où on display de la
/// Strava Data (footer du popover, page download du site).
public struct PoweredByStravaTag: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Text("POWERED BY")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text("STRAVA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(StravaConnectButton.strava)
        }
    }
}
