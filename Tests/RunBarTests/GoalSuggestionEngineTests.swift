import XCTest
@testable import RunBar

final class GoalSuggestionEngineTests: XCTestCase {
    let engine = GoalSuggestionEngine()
    // Référence : un mardi (mid-week), pour que les "4 dernières semaines complètes"
    // soient bien les 4 semaines précédant le lundi courant.
    let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 5; c.hour = 12
        return Calendar(identifier: .iso8601).date(from: c)!
    }()

    // MARK: Hausse normale

    func test_increase_when_avg_above_target() {
        // Target 30, avg 38 → bumped 41.8, cap +20% = 36 → min = 36 → ceil/5 = 40.
        let acts = weeklyActivities(weeks: [38, 38, 38, 38], anchor: now)
        let goal = WeeklyGoal(metric: .distance, target: 30)
        let s = engine.evaluate(activities: acts, goal: goal, now: now)
        XCTAssertEqual(s?.direction, .increase)
        XCTAssertEqual(s?.suggestedTarget, 40)
    }

    func test_increase_capped_to_plus_20_percent() {
        // Avg 60 km, target 20 km. Hausse théorique = 66, mais cap = 24 → arrondi 25.
        let acts = weeklyActivities(weeks: [60, 60, 60, 60], anchor: now)
        let goal = WeeklyGoal(metric: .distance, target: 20)
        let s = engine.evaluate(activities: acts, goal: goal, now: now)
        XCTAssertEqual(s?.direction, .increase)
        XCTAssertEqual(s?.suggestedTarget, 25) // ceil(24/5)*5 = 25
    }

    // MARK: Baisse quand sous-perform

    func test_decrease_when_user_underperforms() {
        // Target 60 km, mais l'utilisateur fait 30/30/35/30 → ratio < 70% sur les 4.
        // Avg = 31.25 → ceil(31.25/5)*5 = 35 km suggéré.
        let acts = weeklyActivities(weeks: [30, 30, 35, 30], anchor: now)
        let goal = WeeklyGoal(metric: .distance, target: 60)
        let s = engine.evaluate(activities: acts, goal: goal, now: now)
        XCTAssertEqual(s?.direction, .decrease)
        XCTAssertEqual(s?.suggestedTarget, 35)
    }

    // MARK: Pas de suggestion

    func test_no_suggestion_when_delta_too_small() {
        // Target 35 km, avg = 35. Hausse = 38.5 → ceil/5 = 40, delta = 5 mais
        // ratio = 5/35 = 14% > 10% → suggestion légitime. À ajuster pour < 10%.
        // Construit un cas où delta absolu = 5 mais target = 60 → ratio < 10%.
        // avg 56 → ceil(56*1.1/5)*5 = 65, delta 5/60 = 8.3% < 10% → nil.
        let acts = weeklyActivities(weeks: [56, 56, 56, 56], anchor: now)
        let goal = WeeklyGoal(metric: .distance, target: 60)
        let s = engine.evaluate(activities: acts, goal: goal, now: now)
        XCTAssertNil(s)
    }

    func test_no_suggestion_when_metric_is_count() {
        let acts = weeklyActivities(weeks: [40, 40, 40, 40], anchor: now)
        let goal = WeeklyGoal(metric: .count, target: 4)
        XCTAssertNil(engine.evaluate(activities: acts, goal: goal, now: now))
    }

    func test_no_suggestion_when_avg_below_minimum() {
        // Avg < 5 km/sem → engine refuse (utilisateur quasi inactif).
        let acts = weeklyActivities(weeks: [3, 4, 2, 4], anchor: now)
        let goal = WeeklyGoal(metric: .distance, target: 30)
        XCTAssertNil(engine.evaluate(activities: acts, goal: goal, now: now))
    }

    func test_no_suggestion_when_no_activities() {
        let goal = WeeklyGoal(metric: .distance, target: 30)
        XCTAssertNil(engine.evaluate(activities: [], goal: goal, now: now))
    }

    // MARK: Helpers

    private func weeklyActivities(weeks: [Double], anchor: Date) -> [Activity] {
        let cal = Calendar.iso8601Monday
        let thisMonday = anchor.startOfWeek()
        var out: [Activity] = []
        for (i, km) in weeks.enumerated() {
            let weekStart = cal.date(byAdding: .day, value: -7 * (i + 1), to: thisMonday)!
            let mid = cal.date(byAdding: .day, value: 3, to: weekStart)!
            out.append(Activity(
                id: "w\(i)",
                name: "Run",
                distance: km * 1000,
                movingTime: Int(km * 300),
                elevationGain: 50,
                startDate: mid,
                type: "Run",
                source: .seed
            ))
        }
        return out
    }
}
