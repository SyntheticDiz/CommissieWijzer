import SwiftUI

struct PatchNotesView: View {
    @Environment(\.dismiss) private var dismiss
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.0" }

    private struct Release: Identifiable {
        let version: String
        let date: String
        let changes: [String]
        var id: String { version }
    }
    // Newest release first; retain the previous release notes.
    private let releases: [Release] = [
        .init(version: "1.3.0", date: "9 november 2026", changes: [
            "Kies je eigen accentkleur via Instellingen → Algemeen. Knoppen, focus en selecties volgen je keuze op Mac en iPad; de kleur blijft op je apparaat bewaard.",
            "Stel een eigen vragenlijst samen vanuit geselecteerde punten of PDF-passages. Bewaar antwoorden en volg vragen op met de statussen Nog stellen, Beantwoord en Opvolgen.",
            "Je vragen en bronverwijzingen gaan mee in het werkdocument. Bestaande werkdocumenten blijven leesbaar; openen start geen nieuwe AI-analyse.",
            "De checklist broncontrole in het analyseoverzicht helpt je onleesbare pagina’s, ontbrekende analysedekking, onzekere tabellen en nog niet zelf gecontroleerde punten na te lopen.",
            "Vernieuwd beginscherm met recente werkdocumenten die rustig naar beneden uitklappen. De importstappen hebben herkenbare pictogrammen en consistent vormgegeven knoppen.",
            "Overzichtelijkere instellingen en een bijgewerkte rondleiding, met gedeelde kaartstijlen, verbeterde uitlijning en ondersteuning voor Verminder beweging."
        ]),
        .init(version: "1.2.0", date: "6 november 2026", changes: [
            "Optionele iCloud-bibliotheek voor bewust gekozen dossiers op Mac en iPad, met de oorspronkelijke PDF, bewaarde analyses, selecties, notities en leespositie. Lokaal werken blijft de standaard.",
            "Kies afzonderlijk of je eigen commissieprofielen meegaan. Dossiers openen en synchroniseren starten geen nieuwe AI-analyse; ChatGPT-inloggegevens blijven op het apparaat.",
            "Bij gelijktijdige wijzigingen blijft je eerdere versie als aparte kopie behouden. Zonder verbinding blijven lokale gegevens beschikbaar en worden wijzigingen later opnieuw gesynchroniseerd."
        ]),
        .init(version: "1.1.2", date: "6 november 2026", changes: [
            "Het analysewerkveld en de originele PDF staan in twee grote, netjes uitgelijnde kaarten met gelijke binnenmarges en herkenbare kleinere inhoudskaarten.",
            "Tabs en PDF-bediening horen bij hun eigen leesdeel. De verstelbare verdeling, bronacties, selecties, chat en overige functies blijven beschikbaar op Mac en iPad."
        ]),
        .init(version: "1.1.1", date: "6 november 2026", changes: [
            "Ontvang op Mac en iPad een lokale melding zodra je analyse klaar is. Bij de eerste analyse vraagt het systeem toestemming voor meldingen.",
            "Beheer de meldingen in Instellingen. De melding bevat geen documentinhoud; geannuleerde analyses geven geen klaar-melding."
        ]),
        .init(version: "1.1.0", date: "6 november 2026", changes: [
            "Maak eigen commissies met een naam, onderwerpen en aanvullende aandachtspunten. Pas de voorbeelden aan de indeling van jouw gemeente aan.",
            "Gebruik je commissies bij documentanalyse, onderwerpfilters en pdf-export. De algemene raadsanalyse blijft beschikbaar.",
            "Bewaar commissie-indelingen lokaal en neem ze mee in werkdocumenten. Eerdere analyses en notities blijven behouden wanneer je een commissie wijzigt of verwijdert."
        ]),
        .init(version: "1.0.1", date: "30 oktober 2026", changes: [
            "De analysemethode op het welkomstscherm staat nu compact en gecentreerd boven de PDF-import. De bestaande keuze en analysewerking blijven gelijk.",
            "Nieuw zakelijk CW-monogram als app-icoon, in dezelfde rustige vormentaal als Foliance."
        ]),
        .init(version: "1.0.0", date: "30 oktober 2026", changes: [
            "Bekijk de bron-pdf naast de analyse op brede schermen; op smalle iPad-schermen wissel je tussen werkbank en PDF.",
            "Analyseer lokaal met Apple Intelligence op geschikte apparaten of kies optioneel ChatGPT online.",
            "Analyseer voor de raad of een eigen commissie en vergelijk desgewenst met een zelfgekozen partijprogramma.",
            "Selecteer analysepunten, voeg notities toe en bewaar zelfgekozen bronpassages.",
            "Zoek lokaal in documenten en analyses, stel vragen via Document Chat en bewaar nuttige antwoorden.",
            "Bekijk herkende tabellen en tekstindeling en raadpleeg de afkortingenlijst.",
            "Exporteer analyses met bronverwijzingen als pdf en bewaar werkdocumenten lokaal als .spdfwork-bestanden.",
            "Open recente dossiers of kies optioneel iCloud voor geselecteerde werkdocumenten.",
            "Pas voorkeuren en meldingen aan en bekijk de rondleiding."
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Patch notes").font(.title2.bold())
            Text("Huidige versie: \(Self.version)").foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(releases) { release in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(release.version).font(.title3.bold())
                            Text(release.date).font(.caption).foregroundStyle(.secondary)
                            ForEach(release.changes, id: \.self) { change in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(change).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        if release.id != releases.last?.id { Divider() }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            HStack { Spacer(); Button(UIStrings.text("Sluiten")) { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(28).platformSheetSize(width: 560, height: 460)
        .buttonStyle(FocusSecondaryButtonStyle())
        .onPlatformExit { dismiss() }
    }
}
