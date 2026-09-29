import DeviceActivity
import Foundation
import ManagedSettings

/// Extension appelée par iOS en arrière-plan, même quand l'app ScreenLimit est fermée.
class LimitMonitor: DeviceActivityMonitor {

    /// Début de journée : on lève le blocage pour repartir à zéro.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if let limit = limit(for: activity.rawValue) {
            LimitShield.unblock(limit)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if let limit = limit(for: activity.rawValue) {
            LimitShield.unblock(limit)
        }
    }

    /// Temps écoulé : on bloque les apps de la limite.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        if let limit = limit(for: event.rawValue), limit.isEnabled {
            LimitShield.block(limit)
        }
    }

    private func limit(for rawName: String) -> AppLimit? {
        guard let id = AppLimit.id(from: rawName) else { return nil }
        return LimitStorage.limit(withID: id)
    }
}
