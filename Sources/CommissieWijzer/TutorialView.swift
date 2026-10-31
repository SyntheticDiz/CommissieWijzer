import SwiftUI

private struct TutorialStep: Identifiable {
    let id: Int
    let group: String
    let title: String
    let action: String
    let outcome: String
    let tip: String
    let symbol: String

    static let all: [TutorialStep] = [
        .init(id: 0, group: "Beginnen", title: "Een PDF openen",
              action: "Sleep een PDF naar het startvak of kies ‘Pdf toevoegen…’. Kies daar ook Raad of de commissie waarvoor je het stuk voorbereidt.",
              outcome: "CommissieWijzer leest tekst, leesvolgorde en tabellen in. Daarna start de gekozen AI-analyse automatisch.",
              tip: "Bij een scan zonder leesbare tekstlaag kan tekstherkenning nodig zijn.", symbol: "doc.badge.plus"),
        .init(id: 1, group: "Beginnen", title: "Een AI-provider kiezen",
              action: "Open Instellingen en kies Apple Intelligence of ChatGPT. Stel bij ChatGPT ook het gewenste model in.",
              outcome: "Deze keuze bepaalt welke voorziening CommissieWijzer gebruikt wanneer je een AI-analyse start. ChatGPT verwerkt documentinhoud online; Apple Intelligence werkt met het beschikbare lokale model.",
              tip: "Voor Apple Intelligence moet een ondersteund model op deze Mac beschikbaar zijn. ChatGPT vereist internet en een geschikte aangemelde account.", symbol: "sparkles"),
        .init(id: 2, group: "Beginnen", title: "Doel en analysemethode kiezen",
              action: "Kies bij het toevoegen van de PDF Raad of de passende commissie. Kies in de bedieningsbalk Neutrale samenvatting of Vergelijk met partijprogramma.",
              outcome: "De commissiekeuze bepaalt voor welke commissie passages op relevantie en belang worden beoordeeld. Een programmavergelijking gebruikt het partijprogramma dat je zelf hebt toegevoegd.",
              tip: "Voeg een partijprogramma toe via Instellingen. Een aanvullende focus vind je onder Analyseopties.", symbol: "slider.horizontal.3"),
        .init(id: 3, group: "Beginnen", title: "De analyse volgen en controleren",
              action: "Volg de status en resterende tijd in de bedieningsbalk. Stop analyse breekt de lopende AI-verwerking af.",
              outcome: "Beschikbare resultaten blijven zichtbaar. Bij een gekozen commissie kan ook een aparte commissiebeoordeling lopen. Stoppen tijdens het inlezen annuleert de PDF-import en brengt je terug naar het importscherm.",
              tip: "Meldingen over overgeslagen pagina’s of onvolledige resultaten staan bij het analyseoverzicht. Open de details voor de reden en herstelacties.", symbol: "play.circle"),
        .init(id: 4, group: "Lezen", title: "De samenvatting lezen",
              action: "Open Overzicht en lees de documentsamenvatting. Kies Uitgebreide samenvatting voor de uitleg per fysieke PDF-pagina.",
              outcome: "Je ziet zowel het grote geheel als waar informatie in het document staat.",
              tip: "Je kunt een paginabereik opgeven om alleen dat deel samen te vatten.", symbol: "text.alignleft"),
        .init(id: 5, group: "Lezen", title: "Punten en bronpassages bekijken",
              action: "Bekijk de concrete bronpassages in Overzicht. Open Punten en wissel tussen Belangrijkste en Alle punten.",
              outcome: "Bij Raad toont Belangrijkste de kernselectie; bij een commissie de belangrijk beoordeelde passages. Alle punten houdt het volledige beschikbare resultaat bereikbaar.",
              tip: "Klik op de titel of samenvatting van een punt om de bijbehorende brontekst in de PDF te controleren.", symbol: "list.bullet.rectangle"),
        .init(id: 6, group: "Lezen", title: "Een punt controleren in de bron",
              action: "Klik op de titel of samenvatting van een aandachtspunt.",
              outcome: "De PDF springt naar de genoemde fysieke pagina en markeert de bijbehorende passage.",
              tip: "Controleer bedragen, voorwaarden en conclusies in de oorspronkelijke tekst.", symbol: "arrow.right.doc.on.clipboard"),
        .init(id: 7, group: "Lezen", title: "Zelf een passage kiezen",
              action: "Selecteer met de muis tekst in de PDF en laat de muisknop los. Kies daarna Vat selectie samen.",
              outcome: "CommissieWijzer geeft uitleg bij het geselecteerde fragment en vermeldt de bronpagina.",
              tip: "De tekst moet selecteerbaar zijn in de PDF.", symbol: "text.cursor"),
        .init(id: 8, group: "Lezen", title: "In het document zoeken",
              action: "Open Zoeken of druk op ⌘F en typ een woord of naam.",
              outcome: "Zoeken doorzoekt lokaal de PDF-tekst en beschikbare samenvattingen, punten, tabellen en afkortingen. Een resultaat opent de puntkaart of bronpassage.",
              tip: "Een zoekopdracht start geen nieuwe AI-aanvraag.", symbol: "magnifyingglass"),
        .init(id: 9, group: "Voorbereiden", title: "Tabellen en afkortingen begrijpen",
              action: "Open Tabellen voor de herkende cijfers en hun uitleg. Open Afkortingen voor gevonden betekenissen en vindplaatsen.",
              outcome: "Bij een tabel zie je de uitleg naast de oorspronkelijke bronpagina. Ontbrekende betekenissen kun je optioneel online aanvullen.",
              tip: "Controleer een cijfervergelijking altijd in de oorspronkelijke tabel.", symbol: "tablecells"),
        .init(id: 10, group: "Voorbereiden", title: "Vragen stellen en punten bewaren",
              action: "Stel in Documentchat een gerichte vraag. Gebruik de ster bij een punt om het aan Mijn selectie toe te voegen.",
              outcome: "Antwoorden kunnen bronverwijzingen tonen; je bewaarde punten vind je terug in Mijn selectie.",
              tip: "Controleer het antwoord via de bronverwijzingen. Chatgesprekken en selectie blijven bij het document bewaard.", symbol: "bubble.left.and.bubble.right"),
        .init(id: 11, group: "Voorbereiden", title: "Een PDF-export maken",
              action: "Kies Exporteren, vink de gewenste onderdelen aan en controleer titel en bestandsnaam voordat je de PDF bewaart.",
              outcome: "De export kan onder meer samenvatting, punten, vragen, tabeluitleg, afkortingen en bronnen bevatten.",
              tip: "Export maakt een deelbare PDF. Bewaar een werkdocument met ⌘S om later verder te werken met resultaten en selectie.", symbol: "square.and.arrow.up")
    ]
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private let staticPreview: Bool
    private var reduceMotion: Bool { staticPreview || systemReduceMotion }
    @State private var step = 0
    @State private var demoPhase = 0
    @State private var replayCount = 0
    @State private var playbackStarted = Date()

