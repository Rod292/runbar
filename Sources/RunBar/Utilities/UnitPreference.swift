import Foundation
import SwiftUI

/// Unité de distance préférée par l'utilisateur. Persistée via @AppStorage.
public enum DistanceUnit: String, CaseIterable, Identifiable, Sendable {
    case km, mi
    public var id: Self { self }

    /// Conversion mètres → unité affichée.
    public func value(fromMeters meters: Double) -> Double {
        switch self {
        case .km: return meters / 1000.0
        case .mi: return meters / 1609.344
        }
    }

    /// Conversion unité affichée → mètres (pour les saisies).
    public func toMeters(_ value: Double) -> Double {
        switch self {
        case .km: return value * 1000.0
        case .mi: return value * 1609.344
        }
    }

    /// Conversion km → unité affichée (pour les valeurs déjà en km comme `WeeklyGoal.target`).
    public func valueFromKilometers(_ km: Double) -> Double {
        switch self {
        case .km: return km
        case .mi: return km / 1.609344
        }
    }

    /// Conversion unité affichée → km.
    public func toKilometers(_ value: Double) -> Double {
        switch self {
        case .km: return value
        case .mi: return value * 1.609344
        }
    }

    public var symbol: String {
        switch self {
        case .km: return String(localized: "distance.km", bundle: .runBarResources)
        case .mi: return String(localized: "distance.mi", bundle: .runBarResources)
        }
    }

    /// Default basé sur la locale utilisateur. États-Unis et UK = mi, sinon km.
    public static var systemDefault: DistanceUnit {
        Locale.current.measurementSystem == .metric ? .km : .mi
    }
}

/// Wrapper @AppStorage centralisé pour l'unité de distance.
@propertyWrapper
public struct UnitPreference: DynamicProperty {
    @AppStorage("runbar.unit") private var raw: String = DistanceUnit.systemDefault.rawValue

    public init() {}

    public var wrappedValue: DistanceUnit {
        get { DistanceUnit(rawValue: raw) ?? .km }
        nonmutating set { raw = newValue.rawValue }
    }

    public var projectedValue: Binding<DistanceUnit> {
        Binding(
            get: { DistanceUnit(rawValue: raw) ?? .km },
            set: { raw = $0.rawValue }
        )
    }
}

/// Lecture stand-alone hors d'une SwiftUI View (services, notifications…).
public enum UnitPreferences {
    public static var current: DistanceUnit {
        let raw = UserDefaults.standard.string(forKey: "runbar.unit") ?? DistanceUnit.systemDefault.rawValue
        return DistanceUnit(rawValue: raw) ?? .km
    }
}

/// Formattage des distances. Mètres en entrée (cohérent avec Strava).
public enum DistanceFormatter {

    /// "12.4 km" ou "7.7 mi" selon la préférence.
    public static func string(meters: Double, unit: DistanceUnit? = nil, fractionDigits: Int = 1) -> String {
        let u = unit ?? UnitPreferences.current
        let value = u.value(fromMeters: meters)
        let formatted = number(value, fractionDigits: fractionDigits)
        let key: String.LocalizationValue = u == .km ? "distance.format.km" : "distance.format.mi"
        return String(localized: key, bundle: .runBarResources).replacingOccurrences(of: "%@", with: formatted)
    }

    /// Comme `string(meters:)` mais à partir d'une distance déjà en km.
    public static func stringFromKm(_ km: Double, unit: DistanceUnit? = nil, fractionDigits: Int = 1) -> String {
        string(meters: km * 1000.0, unit: unit, fractionDigits: fractionDigits)
    }

    /// Numérique seul (sans unité), pour insérer dans une chaîne plus large.
    public static func number(_ value: Double, fractionDigits: Int = 1) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale.current
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = fractionDigits
        nf.maximumFractionDigits = fractionDigits
        return nf.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }
}
