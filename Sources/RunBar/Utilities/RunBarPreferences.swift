import Foundation

public enum RunBarPreferences {
    public enum Key {
        public static let showGlyph = "runbar.showGlyph"
        public static let showPercent = "runbar.showPercent"
        public static let autoSync = "runbar.autoSync"
        public static let notifyVictory = "runbar.notifyVictory"
        public static let trailMode = "runbar.trailMode"
    }

    public static var showGlyph: Bool {
        UserDefaults.standard.object(forKey: Key.showGlyph) as? Bool ?? true
    }

    public static var showPercent: Bool {
        UserDefaults.standard.object(forKey: Key.showPercent) as? Bool ?? false
    }

    public static var autoSync: Bool {
        UserDefaults.standard.object(forKey: Key.autoSync) as? Bool ?? true
    }

    public static var notifyVictory: Bool {
        UserDefaults.standard.object(forKey: Key.notifyVictory) as? Bool ?? true
    }

    public static var trailMode: Bool {
        UserDefaults.standard.object(forKey: Key.trailMode) as? Bool ?? false
    }
}
