import Foundation

/// Configuration Strava. Les secrets réels doivent venir de l'environnement
/// local, pas du dépôt.
enum Secrets {
    static let stravaClientID = value(env: "RUNBAR_STRAVA_CLIENT_ID", defaults: "runbar.strava.clientID")
    static let stravaClientSecret = value(env: "RUNBAR_STRAVA_CLIENT_SECRET", defaults: "runbar.strava.clientSecret")
    /// Callback OAuth — un mini serveur local intercepte la requête.
    /// La "Authorization Callback Domain" sur https://www.strava.com/settings/api
    /// doit valoir `localhost`.
    static let stravaRedirectURI = value(
        env: "RUNBAR_STRAVA_REDIRECT_URI",
        defaults: "runbar.strava.redirectURI",
        fallback: "http://localhost:47862/callback"
    )
    static let stravaLocalCallbackPort: UInt16 = 47862
    /// Scope minimal pour lire les sorties privées et publiques.
    static let stravaScope = value(
        env: "RUNBAR_STRAVA_SCOPE",
        defaults: "runbar.strava.scope",
        fallback: "activity:read_all"
    )
    static let webhookVerifyToken = value(env: "RUNBAR_WEBHOOK_VERIFY_TOKEN", defaults: "runbar.webhook.verifyToken")

    static var hasStravaCredentials: Bool {
        !stravaClientID.isEmpty && !stravaClientSecret.isEmpty
    }

    private static func value(env: String, defaults: String, fallback: String = "") -> String {
        if let envValue = ProcessInfo.processInfo.environment[env], !envValue.isEmpty {
            return envValue
        }
        return UserDefaults.standard.string(forKey: defaults) ?? fallback
    }
}
