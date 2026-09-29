import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Une limite découpée en sessions : `sessionCount` sessions de `sessionMinutes` par jour,
/// séparées par une pause obligatoire de `cooldownMinutes`. Après la dernière session,
/// les apps restent bloquées jusqu'à minuit.
struct AppLimit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var sessionMinutes: Int = 7
    var sessionCount: Int = 8
    var cooldownMinutes: Int = 45
    var selection = FamilyActivitySelection()
    var isEnabled = true

    /// DeviceActivity refuse les intervalles de moins de 15 minutes.
    static let minimumCooldown = 15

    var dailyMinutes: Int { sessionMinutes * sessionCount }

    var isSelectionEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    // MARK: - Noms DeviceActivity / ManagedSettings

    /// Activité quotidienne (00:00 → 23:59) qui compte l'usage cumulé.
    var dailyActivity: DeviceActivityName { DeviceActivityName("daily.\(id.uuidString)") }
    /// Activité ponctuelle dont la fin marque la fin de la pause.
    var cooldownActivity: DeviceActivityName { DeviceActivityName("cooldown.\(id.uuidString)") }
    var storeName: ManagedSettingsStore.Name { ManagedSettingsStore.Name("limit.\(id.uuidString)") }

    /// Événement déclenché à la fin de la session `number` (seuil = number × sessionMinutes).
    func sessionEvent(_ number: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("session.\(id.uuidString).\(number)")
    }

    /// Décode un nom de la forme `prefixe.<uuid>[.<numéro>]`.
    static func parse(_ rawName: String) -> (kind: String, id: UUID, number: Int?)? {
        let parts = rawName.split(separator: ".").map(String.init)
        guard parts.count >= 2, let id = UUID(uuidString: parts[1]) else { return nil }
        return (parts[0], id, parts.count > 2 ? Int(parts[2]) : nil)
    }
}

/// État du jour pour une limite, partagé entre l'app et l'extension.
struct LimitState: Codable, Equatable {
    var day: Date
    var sessionsUsed = 0
    var cooldownEndsAt: Date?

    func isExhausted(for limit: AppLimit) -> Bool { sessionsUsed >= limit.sessionCount }

    func isCoolingDown(at date: Date = .now) -> Bool {
        guard let end = cooldownEndsAt else { return false }
        return end > date
    }
}

/// Persistance dans l'App Group, partagé avec l'extension de surveillance.
enum LimitStorage {
    static let appGroup = "group.com.example.screenlimit"
    private static let limitsKey = "limits"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> [AppLimit] {
        guard let data = defaults.data(forKey: limitsKey) else { return [] }
        return (try? JSONDecoder().decode([AppLimit].self, from: data)) ?? []
    }

    static func save(_ limits: [AppLimit]) {
        guard let data = try? JSONEncoder().encode(limits) else { return }
        defaults.set(data, forKey: limitsKey)
    }

    static func limit(withID id: UUID) -> AppLimit? {
        load().first { $0.id == id }
    }

    /// État du jour ; repart de zéro si l'état enregistré date d'un jour précédent.
    static func state(for id: UUID) -> LimitState {
        let today = Calendar.current.startOfDay(for: .now)
        if let data = defaults.data(forKey: "state.\(id.uuidString)"),
           let state = try? JSONDecoder().decode(LimitState.self, from: data),
           state.day == today {
            return state
        }
        return LimitState(day: today)
    }

    static func saveState(_ state: LimitState, for id: UUID) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: "state.\(id.uuidString)")
    }

    static func clearState(for id: UUID) {
        defaults.removeObject(forKey: "state.\(id.uuidString)")
    }
}

/// Pose ou retire l'écran de blocage pour une limite.
enum LimitShield {
    static func block(_ limit: AppLimit) {
        let store = ManagedSettingsStore(named: limit.storeName)
        let selection = limit.selection
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    static func unblock(_ limit: AppLimit) {
        ManagedSettingsStore(named: limit.storeName).clearAllSettings()
    }
}

/// Logique sessions / pauses, appelée par l'extension `LimitMonitor` (et par l'app à l'enregistrement).
enum LimitEngine {

