import SwiftUI

private struct TutorialStep: Identifiable {
    let id: Int
    let group: String
    let title: String
    let action: String
    let outcome: String
    let tip: String
    let symbol: String

    private static var importAction: String {
        #if os(iOS)
        return "Kies op het beginscherm Analysevorm en Voorbereiden voor. Kies daarna ‘Pdf toevoegen…’ en open een PDF in Bestanden."
        #else
        return "Kies op het beginscherm Analysevorm en Voorbereiden voor. Sleep daarna een PDF naar de importkaart of kies ‘Pdf toevoegen…’."
        #endif
    }

    private static var selectPassageAction: String {
        #if os(iOS)
        return "Houd een woord in de PDF ingedrukt en versleep de selectiegrepen. Kies daarna Vat selectie samen, zo nodig onder Selectieacties."
        #else
        return "Sleep over de tekst in de PDF om die te selecteren. Kies daarna Vat selectie samen, zo nodig onder Selectieacties."
        #endif
    }

    static let all: [TutorialStep] = [
        .init(id: 0, group: "Beginnen", title: "Een PDF openen",
              action: importAction,
              outcome: "CommissieWijzer leest tekst, leesvolgorde en tabellen in. Als de gekozen AI-provider beschikbaar is, start de analyse automatisch.",
              tip: "Bij een scan zonder leesbare tekstlaag kan tekstherkenning nodig zijn.", symbol: "doc.badge.plus"),
        .init(id: 1, group: "Beginnen", title: "Een AI-provider kiezen",
              action: "Kies Wijzigen naast de provider op het beginscherm. Kies in Instellingen → AI en verwerking bij AI-provider voor Apple Intelligence of ChatGPT.",
              outcome: "Apple Intelligence gebruikt een beschikbaar lokaal model. ChatGPT verwerkt documentinhoud online en vereist internet en aanmelding met een geschikt ChatGPT-account.",
              tip: "Na aanmelding vind je de ChatGPT-modelkeuzes onder Geavanceerde modelinstellingen. Via Over en hulp open je deze rondleiding opnieuw.", symbol: "sparkles"),
        .init(id: 2, group: "Beginnen", title: "Doel en analysemethode kiezen",
              action: "Kies vóór de import Raad of een commissie bij Voorbereiden voor. Kies bij Analysevorm Neutrale samenvatting of Vergelijk met partijprogramma.",
              outcome: "Via Commissies beheren voeg je eigen commissies met onderwerpen en optionele aandachtspunten toe. De gekozen commissie bepaalt welke passages op relevantie en belang worden beoordeeld.",
              tip: "Commissies beheren staat ook onder Instellingen → Voorbereiding. Daar voeg je ook het partijprogramma toe dat je voor een optionele vergelijking wilt gebruiken.", symbol: "slider.horizontal.3"),
        .init(id: 3, group: "Beginnen", title: "De analyse volgen en controleren",
              action: "Volg de actieve fase en de geschatte resterende tijd op het verwerkingsscherm. Open Details voor meer informatie. Stel voltooiingsmeldingen in via Instellingen → Algemeen → Meldingen.",
              outcome: "Elke fase heeft een eigen pictogram. Na het inlezen kun je via Open document en resultaten al naar de PDF en beschikbare resultaten.",
              tip: "Kies Annuleer import tijdens het inlezen. Daarna kun je stoppen via Stop en terug naar importeren of via Stop analyse in het werkveld.", symbol: "play.circle"),
        .init(id: 4, group: "Lezen", title: "De samenvatting lezen",
              action: "Open Documentoverzicht en lees de documentsamenvatting. Kies Uitgebreide samenvatting voor de uitleg per fysieke PDF-pagina.",
              outcome: "Je ziet zowel het grote geheel als waar informatie in het document staat.",
              tip: "Je kunt een paginabereik opgeven om alleen dat deel samen te vatten.", symbol: "text.alignleft"),
        .init(id: 5, group: "Lezen", title: "Punten en bronpassages bekijken",
              action: "Bekijk Concrete bronpassages in Documentoverzicht. Open Documentpunten en wissel tussen Belangrijkste en Alle punten.",
              outcome: "Bij Raad toont Belangrijkste de kernselectie. Voor een commissie vind je de belangrijk beoordeelde passages onder Commissiepunten. Via Alle punten zie je alle beschikbare punten.",
              tip: "Open de titel of samenvatting van een punt om de bijbehorende brontekst in de PDF te controleren.", symbol: "list.bullet.rectangle"),
        .init(id: 6, group: "Lezen", title: "Een punt controleren in de bron",
              action: "Kies de titel of samenvatting van een aandachtspunt om de bron te tonen.",
              outcome: "De PDF springt naar de genoemde fysieke pagina en markeert de bijbehorende passage.",
              tip: "Controleer bedragen, voorwaarden en conclusies in de oorspronkelijke tekst. Op een smal iPad-venster wissel je via Werkveld en Originele pdf.", symbol: "arrow.right.doc.on.clipboard"),
        .init(id: 7, group: "Lezen", title: "Zelf een passage kiezen",
              action: selectPassageAction,
              outcome: "CommissieWijzer geeft uitleg bij het geselecteerde fragment en vermeldt de bronpagina.",
              tip: "Je kunt selecteerbare tekst ook letterlijk bewaren via Opnemen in samenvatting. Je vindt die passage terug in Mijn selectie.", symbol: "text.cursor"),
        .init(id: 8, group: "Lezen", title: "In het document zoeken",
              action: "Open Zoeken in het werkveld en typ een woord of naam.",
              outcome: "Zoeken doorzoekt lokaal de PDF-tekst, samenvattingen, punten, tabellen, afkortingen, bewaarde passages en notities. Een resultaat opent het gevonden onderdeel of de bronpagina.",
              tip: "Een zoekopdracht start geen nieuwe AI-aanvraag.", symbol: "magnifyingglass"),
        .init(id: 9, group: "Voorbereiden", title: "Tabellen en afkortingen begrijpen",
              action: "Open Tabellen voor de herkende cijfers en hun uitleg. Open Afkortingen voor gevonden betekenissen en vindplaatsen.",
              outcome: "Vanuit de tabeluitleg kun je de oorspronkelijke bronpagina openen. Ontbrekende betekenissen kun je optioneel online aanvullen.",
              tip: "Controleer een cijfervergelijking altijd in de oorspronkelijke tabel.", symbol: "tablecells"),
        .init(id: 10, group: "Voorbereiden", title: "Vragen stellen en punten bewaren",
              action: "Kies Stel een vraag bij een aandachtspunt of open Documentchat vanuit het werkveld. Gebruik de ster bij een punt om het aan Mijn selectie toe te voegen.",
              outcome: "Antwoorden kunnen bronverwijzingen tonen; je bewaarde punten vind je terug in Mijn selectie.",
              tip: "Controleer het antwoord via de bronverwijzingen. Bewaar nuttige antwoorden bij je voorbereiding.", symbol: "bubble.left.and.bubble.right"),
        .init(id: 11, group: "Voorbereiden", title: "Een PDF-export maken",
              action: "Kies Exporteren. Stel naam en titel in, kies de onderdelen en controleer je keuzes. Kies daarna Opslaan als PDF…",
              outcome: "De export kan onder meer samenvatting, punten, vragen, tabeluitleg, afkortingen en bronnen bevatten.",
              tip: "Kies Werkdocument bewaren… om later met je resultaten, selectie, notities en leespositie verder te gaan.", symbol: "square.and.arrow.up"),
        .init(id: 12, group: "Voorbereiden", title: "Verder werken aan een dossier",
              action: "Kies op het beginscherm Werkdocument openen… of klap Recente werkdocumenten open en kies een dossier.",
              outcome: "Je opent je bewaarde resultaten, notities en selectie. Het openen van een werkdocument start geen AI-analyse.",
              tip: "Schakel desgewenst iCloud in onder Instellingen → Opslag en export. Kies daarna per dossier Synchroniseer dit dossier via iCloud… Je vindt die dossiers in iCloud-bibliotheek.", symbol: "folder")
    ]
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let staticPreview: Bool
    private var reduceMotion: Bool { staticPreview || systemReduceMotion }
    @State private var step = 0
    @State private var demoPhase = 0
    @State private var replayCount = 0
    @State private var playbackStarted = Date()

