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

    func test_reconcile_removes_missing_source_items_since_date() {
        let store = ActivityStore()
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
