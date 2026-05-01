import Foundation
import SwiftData

/// Une sortie. Source agnostique (Strava, Apple Health, manuel).
/// SwiftData @Model — persiste sur disque via le ModelContainer du container.
@Model
public final class Activity {
    @Attribute(.unique) public var id: String
    public var name: String
    /// Distance en mètres (convention API Strava).
    public var distance: Double
    /// Durée en mouvement en secondes.
    public var movingTime: Int
    /// Dénivelé positif en mètres.
    public var elevationGain: Double
    public var startDate: Date
    /// "Run", "TrailRun", "VirtualRun" — provenant de l'API source.
    public var type: String
    public var sourceRaw: String

    public var source: ActivitySource {
        get { ActivitySource(rawValue: sourceRaw) ?? .strava }
        set { sourceRaw = newValue.rawValue }
    }

    public init(
        id: String,
        name: String,
        distance: Double,
        movingTime: Int,
        elevationGain: Double,
        startDate: Date,
        type: String,
        source: ActivitySource
    ) {
        self.id = id
        self.name = name
        self.distance = distance
        self.movingTime = movingTime
        self.elevationGain = elevationGain
        self.startDate = startDate
        self.type = type
        self.sourceRaw = source.rawValue
    }

    public var distanceKm: Double { distance / 1000 }

    /// Allure moyenne en secondes par km.
    public var paceSecondsPerKm: Double {
        guard distance > 0 else { return 0 }
        return Double(movingTime) / distanceKm
    }

    /// Étiquette jour court — "LUN", "MAR"... Toujours en français.
    public func dayLabel(in calendar: Calendar = .iso8601Monday) -> String {
        let weekday = calendar.component(.weekday, from: startDate)
        // Calendar weekday: 1=Sunday, 2=Monday...
        return ["DIM", "LUN", "MAR", "MER", "JEU", "VEN", "SAM"][weekday - 1]
    }
}

public enum ActivitySource: String, Codable, Sendable {
    case strava
    case appleHealth
    case garmin
    case manual
    case seed
}

extension Activity: Equatable {
    public static func == (lhs: Activity, rhs: Activity) -> Bool { lhs.id == rhs.id }
}

extension Activity: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// DTO Sendable utilisé pour traverser les actor boundaries (Strava → MainActor).
/// L'`Activity` SwiftData est un `@Model` (class) qui n'est pas safe à transférer.
public struct ActivityDTO: Sendable, Hashable {
    public let id: String
    public let name: String
    public let distance: Double
    public let movingTime: Int
    public let elevationGain: Double
    public let startDate: Date
    public let type: String
    public let source: ActivitySource

    public init(id: String, name: String, distance: Double, movingTime: Int,
                elevationGain: Double, startDate: Date, type: String, source: ActivitySource) {
        self.id = id; self.name = name; self.distance = distance
        self.movingTime = movingTime; self.elevationGain = elevationGain
        self.startDate = startDate; self.type = type; self.source = source
    }
}

public extension Calendar {
    /// Calendar ISO 8601 commençant le lundi — base pour toutes les semaines.
    static var iso8601Monday: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Lundi
        cal.minimumDaysInFirstWeek = 4
        return cal
    }
}
