import Foundation
import UserNotifications

/// Petit wrapper UNUserNotificationCenter pour les notifs RunBar.
@MainActor
public final class NotificationService {
    public static let shared = NotificationService()
    private init() {}

    /// `UNUserNotificationCenter` exige un vrai bundle .app (avec bundle identifier).
    /// En `swift run` sans bundle, l'API crashe en assertion. On no-op proprement.
    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    public func requestAuthorizationIfNeeded() async {
        guard hasBundle else {
            RunBarLog.app.notice("Notifications disabled: no bundle identifier (launch via .app to enable)")
            return
        }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    public func notifyVictory(distanceKm: Double, target: Double, unit: String) async {
        guard hasBundle, RunBarPreferences.notifyVictory else { return }
        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.victory.title", bundle: .module)
        let summary = DistanceFormatter.stringFromKm(target)
        let template = String(localized: "notif.victory.body", bundle: .module)
        content.body = String(format: template, summary)
        content.sound = .default
        let req = UNNotificationRequest(identifier: "runbar.victory.\(Int(Date.now.timeIntervalSince1970))",
                                         content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
    }

    public func notifyHalfwayReminder(remaining: Double, unit: String) async {
        guard hasBundle else { return }
        await requestAuthorizationIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.recap.title", bundle: .module)
        let summary = DistanceFormatter.stringFromKm(remaining)
        let template = String(localized: "notif.recap.body", bundle: .module)
        content.body = String(format: template, summary)
        let req = UNNotificationRequest(identifier: "runbar.halfway", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
    }

    /// Programme un récap dominical 21:00, répété chaque dimanche.
    public func scheduleSundayRecap(achieved: Double, target: Double, unit: String,
                                    tier: String, streak: Int) async {
        guard hasBundle else { return }
        await requestAuthorizationIfNeeded()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["runbar.weekly-recap"])

        var components = DateComponents()
        components.weekday = 1   // 1 = dimanche en Calendar
        components.hour = 21
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.recap.title", bundle: .module)
        let summary = DistanceFormatter.stringFromKm(achieved)
        let template = String(localized: "notif.recap.body", bundle: .module)
        var body = String(format: template, summary)
        if streak >= 2 {
            body += " 🔥 \(streak)"
        }
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: "runbar.weekly-recap",
                                         content: content, trigger: trigger)
        try? await center.add(req)
    }
}
