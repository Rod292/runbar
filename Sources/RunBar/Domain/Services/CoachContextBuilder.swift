import Foundation

/// Construit le `CoachContext` à partir du store + goal courants.
public struct CoachContextBuilder {
    public init() {}

    public func build(
        activities: [Activity],
        goal: WeeklyGoal,
        streakWeeks: Int,
        now: Date = .now
    ) -> CoachContext {
        let cal = Calendar.iso8601Monday
        let thisMonday = now.startOfWeek(weekday: goal.resetWeekday, calendar: cal)
        let nextMonday = cal.date(byAdding: .day, value: 7, to: thisMonday) ?? thisMonday

        let week = activities.filter { $0.startDate >= thisMonday && $0.startDate < nextMonday }
        let weekKm = week.reduce(0) { $0 + $1.distanceKm }
        let weekElev = week.reduce(0) { $0 + $1.elevationGain }
        let weekRuns = week.count

        let progress = goal.target > 0 ? min(1.0, weekKm / goal.target) : 0
        let pct = Int((progress * 100).rounded())
        let daysLeft = Self.daysLeftInWeek(now: now)

        var last4: [Double] = []
        for i in 1...4 {
            guard
                let start = cal.date(byAdding: .day, value: -7 * i, to: thisMonday),
                let end = cal.date(byAdding: .day, value: 7, to: start)
            else { continue }
            let km = activities
                .filter { $0.startDate >= start && $0.startDate < end }
                .reduce(0.0) { $0 + $1.distanceKm }
            last4.append(km)
        }

        var raceCtx: CoachContext.RaceContext?
        if let raceDate = goal.raceDate, let days = goal.daysUntilRace(now: now), days >= 0 {
            let name = goal.raceName?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "your race"
            _ = raceDate
            raceCtx = CoachContext.RaceContext(name: name, daysUntil: days)
        }

        return CoachContext(
            weekKm: weekKm.rounded(toPlaces: 1),
            weekRuns: weekRuns,
            weekElevationM: weekElev.rounded(),
            targetKm: goal.target,
            progressPct: pct,
            daysLeftInWeek: daysLeft,
            last4WeeksKm: last4.map { $0.rounded(toPlaces: 1) },
            streakWeeks: streakWeeks,
            race: raceCtx
        )
    }

    private static func daysLeftInWeek(now: Date) -> Int {
        let cal = Calendar.iso8601Monday
        let weekday = cal.component(.weekday, from: now) // 1=Sun..7=Sat
        let mondayWeekday = (weekday + 5) % 7 // 0=Mon..6=Sun
        return max(0, 6 - mondayWeekday)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
