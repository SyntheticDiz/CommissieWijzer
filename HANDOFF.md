# CommissieWijzer — ontwikkel- en releasestatus

Bijgewerkt op 30 oktober 2026. Dit bestand beschrijft de huidige fork en de status van de Mac App Store-release.

## Product

CommissieWijzer is een zelfstandige macOS-app voor het lezen en voorbereiden van raads- en commissiestukken. De app behoudt de bestaande lees- en analysewerking, met een eigen productnaam, icoon, bundle-ID, voorkeuren en opslag. Werkdocumenten blijven compatibel met de extensie `.spdfwork`.

De app ondersteunt bronpassages, lokale zoekopdrachten, notities, geselecteerde passages, optionele vergelijking met een door de gebruiker gekozen programma en pdf-export. De belangrijkste commissie-indelingen zijn SOD, LO en BES.

Minimale versie: macOS 14. Apple Intelligence vereist macOS 26 of later en geschikte Apple-hardware. ChatGPT is optioneel, verloopt via OpenAI OAuth en gebruikt het ChatGPT-account van de gebruiker. De app heeft geen API-sleutelprovider.

## Privacyfeiten

- Pdf’s, werkdocumenten, analysecache, voorkeuren, notities en technische diagnostiek worden lokaal opgeslagen.
- Apple Intelligence-verwerking vindt lokaal plaats op geschikte systemen.
- Bij ChatGPT worden de voor de gekozen taak benodigde documentfragmenten en, waar van toepassing, het gekozen programma rechtstreeks met OpenAI gedeeld. OAuth levert een e-mailadres en stabiele accountidentifier op; een vaste, willekeurige hostidentifier wordt voor de OAuth-aanvraag gebruikt. Tokens en accountgegevens staan in de macOS-sleutelhanger. De app leest geen ChatGPT-gesprekken.
- De optionele woordenlijst kan Wikipedia raadplegen. Voor AI-uitleg kan de geselecteerde provider de term, beperkte documentcontext en gevonden brontekst ontvangen.
- De app heeft geen eigen backend, account, telemetrie of tracking. ChatGPT-diagnostiek bevat geen documenttekst, prompts, antwoordtekst of volledige serverresponses.

## Release en verificatie

- Versie: **1.0.1**; build: **2**.
- Het universele Mac App Store-pakket is ondertekend, strict geverifieerd en door de release-audit gekomen.
- Het pakket is op 30 oktober om 21:00 via Transporter afgeleverd en verwerkt. App Store Connect toont het als gereed voor interne tests.
- De build is **nog niet ingediend voor Apple-review**.
- Er zijn drie gecontroleerde screenshots van 2560 × 1600 pixels. Ze tonen een fictief voorbeeld en bevatten geen persoonsgegevens.
- Een lokale Apple Intelligence-analyse op het fictieve voorbeeld werkte. De samenvatting beschreef in die run een voorgesteld besluit alsof het al was genomen. Controleer de samenvatting daarom aan de hand van de bronpassage in de pdf. De bestaande functionaliteit is behouden.

## Nog te doen voor inzending

- Rond de App Store Connect-privacyvragen en productgegevens af op basis van de definitieve build.
- Publiceer en controleer de privacy- en ondersteuningspagina’s. De nieuwe GitHub Pages-site is nog in publicatievoorbereiding en is niet live.
- Dien de build pas na die controles in voor Apple-review.

## Bronnen en projectdocumentatie

- Broncode staat online op `main`, commit `4133e029776b8d16ce9716b37e7cf15baf774152`.
- Nieuwe website in voorbereiding: <https://syntheticdiz.github.io/CommissieWijzer/> — nog niet live.
- [App Store-metadata](AppStore/Metadata.nl-NL.json)
- [Listingtekst](AppStore/Listing.md)
- [Review notes](AppStore/ReviewNotes.md)
- [Privacybeleid](AppStore/Privacy.md)
