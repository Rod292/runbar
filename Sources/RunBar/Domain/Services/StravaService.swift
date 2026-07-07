import Foundation
import Logging

/// API Strava — OAuth + activities. La vraie implémentation, plus le stub Preview.
public protocol StravaServiceProtocol: Sendable {
    func isAuthenticated() async -> Bool
    func startOAuth() async throws
    func disconnect() async
    func fetchActivities(since: Date) async throws -> [ActivityDTO]
}

public actor StravaService: StravaServiceProtocol {
    public init() {}

    private let connectedKey = "runbar.strava.connected"

    /// Base de l'API data Strava. Strava migre vers `https://www.api-v3.strava.com`
    /// (obligatoire à partir du 2026-06-01 selon l'annonce, cutover technique
    /// 2027-06-01). Ce host n'est pas encore résolvable (vérifié 2026-06-02), donc
    /// on reste sur la base actuelle — il suffira de basculer cette seule constante
    /// (et de retirer le segment `/api/v3` absorbé par le nouveau host) le jour J.
    /// Surchargable via env pour tester le nouveau host sans recompiler.
    private static let apiBase =
        ProcessInfo.processInfo.environment["RUNBAR_STRAVA_API_BASE"]
        ?? "https://www.strava.com/api/v3"

    /// Refresh token (durée de vie longue). Stocké en Keychain.
    /// `connectedKey` ne passe à true que si l'écriture Keychain a réussi —
    /// sinon l'app afficherait "connecté" alors que le token serait perdu au
    /// prochain restart.
    private var refreshToken: String? {
        get { Keychain.get(account: "refresh_token") }
        set {
            if let newValue {
                do {
                    try Keychain.set(newValue, account: "refresh_token")
                    UserDefaults.standard.set(true, forKey: connectedKey)
                } catch {
                    RunBarLog.strava.error("Keychain write failed for refresh_token: \(error)")
                    UserDefaults.standard.set(false, forKey: connectedKey)
                }
            } else {
                Keychain.remove(account: "refresh_token")
                UserDefaults.standard.set(false, forKey: connectedKey)
            }
        }
    }

    /// Access token (durée 6h). Persisté en Keychain pour survivre aux
    /// restarts — utile pour pré-seeder en dev sans passer par OAuth.
    /// Un échec d'écriture n'est pas fatal (le token sera re-refreshé) mais
    /// doit être visible dans les logs.
    private var accessToken: String? {
        get { Keychain.get(account: "access_token") }
        set {
            if let newValue {
                do { try Keychain.set(newValue, account: "access_token") }
                catch { RunBarLog.strava.error("Keychain write failed for access_token: \(error)") }
            } else {
                Keychain.remove(account: "access_token")
            }
        }
    }

    private var accessTokenExpiry: Date? {
        get {
            guard
                let raw = Keychain.get(account: "access_token_expiry"),
                let ts = Double(raw)
            else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            if let newValue {
                let ts = String(newValue.timeIntervalSince1970)
                do { try Keychain.set(ts, account: "access_token_expiry") }
                catch { RunBarLog.strava.error("Keychain write failed for access_token_expiry: \(error)") }
            } else {
                Keychain.remove(account: "access_token_expiry")
            }
        }
    }

    public func isAuthenticated() async -> Bool {
        UserDefaults.standard.bool(forKey: connectedKey)
    }

    public func startOAuth() async throws {
        let coord = await MainActor.run { StravaOAuthCoordinator() }
        let code = try await coord.authorize()
        let tokens = try await exchangeCodeForTokens(code: code)
        self.refreshToken = tokens.refreshToken
        self.accessToken = tokens.accessToken
        self.accessTokenExpiry = Date(timeIntervalSince1970: tokens.expiresAt)
        // Si l'écriture Keychain a échoué (trousseau verrouillé, quota…), le
        // token est déjà perdu : mieux vaut un échec franc dans l'onboarding
        // qu'une connexion fantôme qui disparaît au prochain restart.
        guard self.refreshToken != nil else { throw StravaError.keychainWriteFailed }
        RunBarLog.strava.info("OAuth flow completed; tokens stored.")
    }

    public func disconnect() async {
        // Best-effort : on demande à Strava d'invalider le grant côté serveur
        // AVANT d'effacer notre copie locale (conformité §5.4 — révoquer l'accès
        // sur déconnexion). Utilise `oauth/revoke`, le seul endpoint supporté
        // après le 2027-06-01 (`oauth/deauthorize` est retiré). Non bloquant :
        // on efface toujours les tokens locaux même si l'appel réseau échoue.
        if let token = accessToken ?? refreshToken {
            await revokeToken(token)
        }
        self.refreshToken = nil
        self.accessToken = nil
        self.accessTokenExpiry = nil
        Keychain.remove(account: "access_token")
        Keychain.remove(account: "access_token_expiry")
    }

    public func fetchActivities(since: Date) async throws -> [ActivityDTO] {
        guard Secrets.hasStravaCredentials else { throw StravaError.missingConfiguration }
        let token = try await ensureFreshAccessToken()
        var all: [StravaActivityDTO] = []
        var page = 1

        // `per_page=200` est le maximum documenté Strava — minimise le nombre
        // de requêtes pour le backfill initial (3 000 activités = ~15 reqs).
        let perPage = 200
        // Garde-fou : 50 pages = 10 000 activités sur la fenêtre demandée.
        // Au-delà, c'est presque certainement une réponse anormale de l'API —
        // on s'arrête plutôt que de brûler le quota (200 req/15 min).
        let maxPages = 50
        while true {
            var components = URLComponents(string: "\(Self.apiBase)/athlete/activities")!
            components.queryItems = [
                URLQueryItem(name: "after", value: String(Int(since.timeIntervalSince1970))),
                URLQueryItem(name: "per_page", value: String(perPage)),
                URLQueryItem(name: "page", value: String(page)),
            ]
            guard let url = components.url else { throw StravaError.missingConfiguration }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, http) = try await send(req, context: "activities page \(page)")
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                RunBarLog.strava.error("activities fetch failed: HTTP \(http.statusCode) — \(body)")
                throw Self.decodeAPIError(status: http.statusCode, body: data)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let pageItems = try decoder.decode([StravaActivityDTO].self, from: data)
            all.append(contentsOf: pageItems)
            guard pageItems.count == perPage else { break }
            guard page < maxPages else {
                RunBarLog.strava.error("pagination cap hit (\(maxPages) pages) — truncating backfill")
                break
            }
            page += 1
        }

        let runs = all.filter(\.isRunningActivity)
        if all.count > 0 && runs.isEmpty {
            // Help users diagnose "I have activities but RunBar shows 0 runs":
            // log the types we received so the OAuth+account combination is
            // visible without exposing private data (no name, no GPS, no time).
            let types = Dictionary(grouping: all, by: \.type)
                .mapValues(\.count)
                .sorted { $0.value > $1.value }
                .prefix(8)
                .map { "\($0.key)×\($0.value)" }
                .joined(separator: " ")
            RunBarLog.strava.notice(
                "Strava returned \(all.count) activities but none are runs. Types seen: \(types)"
            )
        }
        return runs.map { $0.toDomain() }
    }

    // MARK: - Réseau

    /// Transforme le payload d'erreur Strava (`{"message","errors":[{resource,
    /// field,code}]}`) en erreur actionnable. Le cas vécu le 2026-07-07 :
    /// l'application API entière désactivée par Strava (échéance abonnement du
    /// programme développeur 2026) se présentait comme un "Server error
    /// (HTTP 403)" opaque alors que Strava disait précisément
    /// `Application/Status/Inactive`.
    static func decodeAPIError(status: Int, body: Data) -> StravaError {
        struct APIError: Decodable {
            struct Item: Decodable { let resource: String?; let field: String?; let code: String? }
            let message: String?
            let errors: [Item]?
        }
        guard let parsed = try? JSONDecoder().decode(APIError.self, from: body) else {
            return .httpStatus(status)
        }
        if parsed.errors?.contains(where: { $0.resource == "Application" && $0.code == "Inactive" }) == true {
            return .applicationInactive
        }
        if status == 401 || parsed.errors?.contains(where: { $0.field == "access_token" }) == true {
            return .notAuthenticated
        }
        return .httpStatus(status)
    }

    /// Nombre total de tentatives pour un même appel (1 + 2 retries).
    private static let maxAttempts = 3

    /// Envoie une requête et retente avec backoff exponentiel sur 429 et 5xx.
    /// Les quotas du programme développeur 2026 sont serrés (200 req/15 min en
    /// single player, 400 après l'upgrade 10 athlètes) : un backfill initial
    /// paginé peut frôler la fenêtre, et sans retry l'utilisateur voit un
    /// "Server error (HTTP 429)" sec. Respecte `Retry-After` si présent
    /// (borné à 60 s pour ne pas bloquer une sync indéfiniment).
    private func send(_ request: URLRequest, context: String) async throws -> (Data, HTTPURLResponse) {
        var attempt = 1
        while true {
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard let http = resp as? HTTPURLResponse else { throw StravaError.httpStatus(0) }
            let retryable = http.statusCode == 429 || (500..<600).contains(http.statusCode)
            guard retryable, attempt < Self.maxAttempts else { return (data, http) }

            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            let delay = retryAfter.map { min(max($0, 1), 60) } ?? min(pow(2, Double(attempt)), 30)
            let jitter = Double.random(in: 0...0.5)
            RunBarLog.strava.notice(
                "\(context): HTTP \(http.statusCode), retry \(attempt)/\(Self.maxAttempts - 1) in \(String(format: "%.1f", delay + jitter))s"
            )
            try await Task.sleep(nanoseconds: UInt64((delay + jitter) * 1_000_000_000))
            attempt += 1
        }
    }

    // MARK: - Token plumbing

    private func ensureFreshAccessToken() async throws -> String {
        // Cache hit
        if let token = accessToken, let exp = accessTokenExpiry, exp > Date.now.addingTimeInterval(60) {
            return token
        }
        guard let refresh = refreshToken else {
            UserDefaults.standard.set(false, forKey: connectedKey)
            throw StravaError.notAuthenticated
        }
        let tokens = try await refreshTokens(refreshToken: refresh)
        self.accessToken = tokens.accessToken
        self.accessTokenExpiry = Date(timeIntervalSince1970: tokens.expiresAt)
        // Strava peut retourner un nouveau refresh token — stocker.
        if !tokens.refreshToken.isEmpty {
            self.refreshToken = tokens.refreshToken
        }
        return tokens.accessToken
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Double

        enum CodingKeys: String, CodingKey {
            case accessToken  = "access_token"
            case refreshToken = "refresh_token"
            case expiresAt    = "expires_at"
        }
    }

    private func exchangeCodeForTokens(code: String) async throws -> TokenResponse {
        if let secret = Secrets.stravaClientSecret {
            return try await directStravaTokenCall(payload: [
                "client_id": Secrets.stravaClientID,
                "client_secret": secret,
                "code": code,
                "grant_type": "authorization_code",
            ])
        }
        return try await callBackend(
            path: "/api/strava/exchange",
            payload: [
                "code": code,
                "redirect_uri": Secrets.stravaRedirectURI
            ]
        )
    }

    private func refreshTokens(refreshToken: String) async throws -> TokenResponse {
        if let secret = Secrets.stravaClientSecret {
            return try await directStravaTokenCall(payload: [
                "client_id": Secrets.stravaClientID,
                "client_secret": secret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token",
            ])
        }
        return try await callBackend(
            path: "/api/strava/refresh",
            payload: ["refresh_token": refreshToken]
        )
    }

    /// Mode "Bring Your Own App" : appel direct à
    /// `https://www.strava.com/oauth/token` avec le `client_secret` que
    /// l'utilisateur a saisi dans Settings. On reproduit le format
    /// `application/x-www-form-urlencoded` documenté par Strava.
    private func directStravaTokenCall(payload: [String: String]) async throws -> TokenResponse {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = payload.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let (data, http) = try await send(req, context: "direct token call")
        guard (200..<300).contains(http.statusCode) else {
            RunBarLog.strava.error(
                "direct strava token endpoint failed: HTTP \(http.statusCode) — \(String(data: data, encoding: .utf8) ?? "")"
            )
            throw StravaError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /// Le backend (Next.js sur `Secrets.backendBaseURL`) détient le
    /// `client_secret` et fait l'appel à `https://www.strava.com/oauth/token`.
    /// Il renvoie tel quel le payload de Strava (access_token, refresh_token,
    /// expires_at, athlete, …).
    private func callBackend(path: String, payload: [String: String]) async throws -> TokenResponse {
        guard let url = URL(string: Secrets.backendBaseURL + path) else {
            throw StravaError.missingConfiguration
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, http) = try await send(req, context: "backend token call")
        guard (200..<300).contains(http.statusCode) else {
            RunBarLog.strava.error(
                "backend token endpoint failed: HTTP \(http.statusCode) — \(String(data: data, encoding: .utf8) ?? "")"
            )
            throw StravaError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    // MARK: - Revoke

    /// Révoque le grant côté Strava. En mode "Bring Your Own App" on a le
    /// `client_secret` localement → appel direct. Sinon c'est le backend (qui
    /// détient le secret) qui révoque. Toujours best-effort : les erreurs sont
    /// loggées mais jamais propagées (la déconnexion locale doit aboutir).
    private func revokeToken(_ token: String) async {
        do {
            if let secret = Secrets.stravaClientSecret {
                try await directStravaRevoke(
                    token: token,
                    clientID: Secrets.stravaClientID,
                    clientSecret: secret
                )
            } else {
                try await backendRevoke(token: token)
            }
            RunBarLog.strava.info("Strava grant revoked on disconnect.")
        } catch {
            RunBarLog.strava.notice(
                "token revoke failed (non-fatal): \(error.localizedDescription)"
            )
        }
    }

    /// Mode BYO : POST `https://www.strava.com/oauth/revoke` avec Basic Auth
    /// `client_id:client_secret` et le `token` en form param, comme documenté.
    private func directStravaRevoke(token: String, clientID: String, clientSecret: String) async throws {
        let url = URL(string: "https://www.strava.com/oauth/revoke")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let basic = Data("\(clientID):\(clientSecret)".utf8).base64EncodedString()
        req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        req.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let (_, http) = try await send(req, context: "direct revoke")
        guard (200..<300).contains(http.statusCode) else {
            throw StravaError.httpStatus(http.statusCode)
        }
    }

    /// Mode app partagée : le backend détient le `client_secret` et fait le
    /// Basic Auth vers Strava. On lui transmet juste le token à révoquer.
    private func backendRevoke(token: String) async throws {
        guard let url = URL(string: Secrets.backendBaseURL + "/api/strava/revoke") else {
            throw StravaError.missingConfiguration
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["token": token], options: [])

        let (_, http) = try await send(req, context: "backend revoke")
        guard (200..<300).contains(http.statusCode) else {
            throw StravaError.httpStatus(http.statusCode)
        }
    }
}

// MARK: - DTO

private struct StravaActivityDTO: Decodable {
    let id: Int
    let name: String
    let distance: Double
    let movingTime: Int
    let totalElevationGain: Double
    let startDate: Date
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, name, distance, type
        case movingTime         = "moving_time"
        case totalElevationGain = "total_elevation_gain"
        case startDate          = "start_date"
    }

    func toDomain() -> ActivityDTO {
        ActivityDTO(
            id: String(id),
            name: name,
            distance: distance,
            movingTime: movingTime,
            elevationGain: totalElevationGain,
            startDate: startDate,
            type: type,
            source: .strava
        )
    }

    var isRunningActivity: Bool {
        ["Run", "TrailRun", "VirtualRun"].contains(type)
    }
}

// MARK: - Errors

public enum StravaError: Error, LocalizedError {
    case notImplemented
    case missingConfiguration
    case notAuthenticated
    case oauthFailed
    case oauthTimeout
    case invalidOAuthState
    case keychainWriteFailed
    case applicationInactive
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:    return "Strava connection coming soon."
        case .missingConfiguration:
            return "Strava configuration missing. Set RUNBAR_STRAVA_CLIENT_ID (env or defaults). The OAuth secret lives on the backend."
        case .notAuthenticated:  return "Not connected to Strava."
        case .oauthFailed:       return "Authorization failed."
        case .oauthTimeout:      return "Strava connection timed out."
        case .invalidOAuthState: return "Invalid OAuth response."
        case .keychainWriteFailed:
            return "Connected to Strava, but the token could not be saved to the Keychain. Unlock your keychain and try again."
        case .applicationInactive:
            return "Strava has deactivated this API application (developer-program requirement). The app owner must reactivate it at strava.com/settings/api — reconnecting won't help until then."
        case .httpStatus(let c):
            return c == 429
                ? "Strava rate limit reached. RunBar will retry on the next sync."
                : "Server error (HTTP \(c))."
        }
    }
}

// MARK: - Preview stub

#if DEBUG
public extension StravaService {
    static var preview: StravaServiceProtocol { PreviewStravaService() }
}

actor PreviewStravaService: StravaServiceProtocol {
    func isAuthenticated() async -> Bool { true }
    func startOAuth() async throws {}
    func disconnect() async {}
    func fetchActivities(since: Date) async throws -> [ActivityDTO] { [] }
}
#endif
