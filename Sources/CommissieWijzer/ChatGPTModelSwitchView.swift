import SwiftUI

struct ChatGPTModelSwitchView: View {
    @ObservedObject var workspace: SimpleWorkspace
    @ObservedObject private var account = ChatGPTAccount.shared
    @Environment(\.dismiss) private var dismiss
    @State private var choice: ChatGPTModelChoice

    init(workspace: SimpleWorkspace) {
        self.workspace = workspace
        _choice = State(initialValue: Self.makeChoice(workspace.activeModel, catalog: ChatGPTAccount.shared.models))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(UIStrings.text("Wissel AI-model")).font(.title2.weight(.semibold))
            Text(UIStrings.text("De fase \(workspace.analysisPhase?.title ?? "AI-analyse") wordt volledig opnieuw uitgevoerd met deze keuze. Afgeronde eerdere fasen blijven behouden met hun eigen model."))
            Text(UIStrings.text("De volledige PDF, bronnen en je zelfselectie blijven behouden. Deze keuze geldt alleen voor deze analyse en wijzigt je instellingen niet."))
                .foregroundStyle(.secondary)
            DisclosureGroup(UIStrings.text("Bewaarde fasemodellen")) {
                VStack(alignment: .leading, spacing: 4) {
                    provenance("Punten", model: workspace.analysisModel)
                    provenance("Documentsamenvatting", model: workspace.summaryModel)
                    provenance("Bronpassages", model: workspace.highlightModel)
                }.font(.caption)
            }.font(.caption)

            if !account.isSignedIn {
                Label(UIStrings.text("Meld je aan met ChatGPT om beschikbare modellen te zien."), systemImage: "person.crop.circle.badge.exclamationmark")
            } else if account.models.isEmpty {
                HStack { ProgressView().controlSize(.small); Text(UIStrings.text(account.busy ? account.status : "Beschikbare accountmodellen ophalen…")) }
            } else {
                FocusChoiceTabs(UIStrings.text("ChatGPT-werkwijze"), selection: $choice.routing, options: [
                    .init(value: ChatGPTModelChoice.Routing.single, title: UIStrings.text("Eén model")),
                    .init(value: ChatGPTModelChoice.Routing.orchestrated, title: UIStrings.text("Orchestrator en subagents"))
                ])

                modelPicker(title: choice.routing == .single ? "ChatGPT-model" : "Orchestrator-model",
                            model: $choice.orchestratorModel, effort: $choice.orchestratorEffort)
                if choice.routing == .orchestrated {
                    modelPicker(title: "Subagent-model", model: $choice.workerModel, effort: $choice.workerEffort)
                    Text(UIStrings.text("De ingestelde taakverdeling blijft behouden: subagents verwerken passages; de orchestrator maakt overzichten en controleert bronnen."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !account.catalogNotice.isEmpty {
                    Text(UIStrings.text(account.catalogNotice)).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
            HStack {
                Button(UIStrings.text("Annuleer")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(UIStrings.text("Pas toe en herstart fase")) {
                    workspace.applyChatGPTModelSwitch(choice, catalog: account.models)
                    dismiss()
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .disabled(!workspace.canSwitchChatGPTModel || !account.isSignedIn || account.busy || choice.encoded(using: account.models) == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 430)
        .task {
            if account.isSignedIn && account.models.isEmpty { await account.refreshModels() }
            choice = Self.makeChoice(workspace.activeModel, catalog: account.models)
        }
        .onChange(of: account.models.map(\.id)) { _, _ in
            if choice.encoded(using: account.models) == nil {
                choice = Self.makeChoice(workspace.activeModel, catalog: account.models)
            }
        }
        .onChange(of: choice.orchestratorModel) { _, _ in choice.normalize(using: account.models) }
        .onChange(of: choice.workerModel) { _, _ in choice.normalize(using: account.models) }
        .buttonStyle(FocusSecondaryButtonStyle())
        .disclosureGroupStyle(FullRowDisclosureGroupStyle())
    }

    @ViewBuilder private func modelPicker(title: String, model: Binding<String>, effort: Binding<String>) -> some View {
        let selected = account.models.first { $0.id == model.wrappedValue }
        VStack(alignment: .leading, spacing: 8) {
            FocusMenuPicker(UIStrings.text(title), selection: model,
                            selectedTitle: UIStrings.text(selected?.displayName ?? (model.wrappedValue.isEmpty ? "Kies een model" : "\(model.wrappedValue) · niet beschikbaar"))) {
                ForEach(account.models) { item in Text(item.displayName).tag(item.id) }
            }
            if let selected, !selected.reasoningEfforts.isEmpty {
                FocusMenuPicker(UIStrings.text("Redeneerniveau"), selection: effort,
                                selectedTitle: UIStrings.text(effort.wrappedValue)) {
                    ForEach(selected.reasoningEfforts, id: \.self) { Text($0).tag($0) }
                }
            } else if selected != nil {
                Text(UIStrings.text("Dit model gebruikt zijn standaard redeneerinstelling."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private static func makeChoice(_ encoded: String, catalog: [ChatGPTModel]) -> ChatGPTModelChoice {
        let parts = encoded.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let isOrchestrated = parts.count == 5 && AIConfiguration.isChatGPT(encoded)
        let mainID = isOrchestrated ? parts[1] : (AIConfiguration.chatGPTSelection(encoded)?.model ?? catalog.first?.id ?? "")
        let mainEffort = isOrchestrated ? parts[2] : (AIConfiguration.chatGPTSelection(encoded)?.effort ?? "auto")
        let workerID = isOrchestrated ? parts[3] : mainID
        let workerEffort = isOrchestrated ? parts[4] : mainEffort
        let main = catalog.first { $0.id == mainID } ?? catalog.first
        let worker = catalog.first { $0.id == workerID } ?? main
        return ChatGPTModelChoice(
            routing: isOrchestrated ? .orchestrated : .single,
            orchestratorModel: main?.id ?? "", orchestratorEffort: Self.effort(mainEffort, model: main),
            workerModel: worker?.id ?? "", workerEffort: Self.effort(workerEffort, model: worker))
    }

    private static func effort(_ proposed: String, model: ChatGPTModel?) -> String {
        guard let model else { return proposed }
        guard !model.reasoningEfforts.isEmpty else { return "auto" }
        if model.reasoningEfforts.contains(proposed) { return proposed }
        return model.reasoningEfforts.contains("medium") ? "medium" : model.reasoningEfforts[0]
    }

    private func provenance(_ title: String, model: String?) -> some View {
        Text(UIStrings.text("\(title): \(model.map(AIConfiguration.label) ?? "Nog niet vastgelegd")"))
            .textSelection(.enabled)
    }
}
