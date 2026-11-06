# CommissieWijzer

CommissieWijzer is een app voor Mac en iPad voor het lezen en voorbereiden van Nederlandse raads- en commissiestukken. De app brengt de pdf, aandachtspunten en bijbehorende bronpassages samen, zodat je AI-uitleg bij de oorspronkelijke tekst kunt controleren.

De app behoudt de bestaande lees- en analysewerkwijze. De zelfstandige CommissieWijzer-app heeft een eigen naam, app-symbool, bundle-ID, voorkeuren en opslag.

## Wat je ermee kunt

- Lees pdf’s met doorzoekbare tekst, tekstvolgorde en tabellen naast je analyse.
- Bekijk een algemeen documentoverzicht of aandachtspunten voor je eigen commissies.
- Open een bronpassage vanuit een punt en controleer die in de oorspronkelijke pdf.
- Zoek lokaal in documenttekst, resultaten en eigen notities.
- Voeg notities en zelfgekozen passages toe aan je voorbereiding.
- Vergelijk desgewenst met een zelfgekozen partijprogramma.
- Exporteer een samenvatting of geselecteerde punten als pdf.
- Bewaar de pdf, beschikbare resultaten, notities en leespositie als werkdocument (`.spdfwork`). Het formaat blijft compatibel met bestaand werk in dat formaat. Een werkdocument opnieuw openen start geen AI-analyse.

## Werkveld en bron naast elkaar

Op brede Mac- en iPad-vensters zijn het analysewerkveld en de originele PDF elk in een grote kaart gegroepeerd, met gelijke buitenranden en binnenmarges. De bestaande analysekaarten, tabs en bronacties blijven in het werkveld beschikbaar. De PDF houdt de eigen pagina-, zoom-, selectie- en diagramfuncties. De verdeling tussen beide delen blijft verstelbaar. Op een smal iPad-venster kies je tussen het werkveld en de originele PDF; bronacties openen de PDF zoals voorheen.

## Eigen commissies

Via **Commissies beheren** bij de keuze voor het vergaderdoel of in Instellingen kun je commissies toevoegen, aanpassen en verwijderen. Vul een naam en onderwerpen in, en voeg desgewenst aanvullende aandachtspunten toe. Bestuur, Leefomgeving en Sociaal Domein zijn bewerkbare voorbeelden; de algemene raadsanalyse blijft beschikbaar. De onderwerpen bepalen de commissieanalyse en onderwerpindeling. Een eigen partijprogramma blijft een afzonderlijke, optionele vergelijking.

Je commissie-indeling wordt lokaal bewaard en gaat mee in een werkdocument. Bestaande analyses houden de commissieomschrijving waarmee ze zijn gemaakt, zodat het wijzigen of verwijderen van een commissie geen analyses, notities of selecties wist. Bewaren van een commissie start geen AI-verzoek. Kies bewust een vergaderdoel voor een nieuwe commissieanalyse; bewaarde analyses blijven beschikbaar voor lezen en export.

## Melding na de analyse

Op Mac en iPad kan CommissieWijzer een lokale systeemmelding geven wanneer een analyse is afgerond. Bij de eerste daadwerkelijke analyse vraagt het systeem toestemming. Via **Instellingen → Meldingen** kun je dit uitschakelen of de toestemmingsstatus bekijken. De melding bevat geen documentnaam of documentinhoud. Een geannuleerde of mislukte analyse geeft geen melding dat alles klaar is; onvolledige resultaten worden als aandachtspunt aangeduid.

De meldingsinstelling maakt van de iPad-app geen onbeperkt achtergrondproces. iPadOS kan een analyse pauzeren wanneer de app niet actief is; de melding volgt wanneer de verwerking daadwerkelijk wordt afgerond. Systeeminstellingen en Focus bepalen hoe en wanneer een melding zichtbaar is.

## AI-keuze en privacy

