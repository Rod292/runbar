import XCTest
@testable import RunBar

final class GoalCalculatorTests: XCTestCase {
    let calc = GoalCalculator()

    func test_progress_distance_returns_correct_ratio() {
        let goal = WeeklyGoal(metric: .distance, target: 60)
        let activities = [
            seedActivity(km: 10),
            seedActivity(km: 12),
            seedActivity(km: 8),
        ]
        XCTAssertEqual(calc.progress(activities: activities, goal: goal), 0.5, accuracy: 0.001)
    }

    func test_progress_count_caps_at_1() {
        let goal = WeeklyGoal(metric: .count, target: 3)
        let activities = (0..<10).map { _ in seedActivity(km: 5) }
        XCTAssertEqual(calc.progress(activities: activities, goal: goal), 1.0)
    }

    func test_progress_elevation_sums() {
        let goal = WeeklyGoal(metric: .elevation, target: 1000)
        let activities = [
            seedActivity(km: 5, elev: 300),
            seedActivity(km: 8, elev: 450),
        ]
        XCTAssertEqual(calc.progress(activities: activities, goal: goal), 0.75, accuracy: 0.001)
    }

    func test_runnerState_returns_victory_when_complete() {
        XCTAssertEqual(calc.runnerState(progress: 1.0, dayOfWeek: 3), .victory)
        XCTAssertEqual(calc.runnerState(progress: 1.5, dayOfWeek: 1), .victory)
    }

    func test_runnerState_returns_tired_when_late_in_week() {
        XCTAssertEqual(calc.runnerState(progress: 0.2, dayOfWeek: 5), .tired)
        XCTAssertEqual(calc.runnerState(progress: 0.39, dayOfWeek: 4), .tired)
    }

    func test_runnerState_returns_idle_when_zero() {
        XCTAssertEqual(calc.runnerState(progress: 0, dayOfWeek: 1), .idle)
    }

    func test_runnerState_returns_sprinting_after_recent_sync() {
        let state = calc.runnerState(progress: 0.5, dayOfWeek: 3, lastSyncRecency: 60)
        XCTAssertEqual(state, .sprinting)
    }

    func test_runnerState_jogging_default() {
        XCTAssertEqual(calc.runnerState(progress: 0.5, dayOfWeek: 2), .jogging)
    }

    func test_weekStart_handles_monday_reset() {
        // 2026-05-04 (lundi) doit être start of week
        let formatter = ISO8601DateFormatter()
        let monday = formatter.date(from: "2026-05-04T10:30:00Z")!
        let start = monday.startOfWeek()
        let cal = Calendar.iso8601Monday
        XCTAssertEqual(cal.component(.weekday, from: start), 2) // Monday in Calendar = 2
    }

    private func seedActivity(km: Double, elev: Double = 50) -> Activity {
        Activity(
            id: UUID().uuidString,
            name: "Run",
            distance: km * 1000,
            movingTime: Int(km * 300),
            elevationGain: elev,
            startDate: .now,
            type: "Run",
            source: .seed
        )
    }
}

@MainActor
final class StreakCalculatorTests: XCTestCase {
    func test_streak_counts_consecutive_completed_weeks() {
        let cal = Calendar.iso8601Monday
        let now = Date.now
        let thisMonday = now.startOfWeek()
        let snapshots = (0..<5).compactMap { i -> WeeklySnapshot? in
            guard let monday = cal.date(byAdding: .day, value: -i * 7, to: thisMonday) else { return nil }
            return WeeklySnapshot(weekStart: monday, metric: .distance, target: 60, achieved: 60)
        }
        XCTAssertEqual(StreakCalculator.current(snapshots: snapshots), 5)
    }

    func test_streak_breaks_on_incomplete_week() {
        let cal = Calendar.iso8601Monday
        let now = Date.now
        let thisMonday = now.startOfWeek()
        let snapshots: [WeeklySnapshot] = (0..<5).compactMap { i in
            guard let monday = cal.date(byAdding: .day, value: -i * 7, to: thisMonday) else { return nil }
            let achieved: Double = (i == 2) ? 30 : 60
            return WeeklySnapshot(weekStart: monday, metric: .distance, target: 60, achieved: achieved)
        }
        XCTAssertEqual(StreakCalculator.current(snapshots: snapshots), 2)
    }

    func test_streak_zero_when_current_week_incomplete_and_last_incomplete() {
        let cal = Calendar.iso8601Monday
        let now = Date.now
        let thisMonday = now.startOfWeek()
        let lastMonday = cal.date(byAdding: .day, value: -7, to: thisMonday)!
        let snapshots = [
            WeeklySnapshot(weekStart: thisMonday, metric: .distance, target: 60, achieved: 20),
            WeeklySnapshot(weekStart: lastMonday, metric: .distance, target: 60, achieved: 30),
        ]
        XCTAssertEqual(StreakCalculator.current(snapshots: snapshots), 0)
    }
}
