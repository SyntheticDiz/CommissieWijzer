import SwiftUI

struct GlossaryView: View {
    @Environment(\.dismiss) private var dismiss
    let document: OpenPDF
    var initialSearch = ""
    var tutorialPreview = false
    let showPage: (Int) -> Void
    private let searchProvider = "wikipedia"
    @State private var online: [String: OnlineGlossaryResult] = [:]
    @State private var onlineErrors: [String: String] = [:]
    @State private var enriching = false
    @State private var completed = 0
    @State private var total = 0
    @State private var onlineStatus = ""
    @State private var onlineTask: Task<Void, Never>?
    @State private var entries: [GlossaryEntry] = []
    @State private var search = ""
    @State private var loading = true
    @State private var personal = PersonalGlossary()
    @State private var editing: GlossaryEntry?
    @State private var definition = ""
    @State private var everywhere = false
    @State private var error: String?
    private var documentKey: String { LocalCache.key(document.pages) }
    private func own(_ entry: GlossaryEntry) -> String? { personal.meaning(entry.abbreviation, document: documentKey) }
    private func web(_ entry: GlossaryEntry) -> OnlineGlossaryResult? {
        guard let result = online[Glossary.key(entry.abbreviation)], result.source == nil || result.source?.kind == "Wikipedia-introductie" else { return nil }
        return result
    }
    private var pending: [GlossaryEntry] { entries.filter { own($0) == nil && $0.definitions.isEmpty && $0.reference == nil && !(web($0)?.certain == true && web($0)?.fresh == true) } }
    private func meaning(_ entry: GlossaryEntry) -> String { own(entry) ?? entry.definitions.first?.text ?? entry.reference?.meaning ?? (web(entry)?.certain == true ? web(entry)?.fullName : nil) ?? "Betekenis niet vastgesteld" }
    private func label(_ entry: GlossaryEntry) -> String { own(entry) != nil ? "Eigen definitie" : !entry.definitions.isEmpty ? "Uit document" : entry.reference != nil ? "Woordenlijst" : web(entry)?.certain == true ? "Online aangevuld · AI-uitleg" : web(entry) != nil ? "Betekenis onzeker" : "Onbekend" }
    var filtered: [GlossaryEntry] {
        entries.filter { search.isEmpty || ([$0.abbreviation, meaning($0), $0.reference?.meaning ?? ""] + $0.definitions.map(\.text)).joined(separator: " ").localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Afkortingenlijst").font(.title2.bold())
                Spacer()
                Button("Gereed") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(document.name).font(.caption).foregroundStyle(.secondary)
            Text("Betekenissen uit dit document hebben voorrang op de algemene woordenlijst. Je eigen definitie wordt als zodanig gemarkeerd.").font(.callout).foregroundStyle(.secondary)
            TextField("Zoek afkorting of betekenis…", text: $search).textFieldStyle(FocusInputFieldStyle())
            Text(UIStrings.text("Automatisch aanvullen gebruikt Wikipedia-introducties en de gekozen AI-provider.")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Vul ontbrekende betekenissen online aan", systemImage: "globe") { enrich() }
                    .disabled(loading || enriching || pending.isEmpty)
                if enriching { Button("Stop") { onlineTask?.cancel() } }
            }
            if enriching { ProgressView(value: Double(completed), total: Double(max(1, total))) }
            if !onlineStatus.isEmpty { Text(onlineStatus).font(.caption).foregroundStyle(.secondary) }
            if loading { ProgressView("Afkortingen verzamelen…") }
            else { Text("\(filtered.count) afkortingen").font(.caption) }
            if let error { Text(error).foregroundStyle(.orange) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !loading && filtered.isEmpty { Text("Geen afkortingen gevonden.") }
                    ForEach(filtered) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(entry.abbreviation).font(.title3.bold())
                                Spacer()
                                Text(label(entry)).font(.caption).foregroundStyle(.secondary)
                            }
                            ReadableText(text: meaning(entry))
                            if let result = web(entry), own(entry) == nil && entry.definitions.isEmpty && entry.reference == nil {
                                ReadableText(text: result.explanation)
                                if !result.context.isEmpty { ReadableText(text: "In dit document: " + result.context).foregroundStyle(.secondary) }
                                if let source = result.source { Link("Bron bekijken · " + source.title, destination: source.url).font(.callout) }
                                Text("Opgehaald: " + result.date.formatted(date: .abbreviated, time: .omitted) + (result.fresh ? "" : " · ouder dan 30 dagen")).font(.caption).foregroundStyle(.secondary)
                            }
                            if let message = onlineErrors[Glossary.key(entry.abbreviation)] { Text(message).font(.caption).foregroundStyle(.orange) }
                            DisclosureGroup("Bronnen en andere betekenissen") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(entry.definitions.enumerated()), id: \.offset) { _, value in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("In document · PDF-pagina \(value.page)").font(.caption).foregroundStyle(.secondary)
                                            SourceQuoteView(text: value.text)
                                        }
                                    }
                                    if let reference = entry.reference {
                                        ReadableText(text: "Woordenlijst: \(reference.meaning)")
                                        ReadableText(text: reference.explanation).foregroundStyle(.secondary)
                                        Link("Officiële toelichting", destination: reference.url)
                                    }
                                    if let result = web(entry), let source = result.source {
                                        Text(source.kind).font(.caption).foregroundStyle(.secondary)
                                        if !result.quote.isEmpty { SourceQuoteView(text: result.quote) }
                                        Link(source.title, destination: source.url)
                                    }
                                    if let first = entry.occurrences.first { SourceQuoteView(text: first.excerpt).font(.callout) }
                                    ForEach(entry.occurrences, id: \.page) { occurrence in
                                        Button("PDF-pagina \(occurrence.page)") { showPage(occurrence.page); dismiss() }
                                    }
                                }.padding(.top, 8)
                            }
                            HStack {
                                Button(own(entry) == nil ? "Betekenis toevoegen" : "Betekenis aanpassen") {
                                    definition = own(entry) ?? ""; everywhere = personal.documents[documentKey]?[Glossary.key(entry.abbreviation)] == nil && personal.general[Glossary.key(entry.abbreviation)] != nil
                                    editing = entry
                                }
                                Spacer()
                                Link("Zoek online naar betekenis", destination: entry.searchURL)
                            }.font(.callout)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            Text(UIStrings.text("Wikipedia ontvangt de afkorting. Bij ChatGPT worden ook een kort documentfragment en de gevonden bronintroducties naar OpenAI verstuurd; bij Apple Intelligence blijft die AI-verwerking lokaal. Zoek online blijft een aparte browserzoekopdracht.")).font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 700, height: 650)
        .task(id: documentKey) {
            if !initialSearch.isEmpty { search = initialSearch }
            loading = true
            if tutorialPreview {
                entries = Glossary.extract(pages: document.pages)
                loading = false
                return
            }
            do { online = try OnlineGlossaryStore.read(documentKey) } catch { self.error = "Online aanvullingen konden niet worden geladen: " + error.localizedDescription }
            do { personal = try PersonalGlossary.read() } catch { self.error = "Eigen woordenlijst kon niet worden geladen: " + error.localizedDescription }
            let pages = document.pages
            let terms = Set(personal.general.keys).union(personal.documents[documentKey]?.keys.map { $0 } ?? [])
            entries = await Task.detached { Glossary.extract(pages: pages, personalTerms: terms) }.value
            loading = false
        }
        .onDisappear { onlineTask?.cancel() }
        .sheet(item: $editing) { entry in
            VStack(alignment: .leading, spacing: 18) {
                Text("Betekenis van \(entry.abbreviation)").font(.title2.bold())
                TextField("Eigen definitie", text: $definition, axis: .vertical).lineLimit(3...6)
                Toggle("Bewaren voor alle documenten", isOn: $everywhere)
                Text("Uitgeschakeld: alleen dit document. Een documentdefinitie heeft voorrang op je algemene woordenlijst.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Annuleren") { editing = nil }.keyboardShortcut(.cancelAction)
                    Button("Eigen definitie verwijderen", role: .destructive) { save(entry, value: "") }
                    Spacer()
                    Button("Bewaren") { save(entry, value: definition) }
                        .disabled(definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 520)
                .buttonStyle(FocusSecondaryButtonStyle())
        .disclosureGroupStyle(FullRowDisclosureGroupStyle())
        }
        .buttonStyle(FocusSecondaryButtonStyle())
        .disclosureGroupStyle(FullRowDisclosureGroupStyle())
    }
    private func enrich() {
        guard !enriching else { return }
        let queue = pending
        guard !queue.isEmpty else { return }
        let chosenProvider = searchProvider
        enriching = true; completed = 0; total = queue.count; error = nil; onlineErrors = [:]
        onlineTask = Task { @MainActor in
            defer { enriching = false }
            do {
                if let reason = AIConfiguration.unavailability() { throw AppError(message: reason) }
                for entry in queue {
                    try Task.checkCancellation()
                    onlineStatus = "\(completed + 1) van \(total): \(entry.abbreviation) opzoeken en uitleggen…"
                    do {
                        let sources = try await GlossaryWebSearch.search(term: entry.abbreviation, provider: chosenProvider)
                        let result = try await OnlineGlossaryService.explain(term: entry.abbreviation, context: entry.occurrences.first?.excerpt ?? "", sources: sources, model: AIConfiguration.selectedModel)
                        try Task.checkCancellation()
                        var revised = online; revised[Glossary.key(entry.abbreviation)] = result
                        try OnlineGlossaryStore.write(revised, key: documentKey)
                        online = revised
                    } catch {
                        try Task.checkCancellation()
                        if error is GlossarySearchUnavailable || error is URLError { throw error }
                        onlineErrors[Glossary.key(entry.abbreviation)] = error.localizedDescription
                    }
                    completed += 1
                }
                let confirmed = queue.filter { web($0)?.certain == true }.count
                onlineStatus = "Gereed: \(confirmed) aangevuld, \(total - confirmed) onzeker of niet gelukt. Geslaagde resultaten zijn lokaal bewaard."
            } catch {
                if Task.isCancelled { onlineStatus = "Gestopt na \(completed) van \(total). Geslaagde aanvullingen zijn bewaard." }
                else { self.error = error.localizedDescription; onlineStatus = "Online aanvullen niet afgerond." }
            }
        }
    }
    private func save(_ entry: GlossaryEntry, value: String) {
        var revised = personal
        revised.set(value, term: entry.abbreviation, document: documentKey, everywhere: everywhere)
        do { try revised.write(); personal = revised; editing = nil; error = nil }
        catch { self.error = "Bewaren mislukt: " + error.localizedDescription; editing = nil }
    }
}
