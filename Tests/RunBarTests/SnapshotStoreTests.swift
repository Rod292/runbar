import XCTest
@testable import RunBar

@MainActor
final class SnapshotStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SnapshotStore!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "runbar.tests.snapshots")!
        defaults.removePersistentDomain(forName: "runbar.tests.snapshots")
        store = SnapshotStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "runbar.tests.snapshots")
    }

    private func monday(weeksAgo: Int) -> Date {
        let thisMonday = Date.now.startOfWeek()
        return Calendar.iso8601Monday.date(byAdding: .day, value: -7 * weeksAgo, to: thisMonday)!
    }

    func test_record_creates_then_overwrites_same_week() {
        let week = monday(weeksAgo: 1)
        store.record(weekStart: week, metric: .distance, target: 40, achieved: 20)
        store.record(weekStart: week, metric: .distance, target: 40, achieved: 35)
        XCTAssertEqual(store.snapshots.count, 1)
        XCTAssertEqual(store.snapshot(for: week)?.achieved, 35)
    }

    func test_snapshot_for_returns_nil_when_absent() {
        store.record(weekStart: monday(weeksAgo: 1), metric: .distance, target: 40, achieved: 20)
        XCTAssertNil(store.snapshot(for: monday(weeksAgo: 2)))
    }

    func test_snapshots_persist_across_instances() {
        let week = monday(weeksAgo: 1)
        store.record(weekStart: week, metric: .count, target: 4, achieved: 4)
        let reloaded = SnapshotStore(defaults: defaults)
        XCTAssertEqual(reloaded.snapshot(for: week)?.metric, .count)
        XCTAssertEqual(reloaded.snapshot(for: week)?.achieved, 4)
    }

    /// Le point de la correction : un snapshot d'une autre métrique garde son
    /// `completed` calculé sur SA cible — le streak reste juste après un
    /// changement de métrique. La semaine courante (en cours, pas encore
    /// complétée) est présente comme en production (`recordCurrentWeek()`).
    func test_streak_survives_metric_change() {
        // 3 semaines complétées : 2 en distance, la plus récente en count.
        store.record(weekStart: monday(weeksAgo: 3), metric: .distance, target: 40, achieved: 45)
        store.record(weekStart: monday(weeksAgo: 2), metric: .distance, target: 40, achieved: 41)
        store.record(weekStart: monday(weeksAgo: 1), metric: .count, target: 3, achieved: 3)
        store.record(weekStart: monday(weeksAgo: 0), metric: .count, target: 3, achieved: 1)
        XCTAssertEqual(store.currentStreak, 3)
    }

    func test_clear_wipes_storage() {
        store.record(weekStart: monday(weeksAgo: 1), metric: .distance, target: 40, achieved: 20)
        store.clear()
        XCTAssertTrue(store.snapshots.isEmpty)
        XCTAssertTrue(SnapshotStore(defaults: defaults).snapshots.isEmpty)
    }
}
