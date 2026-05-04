import Foundation

/// Configuration Strava et adresse du backend OAuth.
///
/// Le `client_secret` Strava ne vit plus dans le binaire — il est détenu par
/// le backend (les routes `/api/strava/exchange` et `/api/strava/refresh` du
/// site Next.js déployé). L'app Swift garde uniquement le `client_id`, qui
/// est public (il apparaît dans l'URL d'autorisation).
enum Secrets {
    /// `client_id` Strava — public. Apparaît dans l'URL d'autorisation que
    /// l'utilisateur voit dans son navigateur, donc c'est OK de le baker
    /// dans le binaire. Override via env ou UserDefaults uniquement si tu
    /// forks et enregistres ta propre OAuth app sur https://www.strava.com/settings/api.
    static let stravaClientID = value(
        env: "RUNBAR_STRAVA_CLIENT_ID",
        defaults: "runbar.strava.clientID",
        fallback: "235433"
    )

    /// Adresse du backend qui détient le `client_secret` et fait l'échange.
    /// Override en dev via `RUNBAR_BACKEND_BASE_URL=http://localhost:3210`
    /// (le serveur Next.js local) ou `defaults write com.rodrigue.runbar
    /// runbar.backend.baseURL "http://localhost:3210"`.
    static let backendBaseURL = value(
        env: "RUNBAR_BACKEND_BASE_URL",
        defaults: "runbar.backend.baseURL",
        fallback: "https://runbar.app"
    )

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

    static let webhookVerifyToken = value(
        env: "RUNBAR_WEBHOOK_VERIFY_TOKEN",
        defaults: "runbar.webhook.verifyToken"
    )

    /// Le seul check requis côté desktop : avoir un `client_id`. Le secret est
    /// hors du binaire (sur le backend).
    static var hasStravaCredentials: Bool {
        !stravaClientID.isEmpty
    }

    private static func value(env: String, defaults: String, fallback: String = "") -> String {
        if let envValue = ProcessInfo.processInfo.environment[env], !envValue.isEmpty {
            return envValue
        }
        return UserDefaults.standard.string(forKey: defaults) ?? fallback
    }
}
