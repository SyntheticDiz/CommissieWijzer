# CommissieWijzer — ontwikkel- en releasestatus

Bijgewerkt op 30 oktober 2026. Dit bestand beschrijft de definitieve status van de Mac App Store-inzending.

## Product

CommissieWijzer is een zelfstandige macOS-app voor het lezen en voorbereiden van raads- en commissiestukken. De app behoudt de bestaande lees- en analysewerking, met een eigen naam, icoon, bundle-ID, voorkeuren en opslag. Werkdocumenten gebruiken de compatibele extensie `.spdfwork`.

De app biedt bronpassages, lokale zoekopdrachten, notities, geselecteerde passages, optionele vergelijking met een door de gebruiker gekozen programma en pdf-export. Apple Intelligence is lokaal beschikbaar op geschikte systemen met macOS 26 of later. ChatGPT is optioneel, online en verloopt via OpenAI OAuth. De app heeft geen API-sleutelprovider of eigen backend.

## Definitieve App Store-status

- App: **6829018818**, versie **1.0.1**, build **2**.
- Inzending `dba69734-ed1f-43e4-9eec-2520c6a988e0` is op 30 oktober 2026 om 21:41 (Europe/Amsterdam) ingediend. App Store Connect toont **Waiting for Review** en **1 Item Submitted**. De inzending staat in de wachtrij; er is nog geen goedkeurings- of afwijzingsbesluit.
- Het universele pakket is ondertekend, strict geverifieerd en door de release-audit gekomen. De 58 Swift-tests slaagden zonder fouten. De normale previewherbouw en storebuild zijn strict geverifieerd en door de audit gekomen.
- De privacyvragenlijst met vier gegevenscategorieën is na expliciete gebruikersgoedkeuring gepubliceerd. De encryptievraag is als uitsluitend gebruik van Apple’s besturingssysteembeveiliging beantwoord.
- Drie screenshots van 2560 × 1600 zijn door App Store Connect geaccepteerd. De fictieve, doorzoekbare voorbeeld-pdf is bij de inzending gevoegd.
- Leeftijdsclassificatie: **4+**. Prijs: **gratis**. Beschikbaarheid: **175 storefronts**. De release is openbaar ingesteld met **handmatige vrijgave**; automatische vrijgave staat uit.

## Productie en controle

Een lokale Apple Intelligence-analyse van het fictieve voorbeeld werkte. In die analyse beschreef het overzicht een voorgesteld besluit alsof het al was genomen. Controleer gegenereerde samenvattingen daarom aan de hand van de geciteerde bronpassage en de volledige pdf. De bestaande appfunctionaliteit is behouden.

De GitHub Pages-site is live op <https://syntheticdiz.github.io/CommissieWijzer/>. De acht gepubliceerde resources zijn gecontroleerd op HTTP 200 en komen byte voor byte overeen met de gepubliceerde bestanden.

De website werd gepubliceerd met commit `3a99ffc4a337d4a4a002763ae38cccedc59bb068`. De lokale `main`-branch volgt `origin/main`. De eerder geïmporteerde geschiedenis is lokaal bewaard onder `local-import-history`.

## Privacyfeiten

- Pdf’s, werkdocumenten, analysecache, voorkeuren, notities en technische diagnostiek worden lokaal opgeslagen.
- Apple Intelligence-verwerking vindt lokaal plaats op geschikte systemen.
- Wanneer de gebruiker ChatGPT kiest, worden de voor de taak benodigde documentfragmenten en zo nodig het gekozen programma rechtstreeks met OpenAI gedeeld. OAuth levert een e-mailadres en stabiele accountidentifier op; een vaste, willekeurige hostidentifier wordt voor de OAuth-aanvraag gebruikt. Tokens en accountgegevens staan in de macOS-sleutelhanger. De app leest geen ChatGPT-gesprekken.
- De optionele woordenlijst kan Wikipedia raadplegen. Voor AI-uitleg kan de geselecteerde provider de term, beperkte documentcontext en gevonden brontekst ontvangen.
- De app heeft geen account, telemetrie of tracking. ChatGPT-diagnostiek bevat geen documenttekst, prompts, antwoordtekst of volledige serverresponses.

## Documentatie

- [README](README.md)
- [App Store-metadata](AppStore/Metadata.nl-NL.json)
- [Listingtekst](AppStore/Listing.md)
- [Review notes](AppStore/ReviewNotes.md)
- [Privacybeleid](AppStore/Privacy.md)
