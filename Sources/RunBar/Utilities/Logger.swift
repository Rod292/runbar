import Foundation
import Logging

/// Logger partagé — wrapper autour de swift-log.
public enum RunBarLog {
    public static let app    = Logger(label: "com.rodrigue.runbar.app")
    public static let sync   = Logger(label: "com.rodrigue.runbar.sync")
    public static let strava = Logger(label: "com.rodrigue.runbar.strava")
    public static let ui     = Logger(label: "com.rodrigue.runbar.ui")
}