Apple Intelligence is de standaard AI-provider en werkt lokaal op geschikte Macs met macOS 26 of later. CommissieWijzer zelf vereist macOS 14 of later; Apple Intelligence is niet nodig voor pdf’s openen, lokaal zoeken en andere leesfuncties.

ChatGPT is een optionele online provider. Hiervoor meld je je aan met je ChatGPT-account via OAuth; deze app heeft geen API-sleutelinstelling. Als je ChatGPT kiest, worden documentfragmenten voor de gekozen analyse en, bij programmavergelijking, het geselecteerde programma naar OpenAI verzonden. Je ChatGPT-account, toegang en gebruikslimieten gelden. ChatGPT-gesprekken worden niet door de app gelezen.

Pdf’s, werkdocumenten, notities, voorkeuren, caches en diagnostische gegevens worden lokaal op je Mac bewaard. Er is geen eigen CommissieWijzer-server, account, telemetrie of tracking. De optionele online woordenlijst kan een zoekterm naar Wikipedia sturen; voor de uitleg kan de gekozen AI-provider ook documentcontext ontvangen. Zie [AppStore/Privacy.md](AppStore/Privacy.md) voor de volledige uitleg.

AI-uitkomsten kunnen onvolledig of onjuist zijn. Controleer conclusies, bedragen en citaten altijd in de bron-pdf.

## Vereisten en bouwen

- macOS 14 of later
- Een Swift-toolchain die bij `Package.swift` past
- Xcode Command Line Tools voor het bouwen van de app-bundel en het symbool

Bouw het pakket:

```sh
swift build -c release
```

Maak een lokale preview-app-bundel:

```sh
bash build-app.sh preview
```

`preview` is de standaardmodus, dus `bash build-app.sh` doet hetzelfde. Deze ad-hoc ondertekende build maakt `dist/CommissieWijzer.app`.

Maak een universele App Store-build en ondertekend installatiepakket:

```sh
bash build-app.sh store
```

De `store`-modus vereist een Mac App Distribution-identiteit, een Mac Installer Distribution-identiteit, een App Store-provisioningprofiel en een Apple Developer Team ID. Geef die via de lokale instellingen in `AppStore/Submission.local.json` of de door het script ondersteunde omgevingsvariabelen. Bewaar deze lokale account- en ondertekeningsgegevens buiten versiebeheer. De modus maakt `dist/store/CommissieWijzer.app` en `dist/CommissieWijzer-1.1.2.pkg`.

## App Store

De metadata en review-informatie staan in [AppStore](AppStore/Listing.md). De nieuwe Mac- en iPad-versie is **1.1.2 (7)**, met eigen commissies, lokale analysemeldingen en de uitgelijnde werkveld-/PDF-kaarten. De ondertekende Mac-build is op 6 november 2026 naar Apple geüpload en verwerkt; de eerdere Mac-inzending is uit review gehaald om de nieuwe build te kunnen indienen. De iPad-upload en beide nieuwe indieningen worden voorbereid. De bestaande Apple-teksten en vrijgavekeuzes blijven behouden: Mac handmatig, iPad automatisch na goedkeuring.

- Website: <https://syntheticdiz.github.io/CommissieWijzer/>
- Ondersteuning: <https://syntheticdiz.github.io/CommissieWijzer/support.html>
- Privacy: <https://syntheticdiz.github.io/CommissieWijzer/privacy.html>
- Broncode en issues: <https://github.com/SyntheticDiz/CommissieWijzer>

## iPadOS

De iPad-app gebruikt dezelfde Swift-bronnen, analyseproviders, zoekondersteuning, exportlogica en het ongewijzigde werkdocumentformaat als de Mac-app. De donkere kleuren, typografie, kaarten en knopstijlen worden gedeeld. Op brede vensters staan werkveld en bron-pdf naast elkaar; op smalle vensters wissel je tussen Werkveld en Originele pdf. Pdf-selectie, bronmarkeringen, de passagelezer en bestandsdialoog gebruiken native UIKit/PDFKit. iPadOS 26 of later is vereist; de Apple-beeldanalyse van diagrammen vereist iPadOS 27 en een beschikbaar model, zoals de overeenkomstige Mac-functie macOS 27 vereist.

