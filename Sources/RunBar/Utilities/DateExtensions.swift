import Foundation

public extension Date {
    /// Premier jour de la semaine ISO (lundi par défaut), à 00:00 dans la timezone locale.
    func startOfWeek(weekday firstWeekday: Int = 2, calendar: Calendar = .iso8601Monday) -> Date {
        var cal = calendar
        cal.firstWeekday = firstWeekday
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }

    /// Dernier instant de la semaine (lundi 00:00 → dimanche 23:59:59.999).
    func endOfWeek(weekday firstWeekday: Int = 2, calendar: Calendar = .iso8601Monday) -> Date {
        let start = startOfWeek(weekday: firstWeekday, calendar: calendar)
        return calendar.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-0.001) ?? self
    }

    /// Numéro de semaine ISO (1...53).
    func isoWeekOfYear(calendar: Calendar = .iso8601Monday) -> Int {
        calendar.component(.weekOfYear, from: self)
    }

    /// Numéro de semaine aligné sur le jour de reset de l'utilisateur.
    /// Avec `weekday: 1` (dimanche), le dimanche 28/06 est bien étiqueté
    /// comme la semaine qu'il OUVRE — `isoWeekOfYear` (lundi) l'aurait
    /// rattaché à la semaine précédente.
    func weekNumber(weekday firstWeekday: Int = 2, calendar: Calendar = .iso8601Monday) -> Int {
        var cal = calendar
        cal.firstWeekday = firstWeekday
        cal.timeZone = .current
        return cal.component(.weekOfYear, from: self)
    }

    /// 1 = lundi ... 7 = dimanche (convention plan).
    func dayOfWeek(calendar: Calendar = .iso8601Monday) -> Int {
        let raw = calendar.component(.weekday, from: self) // 1=Sun ... 7=Sat
        return ((raw + 5) % 7) + 1
    }
}
