# CommissieWijzer — ontwikkel- en releasestatus

Bijgewerkt op 30 oktober 2026. Dit bestand beschrijft de huidige fork en releasevoorbereiding.

## Product

CommissieWijzer is een zelfstandige macOS-app voor het lezen en voorbereiden van raadsstukken en commissiestukken. De app behoudt de bestaande leesinterface en analysewerking. De fork heeft een eigen productnaam, symbool, bundle-ID, voorkeuren en opslag. Gebruikersbestanden gebruiken de compatibele extensie `.spdfwork`.

De app koppelt analysepunten aan bronpassages in de pdf, ondersteunt lokale zoekopdrachten, notities en geselecteerde passages, optionele vergelijking met een eigen partijprogramma en pdf-samenvattingsexport. De belangrijkste commissie-indelingen zijn SOD, LO en BES.

Minimale versie: macOS 14. Apple Intelligence vereist macOS 26 of later en geschikte, door Apple ondersteunde hardware. ChatGPT is optioneel, verloopt via OpenAI OAuth en gebruikt het ChatGPT-account van de gebruiker; deze fork heeft geen API-sleutelprovider.

## Privacyfeiten

- Pdf’s, werkdocumenten, analysecache, voorkeuren, notities en diagnostische bestanden worden lokaal opgeslagen.
- Apple Intelligence-verwerking vindt lokaal plaats op geschikte systemen.
- Bij ChatGPT worden de benodigde documentfragmenten en het gekozen programma voor analyse rechtstreeks met OpenAI gedeeld. De OpenAI-aanmelding geeft de app een e-mailadres en stabiele `sub`-accountidentifier; een gegenereerde, vaste hostidentifier wordt gebruikt in de OAuth-aanvraag. Tokens en accountrecord worden in de macOS-sleutelhanger bewaard. De app leest geen ChatGPT-gesprekken.
- De optionele woordenlijst vraagt Wikipedia op basis van een term. Voor AI-uitleg kan de geselecteerde provider documentcontext en de gevonden brontekst ontvangen.
- De app heeft geen eigen server, account, telemetrie of tracking. Lokale ChatGPT-diagnostiek bevat geen prompt, documentinhoud of response body.

## Versie en verificatie

- Versie: 1.0.1
- Build: 1
- Offline Swift-tests: 58 geslaagd, geen fouten (lokale run van 30 oktober 2026).
- De testuitslag is geen release-audit. De uiteindelijke App Store-build, distributieondertekening en installatiepakket zijn nog niet gevalideerd.

## Openstaande releasewerkzaamheden

- Controleer de definitieve app-identiteit, opslagpaden, branding en versie/build in de release-bundel.
- Werk de actuele App Store Connect-privacyvragen in op basis van de definitieve release-build en Apple’s dan geldende formulier.
- Controleer de Nederlandse productmetadata, privacy- en ondersteuningspagina’s en daadwerkelijke URL-beschikbaarheid.
- Maak en controleer echte App Store-screenshots uit de definitieve app; er zijn hier geen screenshots als releasebewijs opgenomen.
- Maak en valideer de App Store-distributiebundel met de juiste Apple-ondertekening en provisioning.
- Upload pas na de release-audit; bouw is nog niet ingediend en er is geen Apple-review of publieke release geweest.

## Referenties

- Productmetadata: [AppStore/Metadata.nl-NL.json](AppStore/Metadata.nl-NL.json)
- Listingtekst: [AppStore/Listing.md](AppStore/Listing.md)
- Review notes: [AppStore/ReviewNotes.md](AppStore/ReviewNotes.md)
- Privacybeleid en questionnaire-feiten: [AppStore/Privacy.md](AppStore/Privacy.md)
- Publieke website: <https://commissiewijzer.adeptbeech13.chatgpt.site>
- Broncode: <https://github.com/SyntheticDiz/CommissieWijzer>

## Verificatie definitieve preview

De sandboxed previewbuild 2.0.1/build2 is geslaagd, inclusief strict codesign en controle op eigen identiteit, sandbox, privacy en compleet AppIcon/ICNS. Log: commissiewijzer-preview-final.log (lokaal). De oorspronkelijke appkleuren zijn behouden; alleen woordmerk/naam en icoon verschillen. Storeprofiel en Apple-indiening volgen.

## Build 2, bijgewerkte identiteit en welkom

CW-icoon is een strak typografisch monogram op donkerblauw, gegenereerd met native vectorcontouren (scripts/generate-icon.swift); eerste beeldconcepten verworpen. Alleen CommissieWijzer-icon gewijzigd. Beide apps hebben dezelfde compacte, horizontaal gecentreerde bestaande keuzelijst. CW1.0.1/build2 en SPDF5.32.4/build82: normale herstart en native visuele controle van welkom/menu geslaagd. SPDF-assets blijven hashgelijk. Geen documenten of AI tijdens deze UI-controle.

Ondertekend universeel Mac App Store-pakket en profielvalidatie geslaagd (commissiewijzer-build2-store.log): dist/CommissieWijzer-1.0.1.pkg. Eigen profiel in Downloads; lokale referenties in genegeerd Submission.local.json, geen sleutels geëxporteerd. Website publiek gepubliceerd met laatste CW-icoon: versie2, source0fdb7999ab8f19e7976e2e72cb4b0f779d4f1228. GitHub-toegang voor de nieuwe repo is na expliciete gebruikersbevestiging toegevoegd. Bronpublicatie volgt via de koppeling. Niet claimen dat code al online staat. Apple App-ID/profiel aangemaakt; App Store Connect-record/upload/review en definitieve screenshots nog te doen. Fictieve AppStore/Sample.pdf één pagina A4, selecteerbare tekst, gerenderd en visueel gecontroleerd; geen echt raadsstuk.