Open `iPadOS/CommissieWijzer.xcodeproj` en kies het schema **CommissieWijzer-iPad**, of bouw vanaf de commandoregel:

```sh
CW_DEVELOPMENT_TEAM=JOUW_TEAM_ID bash build-ipad.sh simulator
bash build-ipad.sh device
```

De simulatorbuild vereist een team-ID en wordt ad-hoc ondertekend, zodat iPadOS de eigen sleutelhanger kan gebruiken. Een ongetekende simulatorbuild mist die app-identiteit en kan ChatGPT-aanmeldgegevens niet bewaren. De team-ID wordt uitsluitend lokaal via de omgevingsvariabele ingesteld.

`device` controleert een Release-build voor een echte iPad zonder ondertekening. Voor installatie op een apparaat of distributie is Apple-ondertekening nodig. Voor een ondertekend archief: stel lokaal `CW_DEVELOPMENT_TEAM` in en voer `bash build-ipad.sh archive` uit. Standaard gebruikt Xcode automatische ondertekening. Met `CW_IPAD_PROVISIONING_PROFILE` kies je expliciet een reeds geïnstalleerd iOS App Store-profiel en een bestaand Apple Distribution-certificaat. Bewaar account- en ondertekeningsgegevens buiten versiebeheer. De bestaande Mac-build en het ingediende Mac-pakket worden hiermee niet vervangen.

Beide platforms gebruiken bundle-ID `nl.commissiewijzer.app` en hetzelfde App Store Connect-record. De iPad-versie **1.0.1 (3)** is inmiddels **Ready for Distribution**. De eerdere ontwikkelbuild 1.0.1 (4) is niet aan die inzending gekoppeld. Voor de update naar **1.1.2 (7)** staat een nieuwe iPad-versie klaar in App Store Connect; de definitieve upload en indiening worden voorbereid. Een upload of indiening betekent nog geen goedkeuring van de nieuwe versie.

Werkdocumenten (`.spdfwork`, formaat 1) zijn op beide apparaten te openen, inclusief de oorspronkelijke pdf, notities, selectie, leespositie en bewaarde resultaten. Op iPad wordt een geopend werkdocument naar lokale appopslag gekopieerd; recente documenten verwijzen naar die lokale werkkopie. Bewaren via Bestanden exporteert een overdraagbare kopie. Latere lokale wijzigingen werken een eerder geëxporteerde kopie niet automatisch bij: bewaar opnieuw voordat je het bestand naar de Mac overzet. Er is geen automatische synchronisatie of samenvoeging tussen apparaten. Kies zelf een locatie in Bestanden; een door de gebruiker gekozen cloudprovider valt onder die provider.

De iPad-accountaanmelding opent de systeem-Safariweergave binnen de app zodat de beveiligde loopbackaanmelding actief blijft. De bestaande PKCE-, state-, nonce- en tokencontroles blijven gedeeld. Accountgegevens staan in de lokale sleutelhanger en worden niet in werkdocumenten opgenomen.

De iPad-testtarget voert dezelfde appregressietests uit als de Mac. `Tests/Fixtures/mac-v1.spdfwork` is uitsluitend fictieve testdata, gegenereerd door de Mac-archieftest. De portabiliteitstest controleert alle archiefvelden en schrijft op de simulator `Documents/iPad-RoundTrip.spdfwork`, dat ook weer met de Mac-test kan worden geopend.

## Licentie

De projectcode valt onder de MIT-licentie in [LICENSE](LICENSE). Behoud de bestaande auteursrecht- en licentietekst bij het kopiëren en herdistribueren van bestanden. Componenten van derden kunnen aanvullende voorwaarden hebben; zie [ThirdPartyLicenses](ThirdPartyLicenses/).