    /// Démarre (ou redémarre) le comptage quotidien avec un seuil par fin de session.
    static func startDailyMonitoring(_ limit: AppLimit, center: DeviceActivityCenter = .init()) throws {
        center.stopMonitoring([limit.dailyActivity])
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for number in 1...limit.sessionCount {
            events[limit.sessionEvent(number)] = DeviceActivityEvent(
                applications: limit.selection.applicationTokens,
                categories: limit.selection.categoryTokens,
                webDomains: limit.selection.webDomainTokens,
                threshold: DateComponents(minute: number * limit.sessionMinutes),
                // Compte aussi le temps déjà passé aujourd'hui (évite de tricher en recréant la limite).
                includesPastActivity: true
            )
        }
        try center.startMonitoring(limit.dailyActivity, during: schedule, events: events)
    }

    /// Nouvelle journée : compteur remis à zéro et apps débloquées.
    static func dayStarted(_ limit: AppLimit) {
        let stored = LimitStorage.state(for: limit.id)
        // `startMonitoring` peut rappeler intervalDidStart en cours de journée : on ne remet à zéro
        // que si aucune session n'a encore été consommée aujourd'hui.
        guard stored.sessionsUsed == 0, stored.cooldownEndsAt == nil else { return }
        DeviceActivityCenter().stopMonitoring([limit.cooldownActivity])
        LimitShield.unblock(limit)
    }

    /// Fin de la session `number` : blocage, puis pause ou blocage jusqu'à minuit.
    static func sessionEnded(_ limit: AppLimit, number: Int) {
        var state = LimitStorage.state(for: limit.id)
        // Les événements peuvent arriver en double ou dans le désordre (includesPastActivity).
        guard number > state.sessionsUsed else { return }
        state.sessionsUsed = number
        LimitShield.block(limit)

        if state.isExhausted(for: limit) {
            state.cooldownEndsAt = nil
            DeviceActivityCenter().stopMonitoring([limit.cooldownActivity])
        } else {
            state.cooldownEndsAt = startCooldown(limit)
        }
        LimitStorage.saveState(state, for: limit.id)
    }

    /// Fin de la pause : on débloque, sauf si toutes les sessions sont consommées.
    static func cooldownEnded(_ limit: AppLimit) {
        var state = LimitStorage.state(for: limit.id)
        // Tolérance d'une minute : l'extension peut être réveillée un peu en avance.
        if let end = state.cooldownEndsAt, end > .now.addingTimeInterval(60) { return }
        state.cooldownEndsAt = nil
        LimitStorage.saveState(state, for: limit.id)
        if !state.isExhausted(for: limit) {
            LimitShield.unblock(limit)
        }
    }

    /// Réapplique le blocage adapté à l'état actuel (après modification d'une limite).
    static func reconcile(_ limit: AppLimit) {
        let state = LimitStorage.state(for: limit.id)
        if state.isExhausted(for: limit) || state.isCoolingDown() {
            LimitShield.block(limit)
        } else {
            LimitShield.unblock(limit)
        }
    }

    /// Arrête toute surveillance et lève le blocage (limite désactivée ou supprimée).
    static func stop(_ limit: AppLimit, center: DeviceActivityCenter = .init()) {
        center.stopMonitoring([limit.dailyActivity, limit.cooldownActivity])
        LimitShield.unblock(limit)
        LimitStorage.clearState(for: limit.id)
    }

    /// Programme une activité ponctuelle « maintenant → maintenant + pause » ; sa fin débloque les apps.
    private static func startCooldown(_ limit: AppLimit) -> Date {
        let minutes = max(limit.cooldownMinutes, AppLimit.minimumCooldown)
        let start = Date.now
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(components, from: start),
            intervalEnd: Calendar.current.dateComponents(components, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([limit.cooldownActivity])
        try? center.startMonitoring(limit.cooldownActivity, during: schedule)
        return end
    }
}
