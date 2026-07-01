import Combine
import Foundation
import SwiftData

/// Store des activités, persisté via SwiftData. Le `goal` reste en `UserDefaults`
/// (sérialisé JSON) — c'est un singleton, pas une collection.
@MainActor
public final class ActivityStore: ObservableObject {
    @Published public var activities: [Activity] = []
    @Published public var goal: WeeklyGoal = .default {
        didSet { saveGoal() }
    }

    private let container: ModelContainer
    private var goalCancellable: AnyCancellable?
    private let goalKey = "runbar.weeklyGoal.v1"

    public init(inMemory: Bool = false) {
        let schema = Schema([Activity.self])
        let url = URL.applicationSupportDirectory
            .appending(path: "RunBar/store.sqlite")
        do {
            let config: ModelConfiguration
            if inMemory {
                config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                config = ModelConfiguration(schema: schema, url: url)
            }
            self.container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Fallback en mémoire si on ne peut pas écrire (sandbox, etc.).
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            self.container = try! ModelContainer(for: schema, configurations: config)
        }

        loadGoal()
        loadActivities()

        #if DEBUG
        if ProcessInfo.processInfo.environment["RUNBAR_SEED"] == "1", activities.isEmpty {
            upsert(SeedData.weekInProgress())
        }
        #endif
    }

    /// Sauvegarde le contexte en loggant l'échec au lieu de l'avaler : un
    /// disque plein ou une base corrompue doit laisser une trace exploitable
    /// (`log stream --predicate 'subsystem CONTAINS "runbar"'`).
    private func save(_ context: ModelContext, operation: String) {
        do { try context.save() }
        catch { RunBarLog.app.error("SwiftData save failed (\(operation)): \(error)") }
    }

    /// Insère ou met à jour des activités depuis des DTO, dédup par id.
    public func upsert(_ incoming: [ActivityDTO]) {
        let context = container.mainContext
        for dto in incoming {
            let id = dto.id
            let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == id })
            if let existing = try? context.fetch(descriptor).first {
                existing.name = dto.name
                existing.distance = dto.distance
                existing.movingTime = dto.movingTime
                existing.elevationGain = dto.elevationGain
                existing.startDate = dto.startDate
                existing.type = dto.type
                existing.sourceRaw = dto.source.rawValue
            } else {
                let model = Activity(
                    id: dto.id, name: dto.name, distance: dto.distance,
                    movingTime: dto.movingTime, elevationGain: dto.elevationGain,
                    startDate: dto.startDate, type: dto.type, source: dto.source
                )
                context.insert(model)
            }
        }
        save(context, operation: "upsert")
        loadActivities()
    }

    /// Remplace la fenêtre synchronisée pour une source donnée. Cela garde les
    /// autres sources intactes et supprime localement les activités Strava qui
    /// ont été retirées ou ne sont plus renvoyées par l'API.
    public func reconcile(source: ActivitySource, since: Date, with incoming: [ActivityDTO]) {
        upsert(incoming)

        let ids = Set(incoming.map(\.id))
        let sourceRaw = source.rawValue
        let context = container.mainContext
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { activity in
                activity.sourceRaw == sourceRaw && activity.startDate >= since
            }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for activity in existing where !ids.contains(activity.id) {
            context.delete(activity)
        }
        save(context, operation: "reconcile")
        loadActivities()
    }

    public func clear() {
        let context = container.mainContext
        try? context.delete(model: Activity.self)
        save(context, operation: "clear")
        loadActivities()
    }

    /// Supprime toutes les activités d'une source donnée (typiquement `.strava`).
    /// Utilisé à la déconnexion : Strava API Agreement exige de supprimer les
    /// données de l'utilisateur sur révocation. Les autres sources (seed, future
    /// HealthKit) sont préservées.
    public func clear(source: ActivitySource) {
        let sourceRaw = source.rawValue
        let context = container.mainContext
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.sourceRaw == sourceRaw }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for activity in existing { context.delete(activity) }
        save(context, operation: "clear(source:)")
        loadActivities()
    }

    /// Supprime une activité Strava par son `object_id`. Appelée quand le
    /// webhook nous notifie d'un `aspect_type=delete` côté Strava — l'API
    /// Agreement (section 2.6f) exige la suppression dans les 48h.
    public func deleteStravaActivity(objectID: Int) {
        let key = String(objectID)
        let context = container.mainContext
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.id == key }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard !existing.isEmpty else { return }
        for activity in existing { context.delete(activity) }
        save(context, operation: "deleteStravaActivity")
        loadActivities()
    }

    /// Purge les activités d'une source plus anciennes qu'un cutoff. Strava API
    /// Agreement: pas plus de 7 jours de Strava Data en cache. L'historique
    /// long est conservé via `WeeklySnapshot` (agrégats dérivés).
    public func purge(source: ActivitySource, olderThan cutoff: Date) {
        let sourceRaw = source.rawValue
        let context = container.mainContext
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { activity in
                activity.sourceRaw == sourceRaw && activity.startDate < cutoff
            }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard !existing.isEmpty else { return }
        for activity in existing { context.delete(activity) }
        save(context, operation: "purge")
        loadActivities()
    }

    private func loadActivities() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        activities = (try? context.fetch(descriptor)) ?? []
    }

    private func loadGoal() {
        guard let data = UserDefaults.standard.data(forKey: goalKey),
              let decoded = try? JSONDecoder().decode(WeeklyGoal.self, from: data) else { return }
        goal = decoded
    }

    private func saveGoal() {
        if let data = try? JSONEncoder().encode(goal) {
            UserDefaults.standard.set(data, forKey: goalKey)
        }
    }
}

#if DEBUG
public enum SeedData {
    public static func weekInProgress() -> [ActivityDTO] {
        let cal = Calendar.iso8601Monday
        let monday = Date.now.startOfWeek()
        func day(_ offset: Int, hours: Int) -> Date {
            cal.date(byAdding: .hour, value: offset * 24 + hours, to: monday) ?? monday
        }
        return [
            ActivityDTO(id: "seed-1", name: "Morning run",
                        distance: 8000, movingTime: 45 * 60 + 12, elevationGain: 60,
                        startDate: day(0, hours: 7), type: "Run", source: .seed),
            ActivityDTO(id: "seed-2", name: "Intervals",
                        distance: 12_000, movingTime: 58 * 60, elevationGain: 90,
                        startDate: day(2, hours: 18), type: "Run", source: .seed),
            ActivityDTO(id: "seed-3", name: "Long run",
                        distance: 22_000, movingTime: 2 * 3600 + 10 * 60, elevationGain: 350,
                        startDate: day(5, hours: 9), type: "TrailRun", source: .seed),
        ]
    }

    public static func weekComplete() -> [ActivityDTO] {
        var runs = weekInProgress()
        let cal = Calendar.iso8601Monday
        let monday = Date.now.startOfWeek()
        let sunday = cal.date(byAdding: .hour, value: 6 * 24 + 9, to: monday) ?? .now
        runs.append(ActivityDTO(
            id: "seed-4", name: "Trail Locronan",
            distance: 18_000, movingTime: 1 * 3600 + 48 * 60, elevationGain: 540,
            startDate: sunday, type: "TrailRun", source: .seed
        ))
        return runs
    }
}
#endif
