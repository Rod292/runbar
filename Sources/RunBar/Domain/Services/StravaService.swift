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

    /// Refresh token (durée de vie longue). Stocké en Keychain.
    private var refreshToken: String? {
        get { Keychain.get(account: "refresh_token") }
        set {
            if let newValue {
                try? Keychain.set(newValue, account: "refresh_token")
                UserDefaults.standard.set(true, forKey: connectedKey)
            } else {
                Keychain.remove(account: "refresh_token")
                UserDefaults.standard.set(false, forKey: connectedKey)
            }
        }
    }

    /// Access token (durée 6h). Stocké en mémoire seulement.
    private var accessToken: String?
    private var accessTokenExpiry: Date?

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
        RunBarLog.strava.info("OAuth flow completed; tokens stored.")
    }

    public func disconnect() async {
        self.refreshToken = nil
        self.accessToken = nil
        self.accessTokenExpiry = nil
    }

    public func fetchActivities(since: Date) async throws -> [ActivityDTO] {
        guard Secrets.hasStravaCredentials else { throw StravaError.missingConfiguration }
        let token = try await ensureFreshAccessToken()
        var all: [StravaActivityDTO] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
            components.queryItems = [
                URLQueryItem(name: "after", value: String(Int(since.timeIntervalSince1970))),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
            ]
            var req = URLRequest(url: components.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                RunBarLog.strava.error("activities fetch failed: HTTP \(code)")
                throw StravaError.httpStatus(code)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let pageItems = try decoder.decode([StravaActivityDTO].self, from: data)
            all.append(contentsOf: pageItems)
            guard pageItems.count == 100 else { break }
            page += 1
        }

        return all
            .filter(\.isRunningActivity)
            .map { $0.toDomain() }
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
        try await postTokens(params: [
            "client_id":     Secrets.stravaClientID,
            "client_secret": Secrets.stravaClientSecret,
            "code":          code,
            "grant_type":    "authorization_code",
        ])
    }

    private func refreshTokens(refreshToken: String) async throws -> TokenResponse {
        try await postTokens(params: [
            "client_id":     Secrets.stravaClientID,
            "client_secret": Secrets.stravaClientSecret,
            "refresh_token": refreshToken,
            "grant_type":    "refresh_token",
        ])
    }

    private func postTokens(params: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            RunBarLog.strava.error("token endpoint failed: HTTP \(code) — \(String(data: data, encoding: .utf8) ?? "")")
            throw StravaError.httpStatus(code)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
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
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:    return "Connexion Strava à venir."
        case .missingConfiguration:
            return "Configuration Strava manquante. Définis RUNBAR_STRAVA_CLIENT_ID et RUNBAR_STRAVA_CLIENT_SECRET."
        case .notAuthenticated:  return "Pas connecté à Strava."
        case .oauthFailed:       return "Échec de l'autorisation."
        case .oauthTimeout:      return "Connexion Strava expirée."
        case .invalidOAuthState: return "Réponse OAuth invalide."
        case .httpStatus(let c): return "Erreur serveur (HTTP \(c))."
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
