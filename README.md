# CommissieWijzer

CommissieWijzer is een app voor Mac en iPad voor het lezen en voorbereiden van Nederlandse raads- en commissiestukken. De app brengt de pdf, aandachtspunten en bijbehorende bronpassages samen, zodat je AI-uitleg bij de oorspronkelijke tekst kunt controleren.

De app behoudt de bestaande lees- en analysewerkwijze. De zelfstandige CommissieWijzer-app heeft een eigen naam, app-symbool, bundle-ID, voorkeuren en opslag.

## Versie 1.3.0 (10) — 9 november 2026

Versie **1.3.0 (10)** bevat de vernieuwde interface en aanvullende voorbereidingstools voor Mac en iPad. Beide platforms bieden vijf lokaal opgeslagen accentkleuren, een bewaarde vragenlijst per werkdocument en een checklist voor broncontrole. Op 9 november zijn beide builds bij Apple ingediend en bevestigd als **Waiting for Review**, met automatische vrijgave na goedkeuring. Zie [HANDOFF](HANDOFF.md) voor uitgevoerde controles en de afzonderlijke, historische releasestatus.

## Wat je ermee kunt

- Lees pdf’s met doorzoekbare tekst, tekstvolgorde en tabellen naast je analyse.
- Bekijk een algemeen documentoverzicht of aandachtspunten voor je eigen commissies.
- Open een bronpassage vanuit een punt en controleer die in de oorspronkelijke pdf.
- Zoek lokaal in documenttekst, resultaten en eigen notities.
- Voeg notities en zelfgekozen passages toe aan je voorbereiding.
- Vergelijk desgewenst met een zelfgekozen partijprogramma.
- Exporteer een samenvatting of geselecteerde punten als pdf.
- Bewaar de pdf, beschikbare resultaten, notities en leespositie als werkdocument (`.spdfwork`). Het formaat blijft compatibel met bestaand werk in dat formaat. Een werkdocument opnieuw openen start geen AI-analyse.

Voor kleinere lees- en voorbereidingsfuncties is er ook het [volledige functieoverzicht](AppStore/Features.md), gecontroleerd tegen de huidige broncode. Daarin staan onder meer documentchat en bewaarde antwoorden, afkortingen en optioneel online opzoeken, tekstindeling en tabelcontrole, leesstatus en puntvergelijking, diagramuitleg en de beschikbare exportonderdelen. Het overzicht vermeldt ook platformverschillen en beperkingen.

## Beginscherm en voortgang

Op Mac en iPad staan analysevorm, vergaderdoel en pdf-import samen in één gecentreerde kolom. Via **Wijzigen** open je de instellingen van de AI-provider. Werkdocumenten en de optionele iCloud-bibliotheek hebben eigen knoppen. **Recente werkdocumenten** is standaard ingeklapt en opent naar beneden met dezelfde zachte animatie als de andere uitklapbare kaarten, zonder de inhoud erboven te verplaatsen. Bestaande open-, herstel- en verwijderacties blijven beschikbaar.

De eerste importanimatie blijft behouden. Daarna krijgt iedere verwerkingsfase een eigen rustig bewegend pictogram: commissie, punten, samenvatting, kernselectie en waar van toepassing programmavergelijking. De werkelijke verwerking bepaalt welk pictogram verschijnt. Bij **Verminder beweging** worden de pictogrammen statisch weergegeven.

## Instellingen

De instellingen zijn op Mac en iPad ingedeeld in **Algemeen**, **AI en verwerking**, **Voorbereiding**, **Opslag en export** en **Over en hulp**. Brede vensters hebben een zijbalk; op een smal iPad-venster open je een onderdeel vanuit het overzicht. De kop met sluitknop en de melding over automatisch bewaren blijven zichtbaar; alleen de inhoud scrolt. Grote tekst krijgt een aangepaste indeling. Wijzigingen worden automatisch opgeslagen. ChatGPT-model-, redeneer- en subagentkeuzes staan onder **Geavanceerde modelinstellingen**. Via **Wijzigen** op het beginscherm open je direct **AI en verwerking**.

