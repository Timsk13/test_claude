import DeviceActivity
import FamilyControls
import Foundation

@MainActor
final class LimitsModel: ObservableObject {
    @Published private(set) var limits: [AppLimit] = LimitStorage.load()
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var errorMessage: String?

    private let center = DeviceActivityCenter()

    // MARK: - Autorisation Temps d'écran

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Autorisation refusée : \(error.localizedDescription)"
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - CRUD

    func save(_ limit: AppLimit) {
        if let index = limits.firstIndex(where: { $0.id == limit.id }) {
            limits[index] = limit
        } else {
            limits.append(limit)
        }
        persist()
        schedule(limit)
    }

    func setEnabled(_ enabled: Bool, for limit: AppLimit) {
        var updated = limit
        updated.isEnabled = enabled
        save(updated)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            stop(limits[index])
        }
        limits.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        LimitStorage.save(limits)
    }

    // MARK: - Surveillance

    /// Surveille l'usage cumulé de la journée (00:00 → 23:59, chaque jour).
    /// Quand le seuil est atteint, l'extension `LimitMonitor` pose le blocage.
    private func schedule(_ limit: AppLimit) {
        stop(limit)
        guard limit.isEnabled, !limit.isSelectionEmpty, limit.minutes > 0 else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: limit.selection.applicationTokens,
            categories: limit.selection.categoryTokens,
            webDomains: limit.selection.webDomainTokens,
            threshold: DateComponents(minute: limit.minutes),
            // Compte aussi le temps déjà passé aujourd'hui avant la création de la limite.
            includesPastActivity: true
        )

        do {
            try center.startMonitoring(limit.activityName, during: schedule, events: [limit.eventName: event])
        } catch {
            errorMessage = "Impossible de démarrer la surveillance : \(error.localizedDescription)"
        }
    }

    private func stop(_ limit: AppLimit) {
        center.stopMonitoring([limit.activityName])
        LimitShield.unblock(limit)
    }
}
