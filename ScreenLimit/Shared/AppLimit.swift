import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Une limite de temps quotidienne appliquée à un ensemble d'apps / catégories / sites.
struct AppLimit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var minutes: Int
    var selection = FamilyActivitySelection()
    var isEnabled = true

    var activityName: DeviceActivityName { DeviceActivityName("limit.\(id.uuidString)") }
    var eventName: DeviceActivityEvent.Name { DeviceActivityEvent.Name("limit.\(id.uuidString)") }
    var storeName: ManagedSettingsStore.Name { ManagedSettingsStore.Name("limit.\(id.uuidString)") }

    var isSelectionEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    /// Retrouve l'identifiant d'une limite à partir du nom d'activité ou d'événement.
    static func id(from rawName: String) -> UUID? {
        guard rawName.hasPrefix("limit.") else { return nil }
        return UUID(uuidString: String(rawName.dropFirst("limit.".count)))
    }
}

/// Persistance des limites dans l'App Group, partagé avec l'extension de surveillance.
enum LimitStorage {
    static let appGroup = "group.com.example.screenlimit"
    private static let key = "limits"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> [AppLimit] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AppLimit].self, from: data)) ?? []
    }

    static func save(_ limits: [AppLimit]) {
        guard let data = try? JSONEncoder().encode(limits) else { return }
        defaults.set(data, forKey: key)
    }

    static func limit(withID id: UUID) -> AppLimit? {
        load().first { $0.id == id }
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
