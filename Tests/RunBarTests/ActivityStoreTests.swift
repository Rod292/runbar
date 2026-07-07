import XCTest
@testable import RunBar

@MainActor
final class ActivityStoreTests: XCTestCase {
    func test_upsert_dedup_avoids_duplicates() {
        let store = ActivityStore(inMemory: true)
        store.clear()
        let a = ActivityDTO(id: "x", name: "Run", distance: 5000, movingTime: 1500,
                            elevationGain: 0, startDate: .now, type: "Run", source: .strava)
        store.upsert([a, a])
        XCTAssertEqual(store.activities.count, 1)
    }

    func test_upsert_updates_existing() {
        let store = ActivityStore(inMemory: true)
        store.clear()
        let a = ActivityDTO(id: "x", name: "Run", distance: 5000, movingTime: 1500,
                            elevationGain: 0, startDate: .now, type: "Run", source: .strava)
        store.upsert([a])
        let updated = ActivityDTO(id: "x", name: "Run renamed", distance: 6000, movingTime: 1800,
                                  elevationGain: 0, startDate: .now, type: "Run", source: .strava)
        store.upsert([updated])
        XCTAssertEqual(store.activities.count, 1)
        XCTAssertEqual(store.activities.first?.name, "Run renamed")
        XCTAssertEqual(store.activities.first?.distance, 6000)
    }

    func test_reconcile_removes_missing_source_items_since_date() {
        let store = ActivityStore(inMemory: true)
        store.clear()
        let monday = Date.now.startOfWeek()
        let keep = ActivityDTO(id: "keep", name: "Run", distance: 5000, movingTime: 1500,
                               elevationGain: 0, startDate: monday, type: "Run", source: .strava)
        let removed = ActivityDTO(id: "removed", name: "Old Run", distance: 6000, movingTime: 1800,
                                  elevationGain: 0, startDate: monday, type: "Run", source: .strava)
        let manual = ActivityDTO(id: "manual", name: "Manual", distance: 3000, movingTime: 1000,
                                 elevationGain: 0, startDate: monday, type: "Run", source: .manual)

        store.upsert([keep, removed, manual])
        store.reconcile(source: .strava, since: monday, with: [keep])

        XCTAssertEqual(Set(store.activities.map(\.id)), ["keep", "manual"])
    }
}

// MARK: - Décodage des erreurs API Strava

final class StravaAPIErrorDecodingTests: XCTestCase {
    func test_application_inactive_is_surfaced() {
        let body = Data(#"{"message":"Forbidden","errors":[{"resource":"Application","field":"Status","code":"Inactive"}]}"#.utf8)
        guard case .applicationInactive = StravaService.decodeAPIError(status: 403, body: body) else {
            return XCTFail("expected .applicationInactive")
        }
    }

    func test_unknown_error_falls_back_to_status() {
        let body = Data(#"{"message":"Weird"}"#.utf8)
        guard case .httpStatus(503) = StravaService.decodeAPIError(status: 503, body: body) else {
            return XCTFail("expected .httpStatus(503)")
        }
    }

    func test_invalid_token_maps_to_not_authenticated() {
        let body = Data(#"{"message":"Authorization Error","errors":[{"resource":"Athlete","field":"access_token","code":"invalid"}]}"#.utf8)
        guard case .notAuthenticated = StravaService.decodeAPIError(status: 401, body: body) else {
            return XCTFail("expected .notAuthenticated")
        }
    }
}
