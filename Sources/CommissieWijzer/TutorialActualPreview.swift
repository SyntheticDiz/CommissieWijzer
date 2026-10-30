import SwiftUI
import PDFKit

/// Shows the same SwiftUI controls as the app, supplied with an isolated, in-memory document.
/// The preview is read-only; phase changes are driven by TutorialView, never by an AI request.
@MainActor struct TutorialActualPreview: View {
    let step: Int
    let phase: Int
    let playbackStarted: Date
    let reduceMotion: Bool
    @StateObject private var workspace = TutorialDemoData.makeWorkspace()
    @StateObject private var pdfControls = PDFControls()
    @StateObject private var selectionSummary = SelectionSummary()
    @State private var compareProgram = false
    @State private var demoProvider = "apple"
    @State private var query = ""
    @State private var rememberedTargetFrames: [String: CGRect] = [:]
    @State private var rememberedStep = -1

    private var document: OpenPDF { workspace.document! }
    private var playbackKey: String { "\(step)-\(phase)" }
    private var targetNames: [String] {
        switch step {
        case 0: ["import"]
        case 1: ["providerMenu", "providerChatGPTOption"]
        case 2: ["mode", "modeCompareOption"]
        case 3: [] // Automatic analysis has no user action to point at.
        case 4: ["summary"]
        case 5: ["category-decisions", "amounts"]
        case 6: ["source"]
        case 7: ["pdfPane", "selection"]
        case 8: ["search", "searchResult"]
        case 9: ["table"]
        case 10: ["ask"]
        case 11: ["exportAction", "exportNext"]
        default: []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text").foregroundStyle(AppTheme.accent)
                Text(UIStrings.text("Uitsnede uit CommissieWijzer · fictief commissiestuk")).font(.caption.bold())
                Spacer()
                Text("demo").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            scene.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped().id(step).transition(.opacity)
        }
        .padding(12)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.08)) }
        .overlayPreferenceValue(TutorialAnchorKey.self) { targets in
            GeometryReader { geometry in
                let currentFrames = Dictionary(uniqueKeysWithValues: targetNames.compactMap { name in
                    targets[name].map { (name, geometry[$0]) }
                })
                let allFrames = (rememberedStep == step ? rememberedTargetFrames : [:]).merging(currentFrames) { _, current in current }
                Group {
                if !reduceMotion, phase < 3 {
                    let selection = targets["pdfPane"].flatMap { selectionRect(in: geometry[$0]) }
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        let elapsed = max(0, timeline.date.timeIntervalSince(playbackStarted))
                        let motion = TutorialPointerMotion.state(
                            step: step, elapsed: elapsed, targets: allFrames, selection: selection)
                        ZStack {
                            if let bounds = motion.target, step != 7,
                               bounds.width < geometry.size.width * 0.8, bounds.height < 130 {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppTheme.accent.opacity(0.07))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(AppTheme.accent.opacity(0.32), lineWidth: 1.5)
                                    }
                                    .frame(width: bounds.width + 10, height: bounds.height + 8)
                                    .position(x: bounds.midX, y: bounds.midY)
                                    .opacity(motion.opacity)
                            }
                            if step == 0 && phase == 0 {
                                Label("Commissiestuk.pdf", systemImage: "doc.fill")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(AppTheme.border) }
                                    .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                                    .position(x: motion.position.x - 65, y: motion.position.y - 24)
                                    .opacity(motion.opacity)
                            }
                            TutorialDemoPointer(clickProgress: motion.clickProgress)
                                .position(motion.position)
                                .opacity(motion.opacity)
                        }
                        .allowsHitTesting(false)
                    }
                }
                }
                .onChange(of: currentFrames, initial: true) { _, newFrames in
                    if rememberedStep != step { rememberedTargetFrames = [:]; rememberedStep = step }
                    rememberedTargetFrames.merge(newFrames) { _, current in current }
                }
            }
        }
        .task(id: playbackKey) {
            syncDemo()
            if step == 8 && phase == 1 && !reduceMotion {
                query = ""
                for character in "fietspad" {
                    do { try await Task.sleep(nanoseconds: 115_000_000) } catch { return }
                    guard !Task.isCancelled else { return }
                    query.append(character)
                }
            }
        }
    }

    @ViewBuilder private var scene: some View {
        switch step {
        case 0:
            if phase < 3 {
                PDFImportCard(busy: phase >= 1, targeted: phase == 0, addPDF: {})
                    .allowsHitTesting(false)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                            Label(UIStrings.text("PDF ingelezen"), systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        Spacer()
                        Text("Commissiestuk.pdf · \(document.pages.count) PDF-pagina’s")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(UIStrings.text("Analyse start automatisch"))
                                .font(.callout.weight(.medium))
                            Text(UIStrings.text("De gekozen AI-provider verwerkt het document."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    pdfPane.frame(height: 194)
                }
                .padding(12)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .allowsHitTesting(false)
            }
        case 1:
            providerSettingsDemo
        case 2:
            modeSettingsDemo
        case 3:
            analysisStatusDemo
        case 4:
            summaryDemo
        case 5:
            highlightsDemo
        case 6:
            if phase < 2 {
                ScrollView {
                    tutorialInsightCard(showAsk: false)
                }.allowsHitTesting(false)
            } else { pdfPane.allowsHitTesting(false) }
        case 7:
            if phase < 3 {
                ZStack(alignment: .top) {
                    pdfPane
                    if phase >= 2 {
                        PDFSelectionActionButton(disabled: false, waitingForAnalysis: false, action: {})
                            .padding(.top, 165)
                    }
                }.allowsHitTesting(false)
            } else { SelectionSummaryCard(session: selectionSummary).allowsHitTesting(false) }
        case 8:
            if phase < 3 {
                ScrollView {
                    UnifiedSearchView(query: $query, records: searchRecords, indexing: false, open: { _ in })
                }.allowsHitTesting(false)
            } else { pdfPane.allowsHitTesting(false) }
        case 9:
            if phase < 3 {
                ScrollView {
                    TableExplanationView(tables: workspace.tables, showPage: { _ in },
                                         tutorialExpanded: phase >= 2, tutorialTableExpanded: phase >= 2)
                }.allowsHitTesting(false)
            } else {
                tutorialGlossary
            }
        case 10:
            if phase < 2 {
                ScrollView {
                    tutorialInsightCard(showAsk: true)
                }.allowsHitTesting(false)
            } else {
                tutorialChatTranscript
            }
        default:
            exportWizardDemo
        }
    }

    private var pdfPane: some View {
        TutorialPDFPage(data: document.data, page: workspace.page,
                        highlight: (step == 6 && phase >= 3) || step == 7 || (step == 8 && phase >= 3) ? TutorialDemoData.quote : nil,
                        selectionColor: step == 7 ? .blue : .yellow, controls: pdfControls,
                        selectionProgress: step == 7 ? (phase >= 1 ? 1 : 0) : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tutorialInsightCard(showAsk: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(UIStrings.text("Voorstel"), systemImage: "sparkle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "star").foregroundStyle(.secondary)
            }
            Button {} label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(TutorialDemoData.insight.title).font(.title3.bold())
                    Text(TutorialDemoData.insight.summary).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).tutorialTarget("source")
            Divider()
            HStack(spacing: 8) {
                Button(UIStrings.text("Lees passage"), systemImage: "text.alignleft") {}
                    .buttonStyle(FocusQuietActionStyle())
                Button(UIStrings.text("Details")) {}.buttonStyle(FocusQuietActionStyle())
                if showAsk {
                    Button(UIStrings.text("Stel een vraag"), systemImage: "bubble.left") {}
                        .buttonStyle(FocusQuietActionStyle()).tutorialTarget("ask")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var providerSettingsDemo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(UIStrings.text("AI-provider"), systemImage: "sparkles").font(.title2.bold())
            FocusMenuPicker(UIStrings.text("Analyse uitvoeren met"), selection: $demoProvider,
                            selectedTitle: UIStrings.text(demoProvider == "chatgpt" ? "ChatGPT · online" : "Apple Intelligence · lokaal")) {
                Text(UIStrings.text("Apple Intelligence · lokaal")).tag("apple")
                Text(UIStrings.text("ChatGPT · online")).tag("chatgpt")
            }
            .tutorialTarget("providerMenu")
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: demoProvider)
            if phase == 1 {
                VStack(spacing: 1) {
                    menuItem(UIStrings.text("Apple Intelligence · lokaal"), selected: demoProvider == "apple", target: nil)
                    menuItem(UIStrings.text("ChatGPT · online"), selected: false, target: "providerChatGPTOption")
                }
                .frame(maxWidth: 310, alignment: .leading)
                .padding(5)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.12)) }
                .shadow(color: .black.opacity(0.13), radius: 8, x: 0, y: 4)
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if phase >= 2 {
                VStack(alignment: .leading, spacing: 10) {
                    Label(UIStrings.text("ChatGPT gekozen"), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold)).foregroundStyle(AppTheme.accent)
                    Text(UIStrings.text("Documentinhoud wordt voor AI-verwerking naar OpenAI verstuurd."))
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var modeSettingsDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProcessingModePicker(compareProgram: $compareProgram)
                .tutorialTarget("mode")
            if phase == 1 {
                VStack(spacing: 1) {
                    menuItem(UIStrings.text("Neutrale samenvatting"), selected: !compareProgram, target: nil)
                    menuItem(UIStrings.text("Vergelijk met partijprogramma"), selected: false, target: "modeCompareOption")
                }
                .frame(maxWidth: 310, alignment: .leading)
                .padding(5)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.12)) }
                .shadow(color: .black.opacity(0.13), radius: 8, x: 0, y: 4)
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if phase >= 2 {
                GroupBox(UIStrings.text("Eigen partijprogramma")) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus").foregroundStyle(AppTheme.accent)
                        Text(UIStrings.text("Voeg je programma toe via Instellingen."))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func menuItem(_ title: String, selected: Bool, target: String?) -> some View {
        HStack(spacing: 8) {
            if selected { Image(systemName: "checkmark").frame(width: 12) }
            else { Color.clear.frame(width: 12, height: 12) }
            Text(title).lineLimit(1)
            Spacer(minLength: 8)
        }
        .font(.callout)
        .padding(.horizontal, 9).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .tutorialTarget(target ?? "menuItem")
    }

    private var analysisStatusDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: phase >= 3 ? "checkmark.circle.fill" : "sparkles")
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(UIStrings.text(phase >= 3 ? "Analyse voltooid" : phase == 0 ? "PDF ingelezen" : "Document analyseren…"))
                        .font(.callout.weight(.semibold))
                    Text(UIStrings.text(phase >= 3 ? "De beschikbare resultaten staan in Overzicht." : "De gekozen AI-provider verwerkt het document."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ProgressView(value: phase == 0 ? 0.08 : phase == 1 ? 0.28 : phase == 2 ? 0.68 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: phase)
            if phase == 2 { Text("68% · Nog ongeveer 2 min").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            if phase >= 3 {
                Text(workspace.documentSummary?.digest.overview ?? "")
                    .font(.body).lineSpacing(4)
                    .padding(14).background(AppTheme.background, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .allowsHitTesting(false)
    }

    private var summaryDemo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(UIStrings.text("Documentbreed overzicht"), systemImage: "doc.text")
                .font(.title3.bold())
            Text(workspace.documentSummary?.digest.overview ?? "")
                .font(.body).lineSpacing(4)
            Button {} label: {
                Label(UIStrings.text(phase >= 2 ? "Sluit uitgebreide samenvatting" : "Uitgebreide samenvatting"), systemImage: "text.alignleft")
            }.buttonStyle(FocusQuietActionStyle()).tutorialTarget("summary")
            if phase >= 2, let section = workspace.documentSummary?.pageSections.first(where: { $0.page == 4 }) {
                SummaryPageSectionView(section: section, showPage: { _ in })
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .allowsHitTesting(false)
    }

    private var highlightsDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.text("Concrete bronpassages")).font(.title3.bold())
            ForEach(Array(["Voorstellen & besluiten", "Geld & gevolgen", "Planning & voorwaarden"].enumerated()), id: \.offset) { index, title in
                let selected = (phase >= 2 ? 1 : 0) == index
                Text(UIStrings.text(title)).font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(selected ? AppTheme.accent.opacity(0.12) : AppTheme.buttonSurface, in: RoundedRectangle(cornerRadius: 9))
                    .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? AppTheme.accent.opacity(0.6) : .clear) }
                    .tutorialTarget(index == 1 ? "amounts" : index == 0 ? "category-decisions" : "category-dates")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(phase >= 2 ? "Raming: € 300.000" : "Voorstel voor een apart fietspad").font(.headline)
                Text(phase >= 2 ? "De geraamde kosten bedragen 300.000 euro. Het bedrag is nog niet vastgesteld." : TutorialDemoData.quote).font(.callout)
                Label(UIStrings.text(phase >= 2 ? "Toon in PDF · p. 3" : "Toon in PDF · p. 4"), systemImage: "doc.text.magnifyingglass")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 0)
        }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var tutorialChatTranscript: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(UIStrings.text("Documentchat"), systemImage: "bubble.left.and.bubble.right")
                .font(.headline)
            HStack {
                Spacer(minLength: 42)
                Text("Wanneer bespreekt de raad dit voorstel?")
                    .padding(11).background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            if phase >= 3 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volgens PDF-pagina 4 bespreekt de raad het voorstel in november.")
                        .fixedSize(horizontal: false, vertical: true)
                    Label("PDF-pagina 4 · ‘De raad bespreekt het voorstel in november.’", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(UIStrings.text("Antwoord voorbereiden…")) }
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 18))
        .allowsHitTesting(false)
    }

    private var tutorialGlossary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(UIStrings.text("Afkortingenlijst"), systemImage: "textformat.abc")
                .font(.title3.bold())
            Text(document.name).font(.caption).foregroundStyle(.secondary)
            Text(UIStrings.text("Betekenissen en vindplaatsen uit dit document."))
                .font(.callout).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Text("COA").font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Centraal Orgaan opvang asielzoekers")
                    Text(UIStrings.text("Gevonden in de PDF · pagina 1"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12).background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 18))
        .allowsHitTesting(false)
    }

    private var exportWizardDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            if phase == 0 {
                Button {} label: {
                    Label(UIStrings.text("Exporteren"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .tutorialTarget("exportAction")
            } else {
                Label(UIStrings.text("Exporteren"), systemImage: "square.and.arrow.up")
                    .font(.title3.bold())
                HStack(spacing: 6) {
                    ForEach(Array(["Naam en titel", "Inhoud", "Controleren"].enumerated()), id: \.offset) { index, title in
                        if index > 0 { Image(systemName: "chevron.right").font(.caption2) }
                        Text("\(index + 1). " + UIStrings.text(title))
                            .font(.caption.weight(index == phase - 1 ? .semibold : .regular))
                            .foregroundStyle(index == phase - 1 ? Color.primary : Color.secondary)
                    }
                }
                Divider()
                if phase == 1 {
                    Text(UIStrings.text("Deze titel komt bovenaan de export-PDF."))
                        .font(.callout).foregroundStyle(.secondary)
                    TextField(UIStrings.text("Titel"), text: .constant("Samenvatting commissiestuk"))
                        .textFieldStyle(FocusInputFieldStyle())
                    TextField(UIStrings.text("Bestandsnaam"), text: .constant("Commissiestuk-SAMENVATTING.pdf"))
                        .textFieldStyle(FocusInputFieldStyle())
                    Button(UIStrings.text("Volgende"), systemImage: "chevron.right") {}
                        .buttonStyle(FocusPrimaryButtonStyle()).tutorialTarget("exportNext")
                } else if phase == 2 {
                    Text(UIStrings.text("Kies de onderdelen die je wilt meenemen."))
                        .font(.callout).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Label(UIStrings.text("Documentsamenvatting"), systemImage: "checkmark.square.fill")
                        Label(UIStrings.text("Punten met bronpagina’s"), systemImage: "checkmark.square.fill")
                        Label(UIStrings.text("Commissievragen"), systemImage: "square")
                        Label(UIStrings.text("Tabeluitleg en afkortingen"), systemImage: "square")
                    }
                    .font(.callout)
                    Button(UIStrings.text("Volgende"), systemImage: "chevron.right") {}
                        .buttonStyle(FocusPrimaryButtonStyle()).tutorialTarget("exportNext")
                } else {
                    Text(UIStrings.text("Controleer de gekozen onderdelen en bestandsnaam."))
                        .font(.callout).foregroundStyle(.secondary)
                    Label(UIStrings.text("Documentsamenvatting · punten · bronpagina’s"), systemImage: "checkmark.circle")
                    Label("Commissiestuk-SAMENVATTING.pdf", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(UIStrings.text("Opslaan als PDF…"), systemImage: "square.and.arrow.down") {}
                        .buttonStyle(FocusPrimaryButtonStyle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 18))
        .allowsHitTesting(false)
    }

    private func selectionRect(in pane: CGRect) -> CGRect? {
        guard step == 7,
              let pdf = PDFDocument(data: document.data),
              let page = pdf.page(at: 3),
              let selection = PDFPassageLocator.selection(in: pdf, page: 4, quote: TutorialDemoData.quote) else { return nil }
        let media = page.bounds(for: .mediaBox)
        let quote = selection.bounds(for: page)
        let scale = pane.width / media.width
        return CGRect(x: pane.minX + (quote.minX - media.minX) * scale,
                      y: pane.minY + (media.maxY - quote.maxY) * scale,
                      width: quote.width * scale, height: quote.height * scale)
    }

    private var searchRecords: [SearchRecord] {
        [
            .init(id: "pdf", kind: .pdf, title: "PDF-pagina 4", content: TutorialDemoData.quote,
                  pageLabel: "PDF-pagina 4", action: .page(4, quote: TutorialDemoData.quote)),
            .init(id: "point", kind: .point, title: "Apart fietspad bij het station",
                  content: TutorialDemoData.insight.summary, pageLabel: "PDF-pagina 4", action: .page(4, quote: TutorialDemoData.quote))
        ]
    }

    private func syncDemo() {
        workspace.busy = (step == 0 && phase >= 2) || (step == 3 && phase == 2)
        workspace.analyzed = !(step == 0 || (step == 3 && phase < 3))
        workspace.keyPointsReady = step != 0 && (step != 3 || phase >= 3)
        workspace.status = step == 0 ? "6 pagina’s" : step == 3 && phase < 2 ? "Klaar om te analyseren" : step == 3 && phase == 2 ? "Document analyseren…" : "Verwerking afgerond"
        workspace.progress.fraction = step == 3 && phase == 2 ? 0.43 : 0
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            compareProgram = step == 2 && phase >= 2
            demoProvider = step == 1 && phase >= 2 ? "chatgpt" : "apple"
            query = step == 8 && phase >= 1 ? (phase == 1 ? "fiet" : "fietspad") : ""
        }
        workspace.page = (step == 0 || (step == 6 && phase < 2)) ? 1 : 4
        pdfControls.page = workspace.page
        pdfControls.count = document.pages.count
        if step == 7 && phase >= 3 {
            selectionSummary.selection = .init(text: TutorialDemoData.quote, pages: [4])
            selectionSummary.summary = "De gemeente stelt een apart fietspad bij het station voor."
            selectionSummary.busy = false
        } else { selectionSummary.close() }
    }
}

private struct TutorialDemoPointer: View {
    let clickProgress: Double

    var body: some View {
        ZStack {
            if clickProgress > 0 {
                Circle().strokeBorder(AppTheme.accent, lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .scaleEffect(0.65 + 0.55 * clickProgress)
                    .opacity(1 - clickProgress)
            }
            Image(systemName: "cursorarrow")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 2, x: 1, y: 2)
                .offset(x: 7, y: 7)
        }.frame(width: 36, height: 36).accessibilityHidden(true)
    }
}

/// Continuous cursor path. It follows real control anchors and pauses briefly before each click.
enum TutorialPointerMotion {
    struct State {
        let position: CGPoint
        let opacity: Double
        let clickProgress: Double
        let target: CGRect?
    }

    private struct Stop {
        let anchor: String
        let start: Double
        let click: Double?
    }

    static func state(step: Int, elapsed: Double, targets: [String: CGRect], selection: CGRect?) -> State {
        if step == 7, let selection, let pane = targets["pdfPane"] {
            let start = CGPoint(x: selection.minX + 12, y: selection.midY)
            let end = CGPoint(x: selection.maxX - 8, y: selection.midY)
            let entry = CGPoint(x: start.x + 72, y: start.y + 54)
            let selectionDrag = ease(clamp((elapsed - 1.15) / 1.15))
            let selectionButton = targets["selection"].map { CGPoint(x: $0.midX, y: $0.midY) } ?? end
            let buttonMove = ease(clamp((elapsed - 2.30) / 0.76))
            let position = elapsed < 1.15 ? mix(entry, start, ease(clamp((elapsed - 0.12) / 0.88)))
                : elapsed < 2.30 ? mix(start, end, selectionDrag)
                : mix(end, selectionButton, buttonMove)
            let mouseDown = click(elapsed, at: 1.00)
            let mouseUp = click(elapsed, at: 2.18)
            let actionClick = click(elapsed, at: 3.24)
            return State(position: position, opacity: fade(elapsed, start: 0, end: 3.62),
                         clickProgress: max(mouseDown, max(mouseUp, actionClick)),
                         target: elapsed < 2.3 ? pane : targets["selection"])
        }

        let stops = plan(step)
        guard let first = stops.first, targets[first.anchor] != nil else {
            return State(position: .zero, opacity: 0, clickProgress: 0, target: nil)
        }
        let stopIndex = stops.lastIndex(where: { elapsed >= $0.start }) ?? 0
        let stop = stops[stopIndex]
        guard let frame = targets[stop.anchor] else {
            return State(position: .zero, opacity: 0, clickProgress: 0, target: nil)
        }
        let previous = stopIndex > 0 ? targets[stops[stopIndex - 1].anchor] : nil
        let destination = CGPoint(x: frame.midX, y: frame.midY)
        let origin = previous.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: destination.x + 78, y: destination.y + 62)
        let moveStart = stop.start + 0.08
        let moveEnd = stop.start + 0.88
        let position = mix(origin, destination, ease(clamp((elapsed - moveStart) / (moveEnd - moveStart))))
        let fadeEnd = (stops.compactMap(\.click).last ?? 1.15) + 0.48
        return State(position: position, opacity: fade(elapsed, start: 0, end: fadeEnd),
                     clickProgress: stop.click.map { click(elapsed, at: $0) } ?? 0, target: frame)
    }

    private static func plan(_ step: Int) -> [Stop] {
        switch step {
        case 0: [Stop(anchor: "import", start: 0, click: 1.00)]
        case 1: [Stop(anchor: "providerMenu", start: 0, click: 1.00),
                 Stop(anchor: "providerChatGPTOption", start: 1.15, click: 2.17)]
        case 2: [Stop(anchor: "mode", start: 0, click: 1.00),
                 Stop(anchor: "modeCompareOption", start: 1.15, click: 2.17)]
        case 4: [Stop(anchor: "summary", start: 0, click: 2.17)]
        case 5: [Stop(anchor: "category-decisions", start: 0, click: nil),
                 Stop(anchor: "amounts", start: 1.15, click: 2.17)]
        case 6: [Stop(anchor: "source", start: 0, click: 2.17)]
        case 8: [Stop(anchor: "search", start: 0, click: 1.00),
                 Stop(anchor: "searchResult", start: 2.30, click: 3.40)]
        case 9: [Stop(anchor: "table", start: 0, click: 2.17)]
        case 10: [Stop(anchor: "ask", start: 0, click: 2.17)]
        case 11: [Stop(anchor: "exportAction", start: 0, click: 1.00),
                  Stop(anchor: "exportNext", start: 1.15, click: 2.17),
                  Stop(anchor: "exportNext", start: 2.30, click: 3.40)]
        default: []
        }
    }

    private static func click(_ elapsed: Double, at time: Double) -> Double {
        clamp(1 - abs(elapsed - (time + 0.12)) / 0.30)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    private static func ease(_ value: Double) -> Double { value * value * (3 - 2 * value) }
    private static func fade(_ elapsed: Double, start: Double, end: Double) -> Double {
        min(1, clamp((elapsed - start) / 0.18), clamp((end - elapsed) / 0.25))
    }
    private static func mix(_ from: CGPoint, _ to: CGPoint, _ fraction: Double) -> CGPoint {
        CGPoint(x: from.x + (to.x - from.x) * fraction,
                y: from.y + (to.y - from.y) * fraction)
    }
}
