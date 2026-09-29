import FamilyControls
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: LimitsModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var editedLimit: AppLimit?

    var body: some View {
        NavigationStack {
            Group {
                if model.authorizationStatus != .approved {
                    authorizationPrompt
                } else if model.limits.isEmpty {
                    ContentUnavailableView(
                        "Aucune limite",
                        systemImage: "hourglass",
                        description: Text("Ajoute une limite pour bloquer des apps après un temps d'utilisation quotidien.")
                    )
                } else {
                    limitsList
                }
            }
            .navigationTitle("ScreenLimit")
            .toolbar {
                if model.authorizationStatus == .approved {
                    Button {
                        editedLimit = AppLimit(name: "")
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.refreshStates() }
            }
            .sheet(item: $editedLimit) { limit in
                LimitEditorView(limit: limit)
            }
            .alert(
                "Erreur",
                isPresented: Binding(get: { model.errorMessage != nil }, set: { _ in model.errorMessage = nil }),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(model.errorMessage ?? "") }
            )
        }
    }

    private var authorizationPrompt: some View {
        ContentUnavailableView {
            Label("Accès Temps d'écran requis", systemImage: "lock.shield")
        } description: {
            Text("ScreenLimit a besoin de l'autorisation Temps d'écran pour surveiller et bloquer les apps choisies.")
        } actions: {
            Button("Autoriser") {
                Task { await model.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var limitsList: some View {
        List {
            ForEach(model.limits) { limit in
                Button {
                    editedLimit = limit
                } label: {
                    LimitRow(limit: limit)
                }
                .foregroundStyle(.primary)
            }
            .onDelete(perform: model.delete)
        }
        .refreshable { model.refreshStates() }
    }
}

private struct LimitRow: View {
    @EnvironmentObject private var model: LimitsModel
    let limit: AppLimit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(limit.name.isEmpty ? "Sans nom" : limit.name)
                    .font(.headline)
                Text(rule)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if limit.isEnabled {
                    StatusBadge(limit: limit, state: model.state(for: limit))
                }
                SelectionIcons(selection: limit.selection)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { limit.isEnabled },
                set: { model.setEnabled($0, for: limit) }
            ))
            .labelsHidden()
        }
    }

    private var rule: String {
        let session = formatted(minutes: limit.sessionMinutes)
        guard limit.sessionCount > 1 else { return "\(session) par jour" }
        return "\(limit.sessionCount) × \(session) · pause \(formatted(minutes: limit.cooldownMinutes))"
    }
}

/// Session en cours, pause ou blocage jusqu'à minuit.
private struct StatusBadge: View {
    let limit: AppLimit
    let state: LimitState

    var body: some View {
        // Se met à jour chaque minute pour faire disparaître une pause terminée.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Group {
                if state.isExhausted(for: limit) {
                    Label("Bloqué jusqu'à minuit", systemImage: "lock.fill")
                        .foregroundStyle(.red)
                } else if let end = state.cooldownEndsAt, end > context.date {
                    Label("En pause jusqu'à \(end.formatted(date: .omitted, time: .shortened))",
                          systemImage: "pause.circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("Session \(state.sessionsUsed + 1)/\(limit.sessionCount) disponible",
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption.weight(.medium))
        }
    }
}

/// Affiche les icônes des apps sélectionnées (les tokens sont opaques, seul `Label` peut les afficher).
struct SelectionIcons: View {
    let selection: FamilyActivitySelection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(selection.applicationTokens.prefix(6)), id: \.self) { token in
                Label(token).labelStyle(.iconOnly)
            }
            ForEach(Array(selection.categoryTokens.prefix(3)), id: \.self) { token in
                Label(token).labelStyle(.iconOnly)
            }
            let total = selection.applicationTokens.count + selection.categoryTokens.count
            if total > 9 {
                Text("+\(total - 9)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(height: 24)
    }
}

func formatted(minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    switch (h, m) {
    case (0, _): return "\(m) min"
    case (_, 0): return "\(h) h"
    default: return "\(h) h \(m) min"
    }
}
