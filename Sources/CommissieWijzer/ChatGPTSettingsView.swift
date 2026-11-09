import SwiftUI

struct ChatGPTSettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingAdvancedSettings = false
    private let refreshOnAppear: Bool
#if os(iOS)
    @Environment(\.appPresentationContext) private var appPresentationContext
#endif
    @AppStorage("localAIProvider") private var provider = "apple"
    @AppStorage("chatGPTModel") private var model = "gpt-6.1-sol"
    @AppStorage("chatGPTReasoning") private var effort = "high"
    @AppStorage("chatGPTSubagentModel") private var workerModel = "gpt-6-luna"
    @AppStorage("chatGPTSubagentReasoning") private var workerEffort = "high"
    @AppStorage("chatGPTRoutingMode") private var routingMode = ""
    @ObservedObject private var account = ChatGPTAccount.shared

    init(refreshOnAppear: Bool = true) {
        self.refreshOnAppear = refreshOnAppear
    }
    private var selected: ChatGPTModel? { account.models.first { $0.id == model } }
    private var worker: ChatGPTModel? { account.models.first { $0.id == workerModel } }
    private var usesOrchestrator: Bool { routingMode == AIConfiguration.ChatGPTMode.orchestrated.rawValue }
    private var catalogIDs: [String] { account.models.map(\.id) }

    private var modelSelection: Binding<String> {
        Binding(get: { model }, set: { value in
            guard value != model else { return }
            model = value
            if let chosen = account.models.first(where: { $0.id == value }) {
                effort = ChatGPTPreferences.normalizeEffortAfterExplicitModelChoice(
                    current: effort, available: chosen.reasoningEfforts)
            }
        })
    }

    private var workerSelection: Binding<String> {
        Binding(get: { workerModel }, set: { value in
            guard value != workerModel else { return }
            workerModel = value
            if let chosen = account.models.first(where: { $0.id == value }) {
                workerEffort = ChatGPTPreferences.normalizeEffortAfterExplicitModelChoice(
                    current: workerEffort, available: chosen.reasoningEfforts)
            }
        })
    }

    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !account.models.isEmpty {
                SettingsMenuPicker(UIStrings.text("ChatGPT-werkwijze"), selection: $routingMode,
                                selectedTitle: UIStrings.text(usesOrchestrator ? "Orchestrator en subagents" : "Eén model voor alle ChatGPT-taken")) {
                    Text(UIStrings.text("Eén model voor alle ChatGPT-taken")).tag(AIConfiguration.ChatGPTMode.single.rawValue)
                    Text(UIStrings.text("Orchestrator en subagents")).tag(AIConfiguration.ChatGPTMode.orchestrated.rawValue)
                }
                SettingsMenuPicker(UIStrings.text(usesOrchestrator ? "Orchestrator-model" : "ChatGPT-model"), selection: modelSelection,
                                selectedTitle: UIStrings.text(selected?.displayName ?? (model.isEmpty ? "Kies een model" : "\(model) · niet beschikbaar"))) {
                    if !ChatGPTPreferences.modelIsAvailable(model, catalogIDs: catalogIDs) { Text("\(model) · \(UIStrings.text("niet beschikbaar"))").tag(model) }
                    ForEach(account.models) { item in Text(item.displayName).tag(item.id) }
                }
                if let selected, !selected.reasoningEfforts.isEmpty {
                    SettingsMenuPicker(UIStrings.text(usesOrchestrator ? "Redeneerniveau orchestrator" : "Redeneerniveau ChatGPT"), selection: $effort, selectedTitle: UIStrings.text(effort)) {
                        if !selected.reasoningEfforts.contains(effort) { Text("\(effort) · \(UIStrings.text("niet beschikbaar"))").tag(effort) }
                        ForEach(selected.reasoningEfforts, id: \.self) { Text($0).tag($0) }
                    }
                }
                if selected?.reasoningEfforts.isEmpty == true { Text(UIStrings.text("Dit model gebruikt zijn standaard redeneerinstelling.")).font(.caption).foregroundStyle(.secondary) }
                if usesOrchestrator {
                    SettingsMenuPicker(UIStrings.text("Subagent-model"), selection: workerSelection,
                                    selectedTitle: UIStrings.text(worker?.displayName ?? (workerModel.isEmpty ? "Kies een model" : "\(workerModel) · niet beschikbaar"))) {
                        if !ChatGPTPreferences.modelIsAvailable(workerModel, catalogIDs: catalogIDs) { Text("\(workerModel) · \(UIStrings.text("niet beschikbaar"))").tag(workerModel) }
                        ForEach(account.models) { item in Text(item.displayName).tag(item.id) }
                    }
                    if let worker, !worker.reasoningEfforts.isEmpty {
                        SettingsMenuPicker(UIStrings.text("Redeneerniveau subagents"), selection: $workerEffort, selectedTitle: UIStrings.text(workerEffort)) {
                            if !worker.reasoningEfforts.contains(workerEffort) { Text("\(workerEffort) · \(UIStrings.text("niet beschikbaar"))").tag(workerEffort) }
                            ForEach(worker.reasoningEfforts, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if worker == nil && !workerModel.isEmpty { Text("\(UIStrings.text("Opgeslagen subagentmodel")): \(workerModel)").font(.caption).foregroundStyle(.secondary) }
                    Text(UIStrings.text("Subagents verwerken iedere passage afzonderlijk. De orchestrator maakt het documentoverzicht en voert bij programmavergelijking de broncontrole uit. De app bepaalt deze vaste taakverdeling.")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(UIStrings.text("Het gekozen model en redeneerniveau worden gebruikt voor alle ChatGPT-taken, waaronder passages, programmavergelijking, broncontrole en documentoverzicht.")).font(.caption).foregroundStyle(.secondary)
                }
                if let selected, !selected.reasoningEfforts.isEmpty, !selected.reasoningEfforts.contains(effort) {
                    Text(UIStrings.text("Het opgeslagen redeneerniveau ontbreekt voor dit model en blijft bewaard tot je zelf een model kiest.")).font(.caption).foregroundStyle(.secondary)
                }
                if usesOrchestrator, let worker, !worker.reasoningEfforts.isEmpty, !worker.reasoningEfforts.contains(workerEffort) {
                    Text(UIStrings.text("Het opgeslagen redeneerniveau van de subagents ontbreekt voor dit model en blijft bewaard tot je zelf een model kiest.")).font(.caption).foregroundStyle(.secondary)
                }
                Text(UIStrings.text("Na PDF-import start de analyse automatisch met deze keuze.")).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(UIStrings.text("Haal de beschikbare modellen op om een model te kiezen.")).font(.caption)
                if !model.isEmpty { Text("\(UIStrings.text("Opgeslagen model")): \(model)").font(.caption).foregroundStyle(.secondary) }
                if usesOrchestrator && !workerModel.isEmpty { Text("\(UIStrings.text("Opgeslagen subagentmodel")): \(workerModel)").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard(UIStrings.text("AI-provider"), systemImage: "sparkles") {
                SettingsMenuPicker(UIStrings.text("Analyse uitvoeren met"), selection: $provider,
                                   selectedTitle: UIStrings.text(provider == "chatgpt" ? "ChatGPT · online" : "Apple Intelligence · lokaal")) {
                    Text(UIStrings.text("Apple Intelligence · lokaal")).tag("apple")
                    Text(UIStrings.text("ChatGPT · online")).tag("chatgpt")
                }
            }
            if provider == "chatgpt" {
                VStack(alignment: .leading, spacing: 12) {
                    Text(UIStrings.text("De documentinhoud, relevante partijprogrammapassages en je vragen worden voor AI-verwerking naar OpenAI verstuurd. PDF-weergave en zoeken blijven lokaal.")).font(.callout)
                    Text(UIStrings.text("Gebruik je geschikte ChatGPT-abonnement. De beschikbare modellen en gebruikslimieten hangen af van je account.")).font(.caption).foregroundStyle(.secondary)
                    if account.isSignedIn {
                        Label(account.email.isEmpty ? UIStrings.text("Verbonden met ChatGPT") : account.email, systemImage: "checkmark.circle")
                        if !account.models.isEmpty && ((selected == nil && !model.isEmpty) || (usesOrchestrator && worker == nil && !workerModel.isEmpty)) {
                            Text(UIStrings.text("Een opgeslagen ChatGPT-model ontbreekt in de actuele catalogus. Je keuze blijft behouden; kies zelf een vervangend model.")).font(.caption).foregroundStyle(.orange)
                        }
                        if !account.catalogNotice.isEmpty { Text(UIStrings.text(account.catalogNotice)).font(.caption).foregroundStyle(.orange) }
                        DisclosureGroup(isExpanded: $showingAdvancedSettings) {
                            advancedControls
                                .padding(.top, 8)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: showingAdvancedSettings)
                        } label: {
                            Text(UIStrings.text("Geavanceerde modelinstellingen")).font(.headline)
                        }
                        .disclosureGroupStyle(FullRowDisclosureGroupStyle())
                        .accessibilityIdentifier("chatgpt-advanced-settings")
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                Button(UIStrings.text("Modellen vernieuwen")) { Task { await account.refreshModels() } }.disabled(account.busy)
                                Button(UIStrings.text("Uitloggen")) { Task { await account.signOut() } }.disabled(account.busy)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button(UIStrings.text("Modellen vernieuwen")) { Task { await account.refreshModels() } }.disabled(account.busy)
                                Button(UIStrings.text("Uitloggen")) { Task { await account.signOut() } }.disabled(account.busy)
                            }
                        }
                    } else {
                        Button(UIStrings.text("Continue with ChatGPT")) {
                            Task {
#if os(iOS)
                                await account.signIn(context: appPresentationContext)
#else
                                await account.signIn()
#endif
                            }
                        }
                        .buttonStyle(FocusPrimaryButtonStyle())
                        .controlSize(.large)
                        .disabled(account.busy)
                    }
                    if account.busy { HStack { ProgressView().controlSize(.small); Text(UIStrings.text(account.status)) }.frame(maxWidth: .infinity, alignment: .leading) }
                    if account.busy && !account.isSignedIn { Button(UIStrings.text("Inloggen annuleren")) { account.cancelSignIn() } }
                    if !account.busy, !account.status.isEmpty { Text(UIStrings.text(account.status)).font(.caption).foregroundStyle(.secondary) }
                    if let error = account.error { Text(UIStrings.text(error)).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
                    Text(UIStrings.text("Diagramuitleg gebruikt voorlopig het lokale Apple-beeldmodel.")).font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readingSurface()
            }
        }
        .task {
            guard refreshOnAppear else { return }
            guard provider == "chatgpt" else { return }
            ChatGPTPreferences.initializeDefaults(defaults: .standard)
            routingMode = AIConfiguration.chatGPTMode(defaults: .standard).rawValue
            if account.isSignedIn && account.models.isEmpty { await account.refreshModels() }
        }
        .onChange(of: provider) { _, newValue in
            guard refreshOnAppear else { return }
            guard newValue == "chatgpt" else { return }
            ChatGPTPreferences.initializeDefaults(defaults: .standard)
            routingMode = AIConfiguration.chatGPTMode(defaults: .standard).rawValue
            if account.isSignedIn && account.models.isEmpty { Task { await account.refreshModels() } }
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

}