| Onderdeel | Instellingen |
| --- | --- |
| Algemeen | Taal, weergave en meldingen na analyse |
| AI en verwerking | Provider, ChatGPT-account, geavanceerde modelkeuzes en Apple Intelligence-status |
| Voorbereiding | Eigen commissies en partijprogramma |
| Opslag en export | Optionele iCloud-bibliotheek en exportmap |
| Over en hulp | Handleiding, versiegeschiedenis en licenties |

Op iPad blijft de weergave donker; op Mac kun je systeem, licht of donker kiezen. Geavanceerde modelinstellingen starten ingeklapt en gebruiken de zachte kaartanimatie, met ondersteuning voor Verminder beweging.

## Rondleiding en visuele stijl

Via **Instellingen → Over en hulp** open je de rondleiding met fictieve voorbeelden. De uitleg volgt de huidige bediening voor import, AI-keuze, commissies, analysevoortgang, broncontrole, zoeken, documentchat, export, recente werkdocumenten en optionele iCloud-opslag. Op iPad beschrijft de rondleiding aanraken en Bestanden; op Mac muisbediening en bestandskeuze. De voorbeelden starten geen echte analyse of synchronisatie.

Primaire acties gebruiken een rustige cyaanblauwe knop met donkere tekst; secundaire acties blijven neutraal. Selecties en kaarten delen dezelfde kleuren op beide platforms. Waarschuwingen, fouten en verwijderacties behouden hun betekenisvolle kleur. Bij het openen van instellingen staan de kaarten direct klaar. Alleen bewust navigeren en uitklappen gebruiken de zachte overgangen, met ondersteuning voor Verminder beweging.

Op Mac en iPad kun je de accentkleur kiezen uit cyaan, blauw, groenblauw, paars en amber. De keuze wordt lokaal bewaard en toegepast in appvensters. De iPad behoudt de vaste donkere weergave.

## Werkveld en bron naast elkaar

Op brede Mac- en iPad-vensters zijn het analysewerkveld en de originele PDF elk in een grote kaart gegroepeerd, met gelijke buitenranden en binnenmarges. De bestaande analysekaarten, tabs en bronacties blijven in het werkveld beschikbaar. De PDF houdt de eigen pagina-, zoom-, selectie- en diagramfuncties. De verdeling tussen beide delen blijft verstelbaar. Op een smal iPad-venster kies je tussen het werkveld en de originele PDF; bronacties openen de PDF zoals voorheen.

## Eigen commissies

Via **Commissies beheren** bij de keuze voor het vergaderdoel of via **Instellingen → Voorbereiding** kun je commissies toevoegen, aanpassen en verwijderen. Vul een naam en onderwerpen in, en voeg desgewenst aanvullende aandachtspunten toe. Bestuur, Leefomgeving en Sociaal Domein zijn bewerkbare voorbeelden; de algemene raadsanalyse blijft beschikbaar. De onderwerpen bepalen de commissieanalyse en onderwerpindeling. Een eigen partijprogramma blijft een afzonderlijke, optionele vergelijking.

Je commissie-indeling wordt lokaal bewaard en gaat mee in een werkdocument. Bestaande analyses houden de commissieomschrijving waarmee ze zijn gemaakt, zodat het wijzigen of verwijderen van een commissie geen analyses, notities of selecties wist. Bewaren van een commissie start geen AI-verzoek. Kies bewust een vergaderdoel voor een nieuwe commissieanalyse; bewaarde analyses blijven beschikbaar voor lezen en export.

## Vragen en broncontrole

Bewaar bij een werkdocument vragen voor de vergadering, met antwoord en status: **Nog stellen**, **Beantwoord** of **Opvolgen**. Een vraag kan worden gekoppeld aan een geselecteerde pdf-passage of analysepunt; de bronverwijzing blijft bij de vraag bewaard. AI-voorstellen komen pas in de vragenlijst nadat je ze goedkeurt. Deze gegevens blijven optioneel en lokaal in het werkdocument.

De **Checklist broncontrole** wijst op pagina’s zonder leesbare tekst, leesbare pagina’s buiten de bevestigde analyse, onvolledige analyse, tabellen die aandacht vragen en analysepunten die je nog niet zelf hebt afgevinkt. Je kunt vanuit de checklist naar de bijbehorende pagina, tabel of punt gaan. De checklist helpt bepalen wat je zelf nog moet controleren en bevestigt niet dat een AI-uitkomst juist is.

