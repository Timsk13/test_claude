import DeviceActivity
import Foundation
import ManagedSettings

/// Extension appelée par iOS en arrière-plan, même quand l'app ScreenLimit est fermée.
class LimitMonitor: DeviceActivityMonitor {

    /// Minuit : nouvelle journée, compteur de sessions remis à zéro.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let target = resolve(activity.rawValue), target.kind == "daily" else { return }
        LimitEngine.dayStarted(target.limit)
    }

    /// Fin de la pause entre deux sessions.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let target = resolve(activity.rawValue), target.kind == "cooldown" else { return }
        LimitEngine.cooldownEnded(target.limit)
    }

    /// Fin d'une session (seuil d'usage cumulé atteint).
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let target = resolve(event.rawValue), target.kind == "session",
              let number = target.number, target.limit.isEnabled else { return }
        LimitEngine.sessionEnded(target.limit, number: number)
    }

    private func resolve(_ rawName: String) -> (kind: String, limit: AppLimit, number: Int?)? {
        guard let parsed = AppLimit.parse(rawName),
              let limit = LimitStorage.limit(withID: parsed.id) else { return nil }
        return (parsed.kind, limit, parsed.number)
    }
}