    init(initialStep: Int = 0, staticPreview: Bool = false) {
        self.staticPreview = staticPreview
        _step = State(initialValue: min(max(initialStep, 0), TutorialStep.all.count - 1))
    }

    private var current: TutorialStep { TutorialStep.all[step] }
    private var playbackKey: String { "\(step)-\(replayCount)-\(reduceMotion)" }
    private var demoCaption: String { TutorialDemo.caption(step: step, phase: demoPhase) }

    private var stepPickerHeader: some View {
        #if os(iOS)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                stepCounter
                Text("· " + tutorialText(current.group))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                stepMenu
            }
            VStack(alignment: .leading, spacing: 6) {
                stepCounter
                HStack {
                    Text("· " + tutorialText(current.group))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    stepMenu
                }
            }
        }
        #else
        HStack(spacing: 10) {
            stepCounter
            Text("· " + tutorialText(current.group))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            stepMenu
        }
        #endif
    }

    private var stepCounter: some View {
        Text(tutorialText("Stap \(step + 1) van \(TutorialStep.all.count)"))
            .font(.caption.weight(.semibold))
            .monospacedDigit()
    }

    private var stepMenu: some View {
        Menu {
            stepMenuSection("Beginnen", range: 0..<4)
            stepMenuSection("Lezen", range: 4..<9)
            stepMenuSection("Voorbereiden", range: 9..<12)
        } label: {
            Label(UIStrings.text("Kies stap"), systemImage: "list.number")
        }
        .focusToolbarMenu()
        .help(UIStrings.text("Rechtstreeks naar een stap gaan"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            stepPickerHeader
            ProgressView(value: Double(step + 1), total: Double(TutorialStep.all.count))
                .tint(AppTheme.accent)

            #if os(macOS)
            HStack(alignment: .top, spacing: 18) {
                previewColumn
                    .frame(width: 492)
                instructionCard
                    .id(step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            #else
            ScrollView {
                VStack(spacing: 18) {
                    previewColumn
                    instructionCard.id(step)
                }
            }
            #endif

            footer
        }
        .padding(22)
        .platformSheetSize(width: 900, height: 640)
        .background(AppTheme.background)
        .task(id: playbackKey) { await playDemo() }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(UIStrings.text("Zo werkt CommissieWijzer"))
                    .font(.title2.bold())
                Text(UIStrings.text("Een rondleiding met fictieve voorbeelden · geen PDF of AI-model nodig"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(UIStrings.text("Sluiten"), systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(FocusToolbarActionStyle())
                .keyboardShortcut(.cancelAction)
                .help(UIStrings.text("Rondleiding sluiten"))
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            TutorialActualPreview(step: step, phase: demoPhase,
                                  playbackStarted: playbackStarted,
                                  reduceMotion: reduceMotion)
                .frame(height: 382)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(tutorialText(demoCaption))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel((reduceMotion ? tutorialText("Stilstaand voorbeeld") + ": " : "") + tutorialText(demoCaption))
                if !reduceMotion {
                    Button {
                        demoPhase = 0
                        replayCount += 1
                    } label: {
                        Label(UIStrings.text("Opnieuw"), systemImage: "arrow.clockwise")
                    }
                    .font(.caption)
                    .disabled(demoPhase < 3)
                    .help(UIStrings.text("Voorbeeld opnieuw afspelen"))
                }
            }
            .frame(minHeight: 30)
        }
    }

    private var instructionCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: current.symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    Text(tutorialText(current.title))
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }

                instructionSection("DOE DIT", text: current.action, symbol: "hand.tap")
                instructionSection("WAT JE ZIET", text: current.outcome, symbol: "checkmark.circle")

                Label {
                    Text(tutorialText(current.tip))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(AppTheme.accent)
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Divider()
                Text(tutorialText("Dit voorbeeld verandert je documenten, analyse en instellingen niet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.primary.opacity(0.07))
        }
    }

    private func instructionSection(_ heading: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(UIStrings.text(heading), systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(tutorialText(text))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                move(to: step - 1)
            } label: {
                Label(UIStrings.text("Vorige"), systemImage: "chevron.left")
            }
            .disabled(step == 0)

            Spacer()

            if step < TutorialStep.all.count - 1 {
                Button {
                    move(to: step + 1)
                } label: {
                    Label(UIStrings.text("Volgende"), systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .tint(AppTheme.accent)
            } else {
                Button {
                    dismiss()
                } label: {
                    Label(UIStrings.text("Rondleiding afronden"), systemImage: "checkmark")
                }
                .buttonStyle(FocusPrimaryButtonStyle())
                .tint(AppTheme.accent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder private func stepMenuSection(_ title: String, range: Range<Int>) -> some View {
        Section(UIStrings.text(title)) {
            ForEach(range, id: \.self) { index in
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
            demoPhase = 3
            return
        }
        demoPhase = 0
        playbackStarted = Date()
        while demoPhase < 3 {
            let delays: [UInt64] = [1_150_000_000, 1_150_000_000, 1_350_000_000]
            do { try await Task.sleep(nanoseconds: delays[demoPhase]) }
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
            demoPhase = reduceMotion ? 3 : 0
            step = target
        }
    }

    /// The shared tour retains its Mac wording on macOS while explaining the same
    /// actions in terms of touch on iPad.
    private func tutorialText(_ value: String) -> String {
        let text = UIStrings.text(value)
        #if os(iOS)
        return text
            .replacingOccurrences(of: "Sleep een PDF naar het startvak of kies ‘Pdf toevoegen…’", with: "Kies ‘Pdf toevoegen…’")
            .replacingOccurrences(of: "Drag a PDF to the start area or choose ‘Add PDF…’", with: "Choose ‘Add PDF…’")
            .replacingOccurrences(of: "Drop a PDF in the start area or choose ‘Add PDF…’", with: "Choose ‘Add PDF…’")
            .replacingOccurrences(of: "Sleep de PDF naar het startvak", with: "Kies ‘Pdf toevoegen…’")
            .replacingOccurrences(of: "Laat de PDF boven het vak los", with: "Open de PDF")
            .replacingOccurrences(of: "Selecteer met de muis tekst in de PDF en laat de muisknop los.", with: "Houd je vinger op tekst in de PDF en sleep om die te selecteren.")
            .replacingOccurrences(of: "Select text in the PDF with the mouse and release the mouse button.", with: "Touch and drag across text in the PDF to select it.")
            .replacingOccurrences(of: "Select text in the PDF with the mouse, then release the button.", with: "Touch and drag across text in the PDF to select it.")
            .replacingOccurrences(of: "Plaats de aanwijzer op de PDF-tekst", with: "Houd je vinger op de PDF-tekst")
            .replacingOccurrences(of: "Sleep over de tekst met de muisknop ingedrukt", with: "Houd je vinger op de tekst en sleep")
            .replacingOccurrences(of: "Hold the pointer over the PDF text", with: "Touch and hold the PDF text")
            .replacingOccurrences(of: "Move the pointer over the PDF text", with: "Touch and hold the PDF text")
            .replacingOccurrences(of: "Drag across the text while holding the mouse button", with: "Touch and drag across the text")
            .replacingOccurrences(of: "Klik op", with: "Tik op")
            .replacingOccurrences(of: "Click the", with: "Tap the")
            .replacingOccurrences(of: "Klik", with: "Tik")
            .replacingOccurrences(of: "Wijs ", with: "Kies ")
            .replacingOccurrences(of: "Hover over", with: "Choose")
            .replacingOccurrences(of: "Open Zoeken of druk op ⌘F", with: "Open Zoeken en typ een woord of naam")
            .replacingOccurrences(of: "Open Search or press ⌘F and enter a word or name.", with: "Open Search and type a word or name.")
            .replacingOccurrences(of: "druk op ⌘F", with: "open Zoeken")
            .replacingOccurrences(of: "press ⌘F", with: "open Search")
            .replacingOccurrences(of: "Bewaar een werkdocument met ⌘S om later verder te werken met resultaten en selectie.", with: "Bewaar het werkdocument om later verder te werken met resultaten en selectie.")
            .replacingOccurrences(of: "Save a work document with ⌘S to continue later with your results and selection.", with: "Save the workspace to continue later with results and selections.")
        #else
        return text
        #endif
    }
}

private enum TutorialDemo {
    static func caption(step: Int, phase: Int) -> String {
        let captions: [[String]] = [
            ["Sleep de PDF naar het startvak", "Laat de PDF boven het vak los", "CommissieWijzer leest tekst en tabellen in", "De analyse start automatisch"],
            ["Open Instellingen → AI-provider", "Kies Apple Intelligence of ChatGPT", "Kies ChatGPT in het menu", "De gekozen provider is ingesteld"],
            ["Kies een analysemethode", "Wijs Vergelijk met partijprogramma aan", "De vergelijking wordt gekozen", "Voeg je programma toe via Instellingen"],
            ["Bekijk de analyse-status", "De verwerking wordt voorbereid", "Volg voortgang en resterende tijd", "De beschikbare resultaten verschijnen"],
            ["Lees de documentsamenvatting", "Wijs Uitgebreide samenvatting aan", "Open de uitgebreide samenvatting", "Lees de uitleg per PDF-pagina"],
            ["Bekijk de bronpassages in Overzicht", "Kies het onderwerp Geld", "De financiële punten verschijnen", "Elk punt biedt een bronverwijzing"],
            ["Kies een aandachtspunt", "Klik op de kaarttekst", "De PDF springt naar pagina 4", "De bijbehorende passage licht op"],
            ["Plaats de aanwijzer op de PDF-tekst", "Sleep over de tekst met de muisknop ingedrukt", "Laat los: Vat selectie samen verschijnt", "De uitleg van die passage verschijnt"],
            ["Open Zoeken of druk op ⌘F", "Typ fietspad", "De resultaten verschijnen", "Open een resultaat bij de bron"],
            ["Bekijk de herkende tabel", "Open het onderdeel Tabellen", "Lees de uitleg en bronpagina", "Open Afkortingen voor begrippen"],
            ["Open een aandachtspunt", "Kies Stel een vraag", "Documentchat opent met je vraag", "Lees het antwoord met bronverwijzing"],
            ["Kies Exporteren", "Controleer titel en bestandsnaam", "Kies de onderdelen", "Controleer de export voor je bewaart"]
        ]
        guard captions.indices.contains(step) else { return "Voorbeeld gereed" }
        return captions[step][min(max(phase, 0), 3)]
    }
}
