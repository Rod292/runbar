import XCTest
@testable import RunBar

@MainActor
final class ActivityStoreTests: XCTestCase {
    func test_upsert_dedup_avoids_duplicates() {
        let store = ActivityStore()
        store.clear()
        let a = ActivityDTO(id: "x", name: "Run", distance: 5000, movingTime: 1500,
                            elevationGain: 0, startDate: .now, type: "Run", source: .strava)
        store.upsert([a, a])
        XCTAssertEqual(store.activities.count, 1)
    }

    func test_upsert_updates_existing() {
        let store = ActivityStore()
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
}
