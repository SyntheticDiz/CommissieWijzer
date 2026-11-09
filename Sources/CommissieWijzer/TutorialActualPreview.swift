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
    @State private var query = ""
    @State private var rememberedTargetFrames: [String: CGRect] = [:]
    @State private var rememberedStep = -1

    private var document: OpenPDF { workspace.document! }
    private var playbackKey: String { "\(step)-\(phase)" }
    private var targetNames: [String] {
        switch step {
        case 0: ["import"]
        case 1: ["providerChange", "providerMenu", "providerChatGPTOption"]
        case 2: ["purpose", "purposeCommittee", "manageCommittees"]
        case 3: [] // Automatic analysis has no user action to point at.
        case 4: ["summary"]
        case 5: ["category-decisions", "amounts"]
        case 6: ["source"]
        case 7: ["pdfPane", "selection"]
        case 8: ["search", "searchResult"]
        case 9: ["table"]
        case 10: ["ask"]
        case 11: ["exportAction", "exportNext"]
        case 12: ["recentWorkspaces", "recentEntry"]
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
                .clipped().id(step).transition(reduceMotion ? .identity : .opacity)
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
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
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
            if phase < 2 { welcomeDemo }
            else { analysisStatusDemo }
        case 1:
            if phase == 0 { welcomeDemo }
            else { providerSettingsDemo }
        case 2:
            if phase < 3 { welcomeDemo }
            else { committeeSettingsDemo }
        case 3:
            analysisStatusDemo
        case 4:
            workbenchDemo(tab: "Documentoverzicht", symbol: "doc.text") { summaryDemo }
        case 5:
            workbenchDemo(tab: phase < 3 ? "Documentoverzicht" : "Documentpunten", symbol: "list.bullet") {
                if phase < 3 { highlightsDemo }
                else { findingsDemo }
            }
        case 6:
            workbenchDemo(tab: "Documentpunten", symbol: "list.bullet", showPDF: phase >= 2) {
                tutorialInsightCard(showAsk: false)
            }
        case 7:
            workbenchDemo(tab: "Documentoverzicht", symbol: "doc.text", showPDF: phase < 3) {
                if phase < 3 { summaryDemo }
                else { SelectionSummaryCard(session: selectionSummary) }
            }
        case 8:
            workbenchDemo(tab: "Zoeken", symbol: "magnifyingglass", showPDF: phase >= 3) {
                if phase == 3 { searchSourceDemo }
                else { UnifiedSearchView(query: $query, records: searchRecords, indexing: false, open: { _ in }) }
            }
        case 9:
            if phase < 3 {
                workbenchDemo(tab: "Tabellen", symbol: "tablecells") {
                    TableExplanationView(tables: workspace.tables, showPage: { _ in },
                                         tutorialExpanded: true, tutorialTableExpanded: phase >= 2)
                }
            } else {
                tutorialGlossary
            }
        case 10:
            if phase < 2 {
                workbenchDemo(tab: "Documentpunten", symbol: "list.bullet") { tutorialInsightCard(showAsk: true) }
            } else {
                tutorialChatTranscript
            }
        case 11:
            exportWizardDemo
        case 12:
            if phase < 2 { savedWorkDemo }
            else if phase == 2 { cloudSettingsDemo }
            else { cloudLibraryDemo }
        default:
            EmptyView()
        }
    }

    private func workbenchDemo<Content: View>(tab: String, symbol: String, showPDF: Bool = false,
                                              @ViewBuilder content: () -> Content) -> some View {
        let cardContent = content()
        return GeometryReader { geometry in
            if usesWideWorkbench(width: geometry.size.width) {
                HStack(spacing: 10) {
                    workspaceCard(tab: tab, symbol: symbol, showsHeading: true) { cardContent }
                        .frame(maxWidth: .infinity)
                    pdfCard(showsHeading: true)
                        .frame(width: (geometry.size.width - 10) * pdfWidthFraction)
                }
            } else {
                VStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { demoPaneSwitcher(showPDF: showPDF) }
                        VStack(spacing: 4) { demoPaneSwitcher(showPDF: showPDF) }
                    }
                    if showPDF { pdfCard(showsHeading: false) }
                    else { workspaceCard(tab: tab, symbol: symbol, showsHeading: false) { cardContent } }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var pdfWidthFraction: CGFloat {
        guard step == 7 else { return 0.43 }
        return phase < 3 ? 0.54 : 0.32
    }

    private func usesWideWorkbench(width: CGFloat) -> Bool {
        #if os(iOS)
        width >= 470
        #else
        true
        #endif
    }

    private func workspaceCard<Content: View>(tab: String, symbol: String, showsHeading: Bool,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeading {
                paneTitle("Analyse en werkveld", symbol: "rectangle.split.2x1")
            }
            Label(UIStrings.text(tab), systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(AppTheme.accent.opacity(0.12), in: Capsule())
            ScrollView {
                content().frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .readingSurface()
    }

    private func pdfCard(showsHeading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeading {
                paneTitle("Originele pdf", symbol: "doc.text")
            }
            pdfPane
            if step == 7 && phase == 2 {
                PDFSelectionActionButton(disabled: false, waitingForAnalysis: false, action: {}, addChosen: {})
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .readingSurface()
    }

    private func paneTitle(_ title: String, symbol: String) -> some View {
        Label(UIStrings.text(title), systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
    }

    @ViewBuilder private func demoPaneSwitcher(showPDF: Bool) -> some View {
        paneTitle("Werkveld", symbol: "rectangle.split.2x1")
            .padding(7).background(!showPDF ? AppTheme.accent.opacity(0.14) : AppTheme.surface, in: Capsule())
        paneTitle("Originele pdf", symbol: "doc.text")
            .padding(7).background(showPDF ? AppTheme.accent.opacity(0.14) : AppTheme.surface, in: Capsule())
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var welcomeDemo: some View {
        ViewThatFits(in: .vertical) {
            welcomeColumn.fixedSize(horizontal: false, vertical: true)
            ScrollView { welcomeColumn }
        }
        .allowsHitTesting(false)
    }

    private var welcomeColumn: some View {
        VStack(spacing: 7) {
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    demoBrandIcon
                    Text("CommissieWijzer").font(.headline)
                }
                Text(UIStrings.text("Jouw stukken. Jouw inzichten. Jouw koers."))
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 5) {
                demoWelcomePicker("Analysevorm", value: "Neutrale samenvatting")
                demoWelcomePicker("Voorbereiden voor", value: step == 2 && phase >= 2 ? "Leefomgeving" : "Raad")
                    .tutorialTarget("purpose")
                if step == 2 && phase == 1 {
                    menuItem(UIStrings.text("Raad"), selected: true, target: nil)
                    menuItem(UIStrings.text("Leefomgeving"), selected: false, target: "purposeCommittee")
                }
                Button(UIStrings.text("Commissies beheren"), systemImage: "slider.horizontal.3") {}
                    .buttonStyle(FocusQuietActionStyle())
                    .tutorialTarget("manageCommittees")
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readingSurface()
            VStack(spacing: 3) {
                Image(systemName: "doc.badge.plus").foregroundStyle(.secondary)
                Text(UIStrings.text(phase == 1 && step == 0 ? "Pdf inladen…" : "Voeg een pdf toe"))
                    .font(.callout.weight(.semibold))
                #if os(macOS)
                Text(UIStrings.text("Sleep je pdf hierheen")).font(.caption2).foregroundStyle(.secondary)
                #endif
                Button(UIStrings.text("Pdf toevoegen…"), systemImage: "plus") {}
                    .buttonStyle(FocusPrimaryButtonStyle())
                    .tutorialTarget("import")
            }
            .padding(.horizontal, 20).padding(.vertical, 7)
            .frame(maxWidth: .infinity).readingSurface()
            HStack {
                Label(UIStrings.text("Apple Intelligence · Lokaal"), systemImage: "sparkles")
                    .font(.caption)
                Spacer(minLength: 4)
                Button(UIStrings.text("Wijzigen")) {}
                    .buttonStyle(FocusQuietActionStyle())
                    .tutorialTarget("providerChange")
            }
            .padding(.horizontal, 10).padding(.vertical, 3).readingSurface()
            workspaceButtons
        }
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
    }

    private func demoWelcomePicker(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(UIStrings.text(title))
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Menu {} label: {
                HStack {
                    Text(UIStrings.text(value))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.caption)
            }
            .menuIndicator(.hidden).focusMenu()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var demoBrandIcon: some View {
        #if os(macOS)
        if let url = Bundle.main.url(forResource: "CWBrand", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            Image(nsImage: icon).resizable().scaledToFit().frame(width: 22, height: 22)
        }
        #else
        Image("CWBrand").resizable().scaledToFit().frame(width: 22, height: 22)
        #endif
    }

    private var workspaceButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { workspaceActionLabels }
            VStack(spacing: 5) { workspaceActionLabels }
        }
        .buttonStyle(FocusSecondaryButtonStyle())
        .controlSize(.small)
    }

    @ViewBuilder private var workspaceActionLabels: some View {
        Button {} label: {
            Label(UIStrings.text("Werkdocument openen…"), systemImage: "folder")
                .frame(maxWidth: .infinity)
        }
        Button {} label: {
            Label(UIStrings.text("iCloud-bibliotheek"), systemImage: "icloud")
                .frame(maxWidth: .infinity)
        }
    }

    private var providerSettingsDemo: some View {
        settingsDemo(.ai) {
            SettingsCard(UIStrings.text("AI-provider"), systemImage: "sparkles") {
                SettingsMenuPicker(UIStrings.text("Analyse uitvoeren met"),
                                   selection: .constant(phase == 3 ? "chatgpt" : "apple"),
                                   selectedTitle: UIStrings.text(phase == 3 ? "ChatGPT · online" : "Apple Intelligence · lokaal")) {
                    Text(UIStrings.text("Apple Intelligence · lokaal")).tag("apple")
                    Text(UIStrings.text("ChatGPT · online")).tag("chatgpt")
                }
                .tutorialTarget("providerMenu")
                if phase == 2 {
                    VStack(spacing: 1) {
                        menuItem(UIStrings.text("Apple Intelligence · lokaal"), selected: true, target: nil)
                        menuItem(UIStrings.text("ChatGPT · online"), selected: false, target: "providerChatGPTOption")
                    }
                    .padding(4)
                    .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 9))
                }
            }
            if phase == 3 {
                SettingsCard("ChatGPT", systemImage: "network") {
                    Label(UIStrings.text("Verbonden met ChatGPT"), systemImage: "checkmark.circle")
                        .font(.caption)
                    DisclosureGroup(isExpanded: .constant(false)) {
                        EmptyView()
                    } label: {
                        Text(UIStrings.text("Geavanceerde modelinstellingen")).font(.caption.weight(.semibold))
                    }
                    .disclosureGroupStyle(FullRowDisclosureGroupStyle())
                }
            }
        }
    }

    private var committeeSettingsDemo: some View {
        settingsDemo(.preparation) {
            SettingsCard(UIStrings.text("Commissies"), systemImage: "person.3") {
                Label(UIStrings.text("Leefomgeving"), systemImage: "list.bullet")
                    .font(.callout.weight(.semibold))
                Text(UIStrings.text("Onderwerpen") + " · " + UIStrings.text("Mobiliteit"))
                    .font(.caption).foregroundStyle(.secondary)
                Button(UIStrings.text("Commissies beheren"), systemImage: "slider.horizontal.3") {}
                    .buttonStyle(FocusSecondaryButtonStyle())
            }
            SettingsCard(UIStrings.text("Eigen partijprogramma"), systemImage: "text.book.closed") {
                Text(UIStrings.text("Voor programmavergelijking kun je in Instellingen een partijprogramma toevoegen."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var cloudSettingsDemo: some View {
        settingsDemo(.storage) {
            SettingsCard(UIStrings.text("Persoonlijke iCloud-synchronisatie"), systemImage: "icloud") {
                Toggle(UIStrings.text("Synchroniseer gekozen dossiers via iCloud"), isOn: .constant(false))
                    .font(.caption)
                Toggle(UIStrings.text("Synchroniseer ook mijn commissielijst"), isOn: .constant(false))
                    .font(.caption).disabled(true)
            }
        }
    }

    private func settingsDemo<Content: View>(_ section: SettingsSection, @ViewBuilder content: () -> Content) -> some View {
        let detail = content()
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(UIStrings.text("Instellingen")).font(.headline)
                Spacer()
                Button(UIStrings.text("Gereed")) {}
                    .buttonStyle(FocusSecondaryButtonStyle())
                    .controlSize(.small)
            }
            .padding(9).background(AppTheme.surface)
            Divider()
            GeometryReader { geometry in
                if geometry.size.width >= 400 {
                    HStack(spacing: 0) {
                        VStack(spacing: 3) {
                            ForEach(SettingsSection.allCases) { item in
                                Button {} label: {
                                    Label(UIStrings.text(item.title), systemImage: item.symbol)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .buttonStyle(SettingsNavigationRowStyle(isSelected: item == section))
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(width: 153)
                        Divider()
                        settingsDetail { detail }
                    }
                } else {
                    settingsDetail(section: section) { detail }
                }
            }
            Divider()
            Text(UIStrings.text("Keuzes worden automatisch bewaard."))
                .font(.caption2).foregroundStyle(.secondary)
                .padding(9).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surface)
        }
        .readingSurface()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .allowsHitTesting(false)
    }

    private func settingsDetail<Content: View>(section: SettingsSection? = nil,
                                               @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let section {
                    Label(UIStrings.text(section.title), systemImage: "chevron.backward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                content()
            }
            .padding(8)
        }
    }

    private var savedWorkDemo: some View {
        VStack(spacing: 10) {
            workspaceButtons
            RecentWorkspacesList(
                entries: [.init(path: "/Commissiestuk.spdfwork", displayName: "Commissiestuk.spdfwork",
                                lastUsed: .distantPast, bookmarkData: nil)],
                open: { _ in }, statusMessage: { _ in nil }, isInitiallyExpanded: phase >= 1
            )
            .id(phase >= 1)
            .tutorialTarget(phase == 0 ? "recentWorkspaces" : "recentEntry")
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private var cloudLibraryDemo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(UIStrings.text("iCloud-bibliotheek"), systemImage: "icloud")
                .font(.title3.weight(.semibold))
            Text(UIStrings.text("Kies een dossier om de beschikbare versie te openen. Openen start geen nieuwe analyse."))
                .font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("Commissiestuk.spdfwork", systemImage: "doc.text").font(.headline)
                Text(UIStrings.text("lokaal beschikbaar")).font(.caption).foregroundStyle(.secondary)
                Button(UIStrings.text("Open versie")) {}
                    .buttonStyle(FocusSecondaryButtonStyle())
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).readingSurface()
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
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
        let isImport = step == 0 && phase == 2
        let (title, illustration, fraction): (String, ProcessingPresentation.Illustration, Double) = switch (step, phase) {
        case (0, 2): ("Document lezen", .document, 0.08)
        case (0, _): ("Punten samenstellen", .points, 0.14)
        case (_, 0): ("Commissievoorbereiding", .committee, 0.19)
        case (_, 1): ("Punten samenstellen", .points, 0.28)
        case (_, 2): ("Vergelijken met partijprogramma…", .partyComparison, 0.40)
        case (_, 3): ("Samenvatting samenstellen", .summary, 0.68)
        default: ("Kernselectie samenstellen", .highlights, 0.90)
        }
        return VStack(spacing: 6) {
            ProcessingStageIllustration(illustration: illustration, scanning: true, completed: false,
                                        reduceMotion: reduceMotion)
                .frame(width: 190, height: 236)
                .scaleEffect(0.37)
                .frame(width: 71, height: 88)
            Text("Commissiestuk.pdf").font(.callout.weight(.semibold))
            Text(UIStrings.text(title)).font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    processingStages(step == 0 ? [.document, .points] : [.document, .committee, .points], illustration)
                }
                HStack(spacing: 8) { processingStages([.summary, .highlights], illustration) }
            }
            ProgressView(value: fraction).tint(.secondary)
            HStack {
                Text(fraction, format: .percent)
                Spacer()
                Text(UIStrings.text("Nog ongeveer 2 min"))
            }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            if !isImport {
                Button {} label: {
                    Text(UIStrings.text("Open document en resultaten")).frame(maxWidth: .infinity)
                }
                .buttonStyle(FocusPrimaryButtonStyle()).controlSize(.small)
            }
            Button {} label: {
                Text(UIStrings.text(isImport ? "Annuleer import" : "Stop en terug naar importeren"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FocusSecondaryButtonStyle()).controlSize(.small)
            DisclosureGroup(UIStrings.text("Details"), isExpanded: .constant(false)) { EmptyView() }
                .font(.caption2)
        }
        .padding(8)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func processingStages(_ stages: [ProcessingPresentation.Stage],
                                  _ illustration: ProcessingPresentation.Illustration) -> some View {
        let orderedStages = ProcessingPresentation.Stage.allCases
        let activeStage: ProcessingPresentation.Stage = switch illustration {
        case .document: .document
        case .committee: .committee
        case .points, .partyComparison: .points
        case .summary: .summary
        case .highlights: .highlights
        }
        return ForEach(stages, id: \.self) { stage in
            let ready = (orderedStages.firstIndex(of: stage) ?? 0) < (orderedStages.firstIndex(of: activeStage) ?? 0)
            Label(UIStrings.text(stage.rawValue),
                  systemImage: ready ? "checkmark.circle.fill" : stage == activeStage ? "circle.dashed" : "circle")
                .font(.caption2)
                .foregroundStyle(stage == activeStage ? Color.primary : Color.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var summaryDemo: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(UIStrings.text("Documentbreed overzicht"), systemImage: "doc.text")
                .font(.callout.weight(.semibold))
            Text(workspace.documentSummary?.digest.overview ?? "")
                .font(.caption).foregroundStyle(.secondary)
            Button {} label: {
                Label(UIStrings.text(phase >= 2 ? "Sluit uitgebreide samenvatting" : "Uitgebreide samenvatting"), systemImage: "text.alignleft")
            }.buttonStyle(FocusQuietActionStyle()).controlSize(.small).tutorialTarget("summary")
            if phase >= 2, let section = workspace.documentSummary?.pageSections.first(where: { $0.page == 4 }) {
                SummaryPageSectionView(section: section, showPage: { _ in })
                    .font(.caption)
                    .transition(.opacity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var searchSourceDemo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("fietspad", systemImage: "magnifyingglass").font(.callout.weight(.medium))
            Divider()
            Label(UIStrings.text("PDF-pagina 4"), systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accent)
            Text(TutorialDemoData.quote).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
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

    private var findingsDemo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UIStrings.text("Alineapunten")).font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) { findingsChoices }
                VStack(alignment: .leading, spacing: 5) { findingsChoices }
            }
            tutorialInsightCard(showAsk: false)
        }
        .padding(7)
    }

    @ViewBuilder private var findingsChoices: some View {
        Text(UIStrings.text("Belangrijkste"))
            .font(.caption.weight(.semibold)).padding(5)
            .background(AppTheme.accent.opacity(0.14), in: Capsule())
        Text(UIStrings.text("Alle punten")).font(.caption).padding(5)
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
    private var symbol: String {
        #if os(iOS)
        return "hand.point.up.left"
        #else
        return "cursorarrow"
        #endif
    }

    var body: some View {
        ZStack {
            if clickProgress > 0 {
                Circle().strokeBorder(AppTheme.accent, lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .scaleEffect(0.65 + 0.55 * clickProgress)
                    .opacity(1 - clickProgress)
            }
            Image(systemName: symbol)
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
        case 1: [Stop(anchor: "providerChange", start: 0, click: 1.00),
                 Stop(anchor: "providerMenu", start: 1.15, click: 2.17),
                 Stop(anchor: "providerChatGPTOption", start: 2.30, click: 3.40)]
        case 2: [Stop(anchor: "purpose", start: 0, click: 1.00),
                 Stop(anchor: "purposeCommittee", start: 1.15, click: 2.17),
                 Stop(anchor: "manageCommittees", start: 2.30, click: 3.40)]
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
        case 12: [Stop(anchor: "recentWorkspaces", start: 0, click: 1.00),
                  Stop(anchor: "recentEntry", start: 1.15, click: 2.17)]
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