## Melding na de analyse

Op Mac en iPad kan CommissieWijzer een lokale systeemmelding geven wanneer een analyse is afgerond. Bij de eerste daadwerkelijke analyse vraagt het systeem toestemming. Via **Instellingen → Algemeen → Meldingen** kun je dit uitschakelen of de toestemmingsstatus bekijken. De melding bevat geen documentnaam of documentinhoud. Een geannuleerde of mislukte analyse geeft geen melding dat alles klaar is; onvolledige resultaten worden als aandachtspunt aangeduid.

De meldingsinstelling maakt van de iPad-app geen onbeperkt achtergrondproces. iPadOS kan een analyse pauzeren wanneer de app niet actief is; de melding volgt wanneer de verwerking daadwerkelijk wordt afgerond. Systeeminstellingen en Focus bepalen hoe en wanneer een melding zichtbaar is.

## AI-keuze en privacy

Apple Intelligence is de standaard AI-provider en werkt lokaal op geschikte Macs met macOS 26 of later. CommissieWijzer zelf vereist macOS 14 of later; Apple Intelligence is niet nodig voor pdf’s openen, lokaal zoeken en andere leesfuncties.

ChatGPT is een optionele online provider. Hiervoor meld je je aan met je ChatGPT-account via OAuth; deze app heeft geen API-sleutelinstelling. Als je ChatGPT kiest, worden documentfragmenten voor de gekozen analyse en, bij programmavergelijking, het geselecteerde programma naar OpenAI verzonden. Je ChatGPT-account, toegang en gebruikslimieten gelden. ChatGPT-gesprekken worden niet door de app gelezen.

De huidige integratie gebruikt de ChatGPT-accountaanmelding en de Responses API. De aanvraag over commerciële toegang tot Sign in with ChatGPT is op 7 november 2026 ingediend; voorwaarden en toestemming voor commerciële distributie zijn nog niet bevestigd. Zie [OpenAI-integratie en aanvraagstatus](AppStore/OpenAI-Integration.md) voor de status, kosten- en toelichtingsverzoeken.

Pdf’s, werkdocumenten, notities, voorkeuren, caches en diagnostische gegevens worden lokaal op je Mac of iPad bewaard. De optionele iCloud-functie in versie 1.2.0 kan daarnaast bewust gekozen dossiers en commissieprofielen in je eigen iCloud-account bewaren. Er is geen eigen CommissieWijzer-server, account, telemetrie of tracking. De optionele online woordenlijst kan een zoekterm naar Wikipedia sturen; voor de uitleg kan de gekozen AI-provider ook documentcontext ontvangen. Zie [AppStore/Privacy.md](AppStore/Privacy.md) voor de volledige uitleg.

AI-uitkomsten kunnen onvolledig of onjuist zijn. Controleer conclusies, bedragen en citaten altijd in de bron-pdf.

## Optionele iCloud-bibliotheek — versie 1.2.0

Persoonlijke iCloud-synchronisatie staat standaard uit. De lokale lees-, analyse-, bewaar- en exportfuncties blijven zonder iCloud werken. Schakel de functie desgewenst in via **Instellingen → Opslag en export** en voeg vervolgens bewust een dossier toe via de werkdocumentacties. De oorspronkelijke pdf en het opgeslagen werk gaan dan naar de private CloudKit-opslag van je eigen Apple-account. Dossiers worden niet openbaar en er is geen samenwerking met andere accounts in deze versie.

Een afzonderlijke keuze bepaalt of je persoonlijke commissie-indeling meegaat. De bibliotheek bewaart beschikbare versies; een ontvangen indeling vervangt de lokale lijst niet stilzwijgend. Bestaande werkdocumenten behouden hun eigen commissieomschrijvingen. ChatGPT-toegang, diagnostiek, exportmappen en apparaatgebonden meldingsinstellingen worden niet meegenomen.

Synchronisatie werkt wanneer de app actief is en iCloud bereikbaar is. Gedownloade dossiers blijven lokaal leesbaar; nieuwe wijzigingen wachten bij verbindingsproblemen. Gelijktijdig gewijzigde dossiers worden als afzonderlijke versies bewaard. Open werk wordt niet automatisch door een binnenkomende versie vervangen. Uitschakelen of een dossier loskoppelen verwijdert geen lokale of iCloud-kopieën. Maak voor een onafhankelijke reservekopie zelf een export. Openen, ontvangen en synchroniseren starten geen nieuwe AI-analyse.