    init(initialStep: Int = 0, staticPreview: Bool = false) {
        self.staticPreview = staticPreview
        let start = min(max(initialStep, 0), TutorialStep.all.count - 1)
        _step = State(initialValue: start)
        _demoPhase = State(initialValue: staticPreview ? TutorialDemo.finalPhase(step: start) : 0)
    }

    private var current: TutorialStep { TutorialStep.all[step] }
    private var playbackKey: String { "\(step)-\(replayCount)-\(reduceMotion)" }
    private var demoCaption: String { TutorialDemo.caption(step: step, phase: demoPhase) }
    private var finalPhase: Int { TutorialDemo.finalPhase(step: step) }

    @ViewBuilder private var stepPickerHeader: some View {
        #if os(iOS)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                stepCounter
                Text("· " + UIStrings.text(current.group))
                    .font(.caption).foregroundStyle(.secondary)
                stepMenu
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    stepCounter
                    Text("· " + UIStrings.text(current.group))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    stepMenu
                }
                VStack(alignment: .leading, spacing: 6) {
                    stepCounter
                    HStack {
                        Text("· " + UIStrings.text(current.group))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        stepMenu
                    }
                }
            }
        }
        #else
        HStack(spacing: 10) {
            stepCounter
            Text("· " + UIStrings.text(current.group))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            stepMenu
        }
        #endif
    }

    private var stepCounter: some View {
        Text(UIStrings.text("Stap \(step + 1) van \(TutorialStep.all.count)"))
            .font(.caption.weight(.semibold))
            .monospacedDigit()
    }

    private var stepMenu: some View {
        Menu {
            stepMenuSection("Beginnen")
            stepMenuSection("Lezen")
            stepMenuSection("Voorbereiden")
        } label: {
            Label(UIStrings.text("Kies stap"), systemImage: "list.number")
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                       alignment: .leading)
        }
        .focusToolbarMenu()
        .help(UIStrings.text("Rechtstreeks naar een stap gaan"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(iOS)
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        stepPickerHeader
                        progressIndicator
                        previewColumn
                        instructionCard.id(step)
                    }
                }
                footer
            } else {
            header
            stepPickerHeader
            progressIndicator
            ScrollView {
                VStack(spacing: 18) {
                    previewColumn
                    instructionCard.id(step)
                }
            }
            footer
            }
            #else
            header
            stepPickerHeader
            progressIndicator
            HStack(alignment: .top, spacing: 18) {
                previewColumn
                    .frame(width: 492)
                instructionCard
                    .id(step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            footer
            #endif
        }
        .padding(22)
        .platformSheetSize(width: 900, height: 640)
        .background(AppTheme.background)
        .task(id: playbackKey) { await playDemo() }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private var progressIndicator: some View {
        ProgressView(value: Double(step + 1), total: Double(TutorialStep.all.count))
            .tint(AppTheme.accent)
    }

    @ViewBuilder private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Text(UIStrings.text("Zo werkt CommissieWijzer"))
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    closeButton
                }
                Text(UIStrings.text("Een rondleiding met fictieve voorbeelden · geen PDF of AI-model nodig"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(UIStrings.text("Zo werkt CommissieWijzer"))
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text(UIStrings.text("Een rondleiding met fictieve voorbeelden · geen PDF of AI-model nodig"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                closeButton
            }
        }
    }

    private var closeButton: some View {
        Button(UIStrings.text("Sluiten"), systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .buttonStyle(FocusToolbarActionStyle())
            .keyboardShortcut(.cancelAction)
            .help(UIStrings.text("Rondleiding sluiten"))
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            TutorialActualPreview(step: step, phase: demoPhase,
                                  playbackStarted: playbackStarted,
                                  reduceMotion: reduceMotion)
                .frame(height: 382)
                .clipped()
                .dynamicTypeSize(...DynamicTypeSize.large)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(UIStrings.text(demoCaption))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel((reduceMotion ? UIStrings.text("Stilstaand voorbeeld") + ": " : "") + UIStrings.text(demoCaption))
                if !reduceMotion {
                    Button {
                        demoPhase = 0
                        replayCount += 1
                    } label: {
                        Label(UIStrings.text("Opnieuw"), systemImage: "arrow.clockwise")
                    }
                    .font(.caption)
                    .disabled(demoPhase < finalPhase)
                    .help(UIStrings.text("Voorbeeld opnieuw afspelen"))
                }
            }
            .frame(minHeight: 30)
        }
    }

    private var instructionCard: some View {
        #if os(iOS)
        instructionContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.primary.opacity(0.07))
            }
        #else
        ScrollView {
            instructionContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.primary.opacity(0.07))
        }
        #endif
    }

    private var instructionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: current.symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                Text(UIStrings.text(current.title))
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }

            instructionSection("DOE DIT", text: current.action, symbol: "hand.tap")
            instructionSection("WAT JE ZIET", text: current.outcome, symbol: "checkmark.circle")

            Label {
                Text(UIStrings.text(current.tip))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lightbulb")
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Divider()
            Text(UIStrings.text("Dit voorbeeld verandert je documenten, analyse en instellingen niet."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func instructionSection(_ heading: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(UIStrings.text(heading), systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(UIStrings.text(text))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var footer: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                previousButton
                    .frame(maxWidth: .infinity)
                nextButton
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack {
                previousButton

                Spacer()

                nextButton
            }
        }
    }

    private var previousButton: some View {
        Button { move(to: step - 1) } label: {
            Label(UIStrings.text("Vorige"), systemImage: "chevron.left")
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                       alignment: .center)
        }
        .disabled(step == 0)
    }

    private var nextButton: some View {
        Group {
            if step < TutorialStep.all.count - 1 {
                Button { move(to: step + 1) } label: {
                    Label(UIStrings.text("Volgende"), systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                               alignment: .center)
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .tint(AppTheme.accent)
            } else {
                Button { dismiss() } label: {
                    Label(UIStrings.text("Rondleiding afronden"), systemImage: "checkmark")
                        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                               alignment: .center)
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .tint(AppTheme.accent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder private func stepMenuSection(_ title: String) -> some View {
        Section(UIStrings.text(title)) {
            ForEach(TutorialStep.all.filter { $0.group == title }) { item in
                let index = item.id
                Button {
                    move(to: index)
                } label: {
                    if index == step {
                        Label("\(index + 1). \(UIStrings.text(TutorialStep.all[index].title))", systemImage: "checkmark")
                    } else {
                        Text("\(index + 1). \(UIStrings.text(TutorialStep.all[index].title))")
                    }
                }
            }
        }
    }

    @MainActor private func playDemo() async {
        if reduceMotion {
            demoPhase = finalPhase
            return
        }
        demoPhase = 0
        playbackStarted = Date()
        while demoPhase < finalPhase {
            let delay: UInt64 = demoPhase < 2 ? 1_150_000_000 : 1_350_000_000
            do { try await Task.sleep(nanoseconds: delay) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.28)) {
                demoPhase += 1
            }
        }
    }

    private func move(to target: Int) {
        guard TutorialStep.all.indices.contains(target) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            demoPhase = reduceMotion ? TutorialDemo.finalPhase(step: target) : 0
            step = target
        }
    }

}

private enum TutorialDemo {
    private static let captions: [[String]] = [
            ["Kies ‘Pdf toevoegen…’", "Open de PDF", "CommissieWijzer leest tekst en tabellen in", "De analyse start automatisch"],
            ["Kies Wijzigen op het beginscherm", "Open het menu bij AI-provider", "Kies ChatGPT in het menu", "Na aanmelding zijn de geavanceerde modelinstellingen beschikbaar"],
            ["Kies bij Voorbereiden voor", "Bekijk Raad en de commissies", "Kies de commissie voor dit document", "Beheer eigen commissies en onderwerpen"],
            ["De commissieanalyse wordt voorbereid", "De punten worden samengesteld", "Bij programmavergelijking verschijnt een eigen pictogram", "De samenvatting wordt samengesteld", "De kernselectie wordt samengesteld. Je kunt al naar de resultaten."],
            ["Lees de documentsamenvatting", "Kies Uitgebreide samenvatting", "Open de uitgebreide samenvatting", "Lees de uitleg per PDF-pagina"],
            ["Bekijk de bronpassages in Documentoverzicht", "Kies het onderwerp Geld", "De financiële punten verschijnen", "Bekijk de kernselectie of alle punten"],
            ["Kies een aandachtspunt", "Kies de titel of samenvatting", "De PDF springt naar pagina 4", "De bijbehorende passage licht op"],
            ["Kies tekst in de PDF", "Vergroot de tekstselectie", "Kies Vat selectie samen", "De uitleg van die passage verschijnt"],
            ["Open Zoeken", "Typ fietspad", "De resultaten verschijnen", "Open een resultaat bij de bron"],
            ["Bekijk de herkende tabel", "Open het onderdeel Tabellen", "Lees de uitleg en bronpagina", "Open Afkortingen voor begrippen"],
            ["Open een aandachtspunt", "Kies Stel een vraag", "Stel je vraag in Documentchat", "Lees het antwoord met bronverwijzing"],
            ["Kies Exporteren", "Controleer titel en bestandsnaam", "Kies de onderdelen", "Controleer de export voor je bewaart"],
            ["Open Recente werkdocumenten", "Kies een eerder bewaard dossier", "Schakel iCloud desgewenst in via Opslag en export", "Open gesynchroniseerde dossiers in iCloud-bibliotheek"]
    ]

    static func finalPhase(step: Int) -> Int { captions[step].count - 1 }

    static func caption(step: Int, phase: Int) -> String {
        captions[step][min(max(phase, 0), finalPhase(step: step))]
    }
}
