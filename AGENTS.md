# CommissieWijzer — werkinstructies

## Projectkader

- Lees vóór werk de `README.md`, `HANDOFF.md` en `AppStore/Features.md`; gebruik `AppStore/OpenAI-Integration.md` en `AppStore/CloudKit/README.md` wanneer de taak die onderwerpen raakt.
- Behandel HANDOFF-status, Apple-ontvangstbewijzen en releasehistorie als laatst vastgelegde feiten, niet als actuele status. Controleer actuele status alleen als de taak dat vereist.
- Dit project is de zelfstandige CommissieWijzer voor macOS en iPadOS. Wijzig SPDF V5 of andere apps uitsluitend op expliciet verzoek.
- Behoud bestaande productfuncties en compatibiliteit; pas functies, beloften en projectdocumentatie aan wanneer de broncode verandert.
- De volledige functies en platformbeperkingen staan in `AppStore/Features.md`; houd dit overzicht in overeenstemming met de broncode.

## Orkestratie en gedelegeerd werk

- De geselecteerde chatmodel-orchestrator is eigenaar van scope, planning, review, integratie, verificatie en releasebesluiten.
- Gebruik GPT-6 Luna (`gpt-6-luna`) voor afgebakende implementaties. De rootagent kan kleine tekst- of documentfixes zelf uitvoeren.
- Gebruik GPT-6.1 Sol (`gpt-6.1-sol`) met reasoning effort `medium` voor complexere implementaties over meerdere onderdelen, foutonderzoek en onafhankelijke code-review bij grote of risicovolle wijzigingen. Geef review aan een aparte agent die de wijziging niet zelf heeft geschreven.
- Gebruik GPT-6.1 Terra (`gpt-6.1-terra`) voor browser-, native-app- en schermafbeeldingstaken. Er is per keer maar één computeroperator; coördineer die exclusiviteit.
- De orchestrator stuurt Luna, Sol en Terra rechtstreeks aan; Sol vormt geen extra managementlaag. Bij complexe of onopgeloste problemen neemt de orchestrator de beoordeling over en bepaalt de vervolgstap.
- Geef iedere delegatie een precies doel, benodigde invoer, eigenaar-bestanden en aantoonbare acceptatiechecks. Vermeld welke bewijzen een geslaagde taak opleveren.
- Geef agenten één eigenaar-bestand of niet-overlappende bestandensets. Gebruik worktrees waar dat helpt; reset of overschrijf nooit ongevraagd onopgeslagen werk.
- Beperk gelijktijdig werk tot maximaal twee implementers plus één onafhankelijke reviewer, naast de rootagent en binnen vier beschikbare slots.
- Laat een onafhankelijke reviewer alleen bij grote of risicovolle wijzigingen meekijken; die reviewer is niet de auteur. De rootagent reviewt de samengevoegde wijziging en de gezamenlijke verificatie.
- Iedere agent rapporteert gewijzigde bestanden, uitgevoerde checks, resultaten en resterende beperkingen. De rootagent controleert dit zelf voordat werk als afgerond geldt.
- Agenten delegeren niet verder, tenzij dat expliciet is gevraagd. Als een gevraagd model niet beschikbaar is, meld de fallback en claim niet dat het gevraagde model is gebruikt.
- Forceer geen Luna voor complexe OAuth-, CloudKit- of migratiebesluiten: root kan die uitvoeren of passend sterker werk delegeren.
- Breng technische, privacy-, account-, ondertekenings- of productscope-ambiguïteit terug naar de rootagent; laat een gedelegeerde agent daar niet naar raden.
- Voeg geen nieuwe toestemmingsdrempels toe voor werk waarvoor de gebruiker al toestemming gaf. Volg wel platformgoedkeuring voor acties die daar expliciet onder vallen.

## Product- en privacygrenzen

