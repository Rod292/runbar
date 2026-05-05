import Combine
import Foundation
import Logging

/// Orchestre la synchronisation des activités depuis Strava (et plus tard Garmin/HealthKit).
@MainActor
public final class SyncManager: ObservableObject {
    @Published public var isSyncing: Bool = false
    @Published public var lastSync: Date? = nil
    @Published public var lastError: String? = nil
    @Published public var lastImportedActivityCount: Int? = nil

    private let store: ActivityStore
    private let strava: StravaServiceProtocol
    private var timer: Timer?

    public init(store: ActivityStore, strava: StravaServiceProtocol) {
        self.store = store
        self.strava = strava
    }

    public func startBackgroundSync(interval: TimeInterval = 30 * 60) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.syncNow() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Strava API Agreement: "No Strava Data shall remain in your cache
        // longer than seven days." On fetch + reconcile une fenêtre roulante de
        // 7 jours uniquement. L'historique long est conservé via
        // `WeeklySnapshot` (agrégats km/target par semaine), qui sont des
        // données dérivées calculées par RunBar — pas de la Strava Data brute.
        let syncStart = Calendar.iso8601Monday.date(
            byAdding: .day,
            value: -7,
            to: Date.now
        ) ?? Date.now
        do {
            let isAuth = await strava.isAuthenticated()
            guard isAuth else {
                RunBarLog.sync.notice("Sync skipped — Strava not authenticated (stub)")
                lastError = nil
                lastImportedActivityCount = nil
                return
            }
            let dtos = try await strava.fetchActivities(since: syncStart)
            RunBarLog.sync.notice("Fetched \(dtos.count) Strava activit\(dtos.count == 1 ? "y" : "ies") since \(syncStart)")
            // Purge d'abord les activités > 7 jours (rétention Strava ToS),
            // puis reconcile la fenêtre fraîchement fetchée.
            store.purge(source: .strava, olderThan: syncStart)
            store.reconcile(source: .strava, since: syncStart, with: dtos)
            lastSync = .now
            lastError = nil
            lastImportedActivityCount = dtos.count
        } catch {
            RunBarLog.sync.error("Sync failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            lastImportedActivityCount = nil
        }
    }
}
