# CommissieWijzer

CommissieWijzer is een macOS-app voor het lezen en voorbereiden van Nederlandse raads- en commissiestukken. De app brengt de pdf, aandachtspunten en bijbehorende bronpassages samen, zodat je AI-uitleg bij de oorspronkelijke tekst kunt controleren.

De app behoudt de bestaande lees- en analysewerkwijze. De zelfstandige CommissieWijzer-app heeft een eigen naam, app-symbool, bundle-ID, voorkeuren en opslag.

## Wat je ermee kunt

- Lees pdf’s met doorzoekbare tekst, tekstvolgorde en tabellen naast je analyse.
- Bekijk een documentoverzicht of aandachtspunten voor commissies SOD, LO en BES.
- Open een bronpassage vanuit een punt en controleer die in de oorspronkelijke pdf.
- Zoek lokaal in documenttekst, resultaten en eigen notities.
- Voeg notities en zelfgekozen passages toe aan je voorbereiding.
- Vergelijk desgewenst met een zelfgekozen partijprogramma.
- Exporteer een samenvatting of geselecteerde punten als pdf.
- Bewaar de pdf, beschikbare resultaten, notities en leespositie als werkdocument (`.spdfwork`). Het formaat blijft compatibel met bestaand werk in dat formaat. Een werkdocument opnieuw openen start geen AI-analyse.

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

De `store`-modus vereist een Mac App Distribution-identiteit, een Mac Installer Distribution-identiteit, een App Store-provisioningprofiel en een Apple Developer Team ID. Geef die via de lokale instellingen in `AppStore/Submission.local.json` of de door het script ondersteunde omgevingsvariabelen. Bewaar deze lokale account- en ondertekeningsgegevens buiten versiebeheer. De modus maakt `dist/store/CommissieWijzer.app` en `dist/CommissieWijzer-1.0.0.pkg`; het uploaden, App Store Connect invullen en inzenden blijven afzonderlijke stappen.

## App Store

De metadata en review-informatie staan in [AppStore](AppStore/Listing.md). Versie 1.0.1, build 2 is ondertekend, via Transporter afgeleverd en door Apple verwerkt; de App Store-vragenlijst en inzending zijn nog niet afgerond. De App Store-versie is in voorbereiding.

- Website: <https://syntheticdiz.github.io/CommissieWijzer>
- Ondersteuning: <https://syntheticdiz.github.io/CommissieWijzer/support.html>
- Privacy: <https://syntheticdiz.github.io/CommissieWijzer/privacy.html>
- Broncode en issues: <https://github.com/SyntheticDiz/CommissieWijzer>

## Licentie

De projectcode valt onder de MIT-licentie in [LICENSE](LICENSE). Behoud de bestaande auteursrecht- en licentietekst bij het kopiëren en herdistribueren van bestanden. Componenten van derden kunnen aanvullende voorwaarden hebben; zie [ThirdPartyLicenses](ThirdPartyLicenses/).
