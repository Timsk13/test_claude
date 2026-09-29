import DeviceActivity
import FamilyControls
import Foundation

@MainActor
final class LimitsModel: ObservableObject {
    @Published private(set) var limits: [AppLimit] = LimitStorage.load()
    @Published private(set) var states: [UUID: LimitState] = [:]
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var errorMessage: String?

    private let center = DeviceActivityCenter()

    init() {
        refreshStates()
    }

    // MARK: - Autorisation Temps d'écran

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Autorisation refusée : \(error.localizedDescription)"
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - État du jour (écrit par l'extension)

    func refreshStates() {
        states = Dictionary(uniqueKeysWithValues: limits.map { ($0.id, LimitStorage.state(for: $0.id)) })
    }

    func state(for limit: AppLimit) -> LimitState {
        states[limit.id] ?? LimitStorage.state(for: limit.id)
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
        refreshStates()
    }

    func setEnabled(_ enabled: Bool, for limit: AppLimit) {
        var updated = limit
        updated.isEnabled = enabled
        save(updated)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            LimitEngine.stop(limits[index], center: center)
        }
        limits.remove(atOffsets: offsets)
        persist()
        refreshStates()
    }

    private func persist() {
        LimitStorage.save(limits)
    }

    // MARK: - Surveillance

    private func schedule(_ limit: AppLimit) {
        guard limit.isEnabled, !limit.isSelectionEmpty, limit.sessionMinutes > 0, limit.sessionCount > 0 else {
            LimitEngine.stop(limit, center: center)
            return
        }
        do {
            try LimitEngine.startDailyMonitoring(limit, center: center)
            // Une modification ne lève pas une pause ou un blocage en cours.
            LimitEngine.reconcile(limit)
        } catch {
            errorMessage = "Impossible de démarrer la surveillance : \(error.localizedDescription)"
        }
    }
}
