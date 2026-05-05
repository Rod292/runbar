import Combine
import Foundation

/// Configuration utilisateur du coach. Une seule clé active à la fois ; le
/// provider sélectionné détermine quelle implémentation `AICoachProvider`
/// est utilisée par `CoachService`.
@MainActor
public final class CoachConfiguration: ObservableObject {
    public static let coachKeychainService = "com.rodrigue.runbar.coach"

    public enum Provider: String, CaseIterable, Codable, Sendable {
        case gemini

        public var displayName: String {
            switch self {
            case .gemini: return "Gemini 2.5 Flash Lite"
            }
        }

        public var keychainAccount: String { "apiKey.\(rawValue)" }

        /// URL où l'utilisateur peut récupérer une clé. Affichée dans Settings.
        public var apiKeyURL: URL {
            switch self {
            case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
            }
        }
    }

    @Published public var enabled: Bool {
        didSet { defaults.set(enabled, forKey: enabledKey) }
    }
    @Published public var provider: Provider {
        didSet { defaults.set(provider.rawValue, forKey: providerKey) }
    }
    @Published public var hasKey: Bool

    private let defaults: UserDefaults
    private let enabledKey = "runbar.coach.enabled.v1"
    private let providerKey = "runbar.coach.provider.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabled = defaults.bool(forKey: enabledKey)
        let raw = defaults.string(forKey: providerKey) ?? Provider.gemini.rawValue
        self.provider = Provider(rawValue: raw) ?? .gemini
        let initialProvider = Provider(rawValue: raw) ?? .gemini
        self.hasKey = (Keychain.get(
            account: initialProvider.keychainAccount,
            service: Self.coachKeychainService
        ) ?? "").isEmpty == false
    }

    public func currentKey() -> String? {
        let v = Keychain.get(account: provider.keychainAccount, service: Self.coachKeychainService)
        return (v?.isEmpty == false) ? v : nil
    }

    public func setKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Keychain.remove(account: provider.keychainAccount, service: Self.coachKeychainService)
            hasKey = false
        } else {
            try Keychain.set(trimmed, account: provider.keychainAccount, service: Self.coachKeychainService)
            hasKey = true
        }
    }

    public func clearKey() {
        Keychain.remove(account: provider.keychainAccount, service: Self.coachKeychainService)
        hasKey = false
    }
}
