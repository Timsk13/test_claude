import FamilyControls
import SwiftUI

struct LimitEditorView: View {
    @EnvironmentObject private var model: LimitsModel
    @Environment(\.dismiss) private var dismiss

    @State private var limit: AppLimit
    @State private var isPickerPresented = false

    init(limit: AppLimit) {
        _limit = State(initialValue: limit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Réseaux sociaux, jeux…", text: $limit.name)
                }

                Section {
                    Button("Choisir les apps") { isPickerPresented = true }
                    if !limit.isSelectionEmpty {
                        SelectionIcons(selection: limit.selection)
                        Text(summary).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apps à limiter")
                }

                Section {
                    Stepper(value: $limit.sessionMinutes, in: 1...180) {
                        LabeledContent("Durée d'une session", value: formatted(minutes: limit.sessionMinutes))
                    }
                    Stepper(value: $limit.sessionCount, in: 1...20) {
                        LabeledContent("Sessions par jour", value: "\(limit.sessionCount)")
                    }
                    if limit.sessionCount > 1 {
                        Stepper(value: $limit.cooldownMinutes, in: AppLimit.minimumCooldown...240, step: 5) {
                            LabeledContent("Pause entre 2 sessions", value: formatted(minutes: limit.cooldownMinutes))
                        }
                    }
                } header: {
                    Text("Sessions")
                } footer: {
                    Text(explanation)
                }
            }
            .navigationTitle(limit.name.isEmpty ? "Nouvelle limite" : limit.name)
            .navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $limit.selection)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        model.save(limit)
                        dismiss()
                    }
                    .disabled(limit.isSelectionEmpty)
                }
            }
        }
    }

    private var explanation: String {
        let session = formatted(minutes: limit.sessionMinutes)
        guard limit.sessionCount > 1 else {
            return "Après \(session) d'utilisation, les apps sont bloquées jusqu'à minuit."
        }
        return """
        Après chaque session de \(session), les apps sont bloquées pendant \(formatted(minutes: limit.cooldownMinutes)). \
        Après la \(limit.sessionCount)e session (\(formatted(minutes: limit.dailyMinutes)) au total), \
        elles restent bloquées jusqu'à minuit.
        """
    }

    private var summary: String {
        let s = limit.selection
        var parts: [String] = []
        if !s.applicationTokens.isEmpty { parts.append("\(s.applicationTokens.count) app(s)") }
        if !s.categoryTokens.isEmpty { parts.append("\(s.categoryTokens.count) catégorie(s)") }
        if !s.webDomainTokens.isEmpty { parts.append("\(s.webDomainTokens.count) site(s)") }
        return parts.joined(separator: " · ")
    }
}
