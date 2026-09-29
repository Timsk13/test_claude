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
                    Stepper(value: $limit.minutes, in: 5...720, step: 5) {
                        Text(formatted(minutes: limit.minutes)).monospacedDigit()
                    }
                } header: {
                    Text("Temps autorisé par jour")
                } footer: {
                    Text("Une fois ce temps écoulé, les apps sont bloquées jusqu'à minuit.")
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

    private var summary: String {
        let s = limit.selection
        var parts: [String] = []
        if !s.applicationTokens.isEmpty { parts.append("\(s.applicationTokens.count) app(s)") }
        if !s.categoryTokens.isEmpty { parts.append("\(s.categoryTokens.count) catégorie(s)") }
        if !s.webDomainTokens.isEmpty { parts.append("\(s.webDomainTokens.count) site(s)") }
        return parts.joined(separator: " · ")
    }
}