De normale preview-, simulator- en ongetekende apparaatbuilds hebben geen CloudKit-toegang. Een echte synchronisatietest vereist iCloud-geautoriseerde ondertekening voor beide platforms en hetzelfde Apple-account. De productietransportcode is op de Mac in de Development-omgeving live gecontroleerd met een fictief dossier: metadata, asset-upload/download, updates, geweigerde verouderde wijzigingen en commissie-assets slagen. De volledige lokaal ondertekende Mac-app heeft ook de persoonlijke Production-bibliotheek vanuit de interface succesvol ververst. Een overdracht tussen een fysieke Mac en iPad is niet getest. De eigen iCloud-container is bij Apple gekoppeld en het schema staat in Development en Production. De Mac- en iPad-profielen zijn vernieuwd en gecontroleerd.

Voor een iCloud-geactiveerde Mac Store-build gebruikt het bestaande buildscript `CW_ENABLE_ICLOUD=1` en een profiel dat CloudKit, container `iCloud.nl.commissiewijzer.app` en de Production-omgeving autoriseert. Voor een iPad-archief selecteer je daarnaast het bijpassende profielbestand via `CW_IPAD_ICLOUD_PROFILE`; `CW_ICLOUD_ENVIRONMENT` kiest Development of Production. Ontwikkelarchieven vereisen een developmentprofiel en -identiteit; Store-archieven vereisen Production en distributieondertekening. De scripts weigeren ontbrekende of onjuiste bevoegdheden. Het versiebeheerbare schema en de instructies staan in [AppStore/CloudKit](AppStore/CloudKit/README.md). Controleer schema en live overdracht voordat je een Store-versie uitbrengt. De app gebruikt de private zone `CommissieWijzerPersonal` en recordtypen `Dossier` en `CommitteeVersion`; er is geen openbare database of pushserver.

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

`preview` is de standaardmodus, dus `bash build-app.sh` doet hetzelfde. Deze ad-hoc ondertekende build maakt `dist/preview/CommissieWijzer.app`.

Voor dagelijks lokaal gebruik wordt de bestaande installatie in `dist/CommissieWijzer.app` bijgewerkt. Open geen aparte preview zonder expliciet verzoek. Bouw met `CW_ENABLE_ICLOUD=1 bash build-app.sh local-production`, controleer de ondertekende build en vervang daarna de bestaande lokale installatie met die build. Behoud Production-iCloud, het bundle-ID en alle gebruikersgegevens.

Preview, iCloud-tests en Store-builds hebben elk een eigen map, zodat een preview de lokale iCloud-app niet vervangt. De preview staat in `dist/preview/CommissieWijzer.app`. De afzonderlijke Mac Development-build gebruikt de Development-database en staat in `dist/development/CommissieWijzer.app`. Voor dagelijks lokaal gebruik dat moet synchroniseren met de iPad en de App Store-app gebruik je de gecontroleerde Production-configuratie in `dist/local-production/CommissieWijzer.app`: `CW_ENABLE_ICLOUD=1 bash build-app.sh local-production`. De build gebruikt standaard het geregistreerde Mac-profiel in `AppStore/Profiles/CommissieWijzer-iCloud-Mac-Development.provisionprofile` en kiest uitsluitend een geldige Apple Development-identiteit die in dat profiel staat. De CloudKit-entitlements gebruiken de Production-omgeving. Die map is een bouwtussenproduct; gebruik voor de dagelijkse installatie de hierboven beschreven vervanging van `dist/CommissieWijzer.app`. De ondertekende Store-app blijft in `dist/store/CommissieWijzer.app`, met het installatiepakket in `dist/CommissieWijzer-1.3.0.pkg`. Store-builds en iPad-archieven weigeren zonder expliciete `CW_ENABLE_ICLOUD=1` en een passend profiel.

Maak een universele App Store-build en ondertekend installatiepakket:

```sh
CW_ENABLE_ICLOUD=1 CW_ICLOUD_ENVIRONMENT=Production bash build-app.sh store
```

