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

    /// Doit être appelée après chaque sync. Décide si on régénère.
    public func refreshIfDue(now: Date = .now) {
        guard configuration.enabled, configuration.hasKey else { return }
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
        let ctx = currentContext(now: now)
        let hash = Self.hash(of: ctx)
        generate(context: ctx, hash: hash, now: now)
    }

    /// Effacement local — n'efface pas la clé Keychain.
    public func dismiss() {
        setCurrent(nil)
    }

    /// Test de bout en bout pour la connexion (Settings/onboarding).
    public func test(apiKey: String, now: Date = .now) async throws -> String {
        let ctx = currentContext(now: now)
        return try await provider.generate(context: ctx, apiKey: apiKey)
    }

    // MARK: Private

    private func generate(context: CoachContext, hash: String, now: Date) {
        guard let key = configuration.currentKey() else { return }
        let provider = self.provider
        isFetching = true
        lastError = nil
        Task { [weak self] in
            do {
                let text = try await provider.generate(context: context, apiKey: key)
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
            streakWeeks: snapshots?.currentStreak ?? 0,
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
