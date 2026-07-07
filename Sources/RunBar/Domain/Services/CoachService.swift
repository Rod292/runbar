import Combine
import Foundation
import Logging

/// Orchestre la génération de messages coach.
///
/// Stratégie de cache :
/// - On regénère uniquement si le hash du contexte a changé OU si plus de
///   `maxAge` s'est écoulé depuis le dernier message.
/// - Trigger : à chaque sync terminée, le service regarde si un nouveau
///   message est dû. Pas d'appel à l'ouverture du popover.
@MainActor
public final class CoachService: ObservableObject {
    @Published public private(set) var current: CoachMessage?
    @Published public private(set) var isFetching: Bool = false
    @Published public private(set) var lastError: String?

    /// Durée minimum entre deux régénérations même si le contexte a changé.
    public var maxAge: TimeInterval = 6 * 3600

    private let store: ActivityStore
    private let snapshots: SnapshotStore?
    private let configuration: CoachConfiguration
    private let provider: AICoachProvider
    private let builder = CoachContextBuilder()
    private let defaults: UserDefaults
    private let cacheKey = "runbar.coach.lastMessage.v1"

    public init(
        store: ActivityStore,
        snapshots: SnapshotStore?,
        configuration: CoachConfiguration,
        provider: AICoachProvider = GeminiCoachProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.snapshots = snapshots
        self.configuration = configuration
        self.provider = provider
        self.defaults = defaults
        self.current = loadCached()
    }

    /// Conformité Strava API Policy §5.3 (effective 2026-06-01) : les données
    /// issues de l'API Strava ne peuvent alimenter aucune "AI Application",
    /// directement ou indirectement — et la review Extended Access refuse
    /// explicitement les apps exposant des données athlète à des outils IA
    /// tiers. Le coach ne génère donc que si AUCUNE activité du store ne
    /// provient de Strava. Il se réactivera avec une source conforme
    /// (Apple Health prévu) sans changement de code ici.
    public var blockedByStravaPolicy: Bool {
        store.activities.contains { $0.source == .strava }
    }

    /// Doit être appelée après chaque sync. Décide si on régénère.
    public func refreshIfDue(now: Date = .now) {
        guard configuration.enabled, configuration.hasKey else { return }
        guard !blockedByStravaPolicy else {
            // On efface aussi le message en cache : il a été dérivé de
            // données Strava et ne doit pas continuer à s'afficher.
            if current != nil { setCurrent(nil) }
            return
        }
        let ctx = currentContext(now: now)
        let hash = Self.hash(of: ctx)

        if let m = current, m.contextHash == hash, now.timeIntervalSince(m.generatedAt) < maxAge {
            return
        }
        generate(context: ctx, hash: hash, now: now)
    }

    /// Force une régénération (bouton refresh dans le popover).
    public func forceRefresh(now: Date = .now) {
        guard configuration.enabled, configuration.hasKey else { return }
        guard !blockedByStravaPolicy else { return }
        let ctx = currentContext(now: now)
        let hash = Self.hash(of: ctx)
        generate(context: ctx, hash: hash, now: now)
    }

    /// Effacement local — n'efface pas la clé Keychain.
    public func dismiss() {
        setCurrent(nil)
    }

    /// Test de bout en bout pour la connexion (Settings/onboarding).
    /// Utilise un contexte d'exemple, jamais les vraies données : valider une
    /// clé ne doit envoyer aucune donnée d'activité au provider (et doit
    /// marcher aussi quand le coach est bloqué par la policy Strava).
    public func test(apiKey: String, now: Date = .now) async throws -> String {
        try await provider.generate(context: Self.sampleContext, apiKey: apiKey)
    }

    static let sampleContext = CoachContext(
        unit: UnitPreferences.current.rawValue,
        weekDistance: 23.4,
        weekRuns: 3,
        weekElevationM: 240,
        targetDistance: 35,
        progressPct: 67,
        daysLeftInWeek: 3,
        last4WeeksDistance: [28.0, 31.5, 25.0, 33.2],
        streakWeeks: 2,
        race: nil
    )

    // MARK: Private

    /// Deadline dure au-delà du timeout réseau du provider : si la réponse
    /// arrive au goutte-à-goutte, `timeoutInterval` ne suffit pas et le
    /// spinner du popover tournerait indéfiniment.
    private static let generationDeadline: TimeInterval = 30

    private func generate(context: CoachContext, hash: String, now: Date) {
        guard let key = configuration.currentKey() else { return }
        let provider = self.provider
        isFetching = true
        lastError = nil
        Task { [weak self] in
            do {
                let text = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        try await provider.generate(context: context, apiKey: key)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(Self.generationDeadline * 1_000_000_000))
                        throw CoachProviderError.timeout
                    }
                    guard let first = try await group.next() else { throw CoachProviderError.empty }
                    group.cancelAll()
                    return first
                }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let msg = CoachMessage(
                        text: text,
                        providerLabel: provider.displayName,
                        generatedAt: now,
                        contextHash: hash
                    )
                    self.setCurrent(msg)
                    self.isFetching = false
                }
            } catch {
                RunBarLog.app.error("Coach generation failed: \(error.localizedDescription)")
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.isFetching = false
                }
            }
        }
    }

    private func currentContext(now: Date) -> CoachContext {
        builder.build(
            activities: store.activities,
            goal: store.goal,
            streakWeeks: snapshots?.currentStreak(weekStartingOn: store.goal.resetWeekday) ?? 0,
            now: now
        )
    }

    private func setCurrent(_ value: CoachMessage?) {
        current = value
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: cacheKey)
        } else {
            defaults.removeObject(forKey: cacheKey)
        }
    }

    private func loadCached() -> CoachMessage? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CoachMessage.self, from: data)
    }

    /// Hash stable et court (FNV-1a 32-bit) — suffisant pour invalider le cache.
    static func hash(of context: CoachContext) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(context) else { return "" }
        var h: UInt32 = 0x811c9dc5
        for byte in data {
            h ^= UInt32(byte)
            h = h &* 0x01000193
        }
        return String(h, radix: 16)
    }
}
