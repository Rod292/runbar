import XCTest
@testable import RunBar

/// Provider factice — compte les appels pour vérifier que le gating
/// conformité (Strava API Policy § 5.3) empêche toute génération.
private final class SpyProvider: AICoachProvider, @unchecked Sendable {
    let id = "spy"
    let displayName = "Spy"
    private(set) var callCount = 0

    func generate(context: CoachContext, apiKey: String) async throws -> String {
        callCount += 1
        return "ok"
    }
}

@MainActor
final class CoachServicePolicyTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "runbar.tests.coach")!
        defaults.removePersistentDomain(forName: "runbar.tests.coach")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "runbar.tests.coach")
    }

    private func makeService(
        activities: [ActivityDTO],
        provider: SpyProvider = SpyProvider()
    ) -> (CoachService, ActivityStore) {
        let store = ActivityStore(inMemory: true)
        store.clear() // retire les seeds DEBUG éventuels
        store.upsert(activities)
        let config = CoachConfiguration(defaults: defaults)
        config.enabled = true
        config.hasKey = true
        let service = CoachService(
            store: store,
            snapshots: nil,
            configuration: config,
            provider: provider,
            defaults: defaults
        )
        return (service, store)
    }

    private func dto(id: String, source: ActivitySource) -> ActivityDTO {
        ActivityDTO(
            id: id, name: "Run", distance: 10_000, movingTime: 3000,
            elevationGain: 50, startDate: .now, type: "Run", source: source
        )
    }

    func test_blocked_when_any_strava_activity_present() {
        let (service, _) = makeService(activities: [
            dto(id: "a", source: .seed),
            dto(id: "b", source: .strava),
        ])
        XCTAssertTrue(service.blockedByStravaPolicy)
    }

    func test_not_blocked_without_strava_data() {
        let (service, _) = makeService(activities: [dto(id: "a", source: .seed)])
        XCTAssertFalse(service.blockedByStravaPolicy)
    }

    func test_refreshIfDue_clears_cached_message_when_blocked() throws {
        // Pré-seed un message en cache (généré avant le blocage).
        let cached = CoachMessage(
            text: "old", providerLabel: "Spy",
            generatedAt: .now, contextHash: "x"
        )
        defaults.set(try JSONEncoder().encode(cached), forKey: "runbar.coach.lastMessage.v1")

        let (service, _) = makeService(activities: [dto(id: "b", source: .strava)])
        XCTAssertNotNil(service.current, "le cache doit être chargé à l'init")

        service.refreshIfDue()
        XCTAssertNil(service.current, "un message dérivé de données Strava doit être purgé")
        XCTAssertNil(defaults.data(forKey: "runbar.coach.lastMessage.v1"))
    }

    func test_forceRefresh_never_calls_provider_when_blocked() {
        let spy = SpyProvider()
        let (service, _) = makeService(
            activities: [dto(id: "b", source: .strava)],
            provider: spy
        )
        service.forceRefresh()
        XCTAssertEqual(spy.callCount, 0)
    }
}