- De Mac- en iPad-app delen Swift-bronnen waar mogelijk. Behoud het bestaande gedrag op beide platforms en controleer alle ondersteunde layouts bij UI-wijzigingen.
- Gebruik de gedeelde `AppTheme`-kleuren en knop-/kaartstijlen: cyaan voor primaire acties, neutraal voor secundaire acties en adaptieve selecties. Behoud betekenisvolle fout-, waarschuwing- en verwijderkleuren. Controleer focuscontrast ook op lichte knoppen en PDF-overlays.
- Gebruik voor instellingen de gedeelde vijf categorieën en `SettingsDesign.swift`; behoud de vaste kop/voet, compacte navigatie en bestaande account- en opslagacties. Houd gebruikersinstructies gelijk aan de actuele menupaden.
- Behoud het naar beneden uitklappen van recente werkdocumenten zonder verschuiving boven de kaart, de oorspronkelijke eerste importanimatie en ondersteuning voor Verminder beweging.
- Houd de bron-pdf en het analysewerkveld als twee gelijkwaardige kaarten met gedeeld ontwerp op brede vensters; behoud de iPad-paneelwisselaar op smalle vensters.
- Bewaar werkdocumentformaat 1 en `.spdfwork`-compatibiliteit tussen Mac en iPad. Wijzig het formaat alleen als de opdracht dit vereist en compatibiliteit zorgvuldig is afgedekt.
- Optionele vragenlijsten zijn toegevoegd aan formaat 1 als onbekend veld. Oudere appversies kunnen zulke werkdocumenten lezen, maar bewaren vanuit een oudere versie verwijdert de onbekende vragenlijstgegevens. Adviseer beide platforms bij te werken voordat een werkdocument met vragen heen en weer wordt bewaard.
- Houd `nl.commissiewijzer.app` en het bestaande gedeelde App Store-record intact. Houd Mac-versie/build in `build-app.sh` gelijk aan `PatchNotesView.swift`; houd iPad-projectversies coherent via `scripts/generate-ipad-project.py`.
- Opslag en verwerking zijn lokaal standaard. Publiceer geen geheimen, credentials, echte gebruikersdocumenten of lokale paden.
- iCloud en online ChatGPT zijn optioneel; maak cloud- of netwerkverwerking nooit stilzwijgend standaard.
- ChatGPT gebruikt OAuth met het ChatGPT-account; voeg geen API-sleutelveld toe zonder expliciete productopdracht.
- Ga niet uit van commerciële OpenAI-toestemming. Raadpleeg `AppStore/OpenAI-Integration.md` voor aanvraagstatus en vastgelegde beslissingen.
- Houd CloudKit-preview, Development en Production gescheiden met de passende profielen en omgevingen. Simulator- of ongetekende builds bewijzen geen echte synchronisatie.
- Rapporteer duidelijk wanneer fysieke apparaat-, account- of Production-verificatie niet is uitgevoerd; verzin geen bewijs.

## Builds, tests en releases

- Kies checks passend bij de wijziging: Swift-tests en Mac-build voor gedeelde/codewijzigingen; de toepasselijke iPad-projectgeneratie, build en tests voor iPad- of gedeelde wijzigingen.
- Voor UI-wijzigingen controleer je visueel de relevante Mac- en iPad-layouts, inclusief brede en smalle vensters waar van toepassing.
- Voor documentatie-only wijzigingen zijn diff- en linkcontroles doorgaans genoeg; voer geen volledige appbuild uit zonder reden.
- Gebruik de bestaande build- en release-instructies uit `README.md`. Scheid preview-, Development-, Production- en Store-output.
- Voor dagelijks lokaal gebruik werk je de bestaande installatie `dist/CommissieWijzer.app` bij, met behoud van ondertekening en Production-iCloud. Maak of open geen tweede preview-installatie zonder expliciet verzoek. Buildmappen zijn tussenproducten, geen extra gebruikersinstallaties.
- Behoud de actuele vrijgavevoorkeuren in App Store Connect; verander ze alleen op expliciet verzoek. Op 9 november 2026 is automatische vrijgave voor beide platforms waargenomen; eerdere notities over handmatige Mac-vrijgave zijn historisch.
- RELEASE alleen binnen de bestaande machtiging en concrete taak. De rootagent beheert releasebesluiten; Terra kan uitsluitend de precies omschreven, al geautoriseerde stappen uitvoeren en bewijs/resultaten controleren.
- Verzin geen Apple-goedkeuring of actuele indieningsstatus. Raadpleeg ontvangstbewijzen; de laatst genoteerde status is historisch totdat opnieuw gecontroleerd.
- Voor Store Story zijn er zes dia’s per platform, in volgorde 01–06, met exact: “Jouw stukken. Jouw inzichten. Jouw koers.” Gebruik de huidige assetdocumentatie; contactsheets zijn geen standaard uploadbestanden.
- Gebruik echte, cursorvrije appbeelden voor Store-assets; behoud de verhoudingen en toon geen verzonnen interface of persoonlijke gegevens.
- Controleer vóór push de lokale diff, ongerelateerd lokaal werk en eventuele remote-divergentie. Behoud andermans wijzigingen en publiceer of commit niet tenzij dat onderdeel is van de opdracht.

## Afronding en documentatie

- Houd README, functieoverzicht en HANDOFF bij als de wijziging blijvende product- of release-informatie verandert.
- Scheid nieuw geverifieerde feiten van historische status; verwijder geen bewijs of bronassets zonder expliciete opdracht.
- Rapporteer kort wat veranderde, welke checks daadwerkelijk zijn uitgevoerd, hun uitkomst en eventuele open beperkingen.
