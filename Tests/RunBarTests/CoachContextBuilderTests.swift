import XCTest
@testable import RunBar

@MainActor
final class CoachContextBuilderTests: XCTestCase {
    let builder = CoachContextBuilder()
    let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 5; c.hour = 12 // mardi
        return Calendar(identifier: .iso8601).date(from: c)!
    }()

    func test_empty_week_produces_zeros() {
        let goal = WeeklyGoal(metric: .distance, target: 40)
        let ctx = builder.build(activities: [], goal: goal, streakWeeks: 0, unit: .km, now: now)
        XCTAssertEqual(ctx.unit, "km")
        XCTAssertEqual(ctx.weekDistance, 0)
        XCTAssertEqual(ctx.weekRuns, 0)
        XCTAssertEqual(ctx.targetDistance, 40)
        XCTAssertEqual(ctx.progressPct, 0)
        XCTAssertEqual(ctx.last4WeeksDistance.count, 4)
        XCTAssertEqual(ctx.last4WeeksDistance, [0, 0, 0, 0])
        XCTAssertNil(ctx.race)
    }

    func test_aggregates_only_current_week() {
        let cal = Calendar.iso8601Monday
        let monday = now.startOfWeek()
        let lastWeek = cal.date(byAdding: .day, value: -3, to: monday)!
        let inThisWeek = cal.date(byAdding: .hour, value: 30, to: monday)!
        let acts = [
            seedActivity(km: 8, at: inThisWeek),
            seedActivity(km: 12, at: inThisWeek),
            seedActivity(km: 50, at: lastWeek), // ne doit pas compter
        ]
        let goal = WeeklyGoal(metric: .distance, target: 40)
        let ctx = builder.build(activities: acts, goal: goal, streakWeeks: 3, unit: .km, now: now)
        XCTAssertEqual(ctx.weekDistance, 20)
        XCTAssertEqual(ctx.weekRuns, 2)
        XCTAssertEqual(ctx.progressPct, 50)
        XCTAssertEqual(ctx.streakWeeks, 3)
    }

    func test_miles_unit_converts_distances_but_not_progress() {
        let monday = now.startOfWeek()
        let inThisWeek = Calendar.iso8601Monday.date(byAdding: .hour, value: 30, to: monday)!
        let acts = [seedActivity(km: 20, at: inThisWeek)]
        let goal = WeeklyGoal(metric: .distance, target: 40)
        let ctx = builder.build(activities: acts, goal: goal, streakWeeks: 0, unit: .mi, now: now)
        XCTAssertEqual(ctx.unit, "mi")
        XCTAssertEqual(ctx.weekDistance, 12.4, accuracy: 0.01)   // 20 km
        XCTAssertEqual(ctx.targetDistance, 24.9, accuracy: 0.01) // 40 km
        // La progression reste calculée en km : 20/40 = 50 %.
        XCTAssertEqual(ctx.progressPct, 50)
    }

    func test_race_context_when_within_30_days() {
        let raceDate = Calendar.iso8601Monday.date(byAdding: .day, value: 14, to: now)!
        var goal = WeeklyGoal(metric: .distance, target: 40)
        goal.raceDate = raceDate
        goal.raceName = "London"
        let ctx = builder.build(activities: [], goal: goal, streakWeeks: 0, unit: .km, now: now)
        XCTAssertEqual(ctx.race?.name, "London")
        XCTAssertEqual(ctx.race?.daysUntil, 14)
    }

    func test_no_race_when_passed() {
        let raceDate = Calendar.iso8601Monday.date(byAdding: .day, value: -5, to: now)!
        var goal = WeeklyGoal(metric: .distance, target: 40)
        goal.raceDate = raceDate
        let ctx = builder.build(activities: [], goal: goal, streakWeeks: 0, unit: .km, now: now)
        XCTAssertNil(ctx.race)
    }

    private func seedActivity(km: Double, at date: Date) -> Activity {
        Activity(
            id: UUID().uuidString,
            name: "Run",
            distance: km * 1000,
            movingTime: Int(km * 300),
            elevationGain: 50,
            startDate: date,
            type: "Run",
            source: .seed
        )
    }
}

final class GeminiCoachProviderParserTests: XCTestCase {
    func test_extracts_text_from_well_formed_response() throws {
        let json = """
        {"candidates":[{"content":{"parts":[{"text":"Steady week.\\nKeep building."}]}}]}
        """
        let text = try GeminiCoachProvider.extractText(from: Data(json.utf8))
        XCTAssertEqual(text, "Steady week.\nKeep building.")
    }

    func test_concatenates_multiple_parts() throws {
        let json = """
        {"candidates":[{"content":{"parts":[{"text":"Hello "},{"text":"there."}]}}]}
        """
        let text = try GeminiCoachProvider.extractText(from: Data(json.utf8))
        XCTAssertEqual(text, "Hello there.")
    }

    func test_throws_on_missing_candidates() {
        let json = "{}"
        XCTAssertThrowsError(try GeminiCoachProvider.extractText(from: Data(json.utf8)))
    }

    func test_throws_on_empty_text() {
        let json = """
        {"candidates":[{"content":{"parts":[{"text":"   "}]}}]}
        """
        XCTAssertThrowsError(try GeminiCoachProvider.extractText(from: Data(json.utf8))) { err in
            guard case CoachProviderError.empty = err else {
                return XCTFail("expected .empty, got \(err)")
            }
        }
    }
}