De `store`-modus vereist een Mac App Distribution-identiteit, een Mac Installer Distribution-identiteit, een App Store-provisioningprofiel en een Apple Developer Team ID. Geef die via de lokale instellingen in `AppStore/Submission.local.json` of de door het script ondersteunde omgevingsvariabelen. Bewaar deze lokale account- en ondertekeningsgegevens buiten versiebeheer. De modus maakt `dist/store/CommissieWijzer.app` en `dist/CommissieWijzer-1.3.0.pkg`.

## App Store

De metadata en review-informatie staan in [AppStore](AppStore/Listing.md). Op 9 november 2026 zijn Mac en iPad **1.3.0 (10)** ingediend en beide bevestigd als **Waiting for Review**. Beide behouden automatische vrijgave na goedkeuring. De iPad-app is al beschikbaar in de [App Store](https://apps.apple.com/nl/app/commissiewijzer/id6829018818); update 1.3 wacht nog op beoordeling. De zes bestaande store-dia’s per platform blijven behouden, met de tagline “Jouw stukken. Jouw inzichten. Jouw koers.” Zie [de ontwikkel- en releasestatus](HANDOFF.md) voor verificatie en historische status.

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

`device` controleert een Release-build voor een echte iPad zonder ondertekening. Voor installatie op een apparaat of distributie is Apple-ondertekening nodig. Voor een Store-archief stel je lokaal `CW_DEVELOPMENT_TEAM`, `CW_IPAD_ICLOUD_PROFILE` (het profielbestand voor deze app), `CW_ENABLE_ICLOUD=1` en `CW_ICLOUD_ENVIRONMENT=Production` in en voer je `bash build-ipad.sh archive` uit. Het script controleert het profiel vóór het bouwen en gebruikt het bijbehorende distributiecertificaat. Bewaar account- en ondertekeningsgegevens buiten versiebeheer. De bestaande Mac-build en het ingediende Mac-pakket worden hiermee niet vervangen.

Beide platforms gebruiken bundle-ID `nl.commissiewijzer.app` en hetzelfde App Store Connect-record. De laatst vastgelegde inzending voor beide platforms is **1.3.0 (10)** op 9 november 2026. Zie het App Store-overzicht hierboven en de releasegeschiedenis in [HANDOFF.md](HANDOFF.md).

Werkdocumenten (`.spdfwork`, formaat 1) zijn op beide apparaten te openen, inclusief de oorspronkelijke pdf, notities, selectie, leespositie en bewaarde resultaten. Op iPad wordt een geopend werkdocument naar lokale appopslag gekopieerd; recente documenten verwijzen naar die lokale werkkopie. Bewaren via Bestanden exporteert een overdraagbare kopie. Latere lokale wijzigingen werken een eerder geëxporteerde kopie niet automatisch bij: bewaar opnieuw voordat je het bestand naar de Mac overzet. De afzonderlijke, optionele iCloud-bibliotheek in versie 1.2.0 is bedoeld voor automatische overdracht van bewust gekozen dossiers. Een gewone bestandsimport of -export schakelt die functie niet in. Kies zelf een locatie in Bestanden; een door de gebruiker gekozen cloudprovider valt onder die provider.

De iPad-accountaanmelding opent de systeem-Safariweergave binnen de app zodat de beveiligde loopbackaanmelding actief blijft. De bestaande PKCE-, state-, nonce- en tokencontroles blijven gedeeld. Accountgegevens staan in de lokale sleutelhanger en worden niet in werkdocumenten opgenomen.

De iPad-testtarget voert dezelfde appregressietests uit als de Mac. `Tests/Fixtures/mac-v1.spdfwork` is uitsluitend fictieve testdata, gegenereerd door de Mac-archieftest. De portabiliteitstest controleert alle archiefvelden en schrijft op de simulator `Documents/iPad-RoundTrip.spdfwork`, dat ook weer met de Mac-test kan worden geopend.

## Licentie

De projectcode valt onder de MIT-licentie in [LICENSE](LICENSE). Behoud de bestaande auteursrecht- en licentietekst bij het kopiëren en herdistribueren van bestanden. Componenten van derden kunnen aanvullende voorwaarden hebben; zie [ThirdPartyLicenses](ThirdPartyLicenses/).
