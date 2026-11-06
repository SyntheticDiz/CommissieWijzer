import SwiftUI

struct PatchNotesView: View {
    @Environment(\.dismiss) private var dismiss
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.2" }

    private struct Release: Identifiable {
        let version: String
        let date: String
        let changes: [String]
        var id: String { version }
    }
    // Newest release first; retain the previous release notes.
    private let releases: [Release] = [
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
            "CommissieWijzer is een zelfstandige kopie met een eigen naam en icoon, met dezelfde vormgeving en werking als de oorspronkelijke app.",
            "Programmavergelijking blijft optioneel en gebruikt alleen het programma dat je zelf kiest."
        ]),
        .init(version: "5.32.3", date: "30 oktober 2026", changes: [
            "Lange teksten in de uitgebreide samenvatting, chat, selectiesamenvattingen, vergelijkingen en toelichtingen krijgen leesalinea’s en rustigere regelafstand.",
            "Bredere broncontext, broncitaten en geselecteerde teksten gebruiken dezelfde leesbare bronopmaak, met behoud van de volledige tekst en oorspronkelijke bronverwijzingen.",
            "De afkortingenlijst vermeldt correct dat online aanvullen de gekozen AI-provider gebruikt. De bestaande analysewerking is niet gewijzigd."
        ]),
        .init(version: "5.32.2", date: "30 oktober 2026", changes: [
            "Volledige broncitaten, aanvullende bronnen en programmacitaten staan bij Lees passage. Kaartdetails blijven compact; alle toelichting, controle, notities en vraagacties blijven beschikbaar.",
            "De losse Bron-knop is verwijderd uit puntkaarten. Klikken op de titel of samenvatting opent de bijbehorende passage in de PDF.",
            "De leesweergave bewaart alle bronrollen en verwijzingen, zonder standaard blauwe citaatmarkering. Identieke bronnen op dezelfde pagina worden één keer getoond. De AI-analyse blijft ongewijzigd."
        ]),
        .init(version: "5.32.1", date: "30 oktober 2026", changes: [
            "Broncitaten en geselecteerde passages in kaartdetails krijgen rustigere bronblokken met leesalinea’s en herstelde PDF-regelafbrekingen. De volledige oorspronkelijke tekst blijft behouden.",
            "Een onderbouwend citaat dat eenduidig en letterlijk in de geselecteerde passage voorkomt, wordt daarin gemarkeerd in plaats van dubbel getoond. Bij verschillen of twijfel blijven beide teksten afzonderlijk zichtbaar.",
            "Bronverwijzingen, volledige passages en context blijven bereikbaar. De AI-analyse en opgeslagen informatie veranderen niet."
        ]),
        .init(version: "5.32.0", date: "30 oktober 2026", changes: [
            "Raad- en commissiekaarten hebben één compacte actierij met Bron, Lees passage en Details. De volledige samenvatting en details klappen onafhankelijk en vloeiend uit, met ondersteuning voor Verminder beweging.",
            "Toelichting, brononderbouwing, controle, notities en vragen blijven binnen Details beschikbaar. Ook commissiekaarten met alleen een bronpassage gebruiken deze rustige indeling.",
            "Commissiepunten tonen zes regels vóór de fade in plaats van vier. De vrijgekomen detailruimte houdt de kaart compact; Compact lezen en de andere kaarttypen behouden hun korte weergave.",
            "Zelf gekozen passages tonen hun tekst niet meer dubbel. Lees passage opent steeds de leesweergave; wijzigen, verplaatsen en verwijderen staan samen onder Meer.",
            "Tabelkaarten groeperen tabelgegevens, leespunten en correcties. Bronstatus, onzekere cellen, waarschuwingen en lopende verwerking blijven zichtbaar. De AI-analyse, broninformatie en opslag blijven behouden."
        ]),
        .init(version: "5.31.2", date: "30 oktober 2026", changes: [
            "Lange teksten in Kerngegevens uit bron worden voor de leesweergave verdeeld in kortere alinea’s op zinsgrenzen. Bestaande alinea’s, lijsten, tabellen en de volledige oorspronkelijke bron blijven behouden.",
            "De fade, uitklapbediening, bronverwijzingen en leesacties blijven beschikbaar. Hiervoor is geen nieuwe AI-analyse nodig.",
            "Commissiekaarten tonen de hoofdtekst rustiger. Toelichting, brononderbouwing, eigen controle en notities en vraagacties zijn afzonderlijk opvraagbaar, met behoud van alle informatie en functies."
        ]),
        .init(version: "5.31.1", date: "30 oktober 2026", changes: [
            "Kerngegevens krijgen een duidelijke titel, rustigere tekst en een compacte actierij. Overbodige opsommingstekens verdwijnen; lange tekst behoudt de fade en uitklapbediening.",
            "Duidelijke PDF-regelafbrekingen worden alleen voor het lezen samengevoegd. Alinea’s, lijsten, tabellen en de oorspronkelijke bron blijven behouden.",
            "Bron en Lees passage blijven direct beschikbaar; bredere context staat onder Meer. Aanvullende toelichting staat achter Waarom dit punt? en ontbreekt wanneer er niets toe te voegen is."
        ]),
        .init(version: "5.31.0", date: "30 oktober 2026", changes: [
            "De rondleiding sluit aan op de Focus-stijl, met duidelijke stappen, korte uitleg over handeling en resultaat, praktische tips en rechtstreeks kiezen van een onderwerp.",
            "Voorbeelden tonen het huidige gebruik van CommissieWijzer, waaronder automatisch analyseren na import, providerkeuze en teruggaan naar de bron. Gerichte animaties laten de bediening zien; opnieuw afspelen en verminderde beweging blijven beschikbaar.",
            "De rondleiding gebruikt fictieve gegevens en verandert je document of analyse niet. De laatste stap heeft een duidelijke knop om af te ronden.",
            "Lange kaartteksten lopen onderaan zacht weg in plaats van afgebroken te worden met puntjes. Klikken toont de volledige tekst; bron- en selectieacties blijven apart beschikbaar."
        ]),
        .init(version: "5.30.3", date: "30 oktober 2026", changes: [
            "Bronacties openen voortaan ook een ingeklapte PDF. Knoppen voor analyse tonen dezelfde beschikbaarheid als de bestaande verwerking; afzonderlijke acties op bronkaarten blijven gescheiden.",
            "PDF-bediening, bronlinks, sluitacties en verwijderacties volgen dezelfde Focus-stijlen. Uitgeschakelde menu’s krijgen geen actieve aanwijseffecten. Keuzetabs ondersteunen pijltoetsen.",
            "Escape sluit aanvullende vensters; Enter sluit de woordenlijst niet meer tijdens zoeken. Alle bronnen, resultaten, bestaande keuzes en analysewerking blijven behouden."
        ]),
        .init(version: "5.30.2", date: "30 oktober 2026", changes: [
            "Keuzemenu’s en tabs volgen in de hele app dezelfde rustige Focus-stijl, onder meer bij commissiepunten, zoeken, instellingen, modelkeuze en export. De actieve keuze blijft herkenbaar en aantallen staan rustiger naast de tabtitel.",
            "Paginafilters, zoekvelden en overige tekstvelden hebben een bijpassend oppervlak en rand. Compact lezen en andere selectievakjes blijven herkenbaar; bestaande keuzes, filters, broninformatie en analysewerking blijven behouden."
        ]),
        .init(version: "5.30.1", date: "30 oktober 2026", changes: [
            "Eén rustige bedieningsbalk vervangt de losse rijen boven het document. De analysemodus staat als compacte keuzeknop naast Vernieuw analyse; de leesacties staan rechts en passen zich aan de beschikbare breedte aan.",
            "Waarschuwingen staan zonder omliggende kaart onder de balk. De herkenbare waarschuwingsiconen en aanklikbare details blijven behouden, net als alle analyse-, bron- en opslagfuncties."
        ]),
        .init(version: "5.30.0", date: "30 oktober 2026", changes: [
            "Een klik op een commissiekaart opent de bijbehorende passage in het PDF-deel. De afzonderlijke bron-, lees-, selectie- en notitieacties blijven beschikbaar.",
            "Kerngegevens staan als afzonderlijke kaarten binnen het overzicht. De categoriebediening en leesopmaak zijn stabieler. Lange documentoverzichten krijgen lokaal leesbare alinea’s; de oorspronkelijke tekst en analyse blijven ongewijzigd.",
            "De keuze tussen programmavergelijking en neutrale samenvatting volgt de Focus-stijl. Uitklapbare secties zijn via hun hele kop te bedienen, ook in lees- en detailvensters.",
            "Een geopend werkdocument wordt bij het afsluiten van de app automatisch naar zijn bestand bewaard. De app wacht op het bewaren en blijft bij een fout open. Nieuwe losse PDF’s houden de bestaande keuze om te bewaren of wijzigingen te verwerpen."
        ]),
        .init(version: "5.29.0", date: "30 oktober 2026", changes: [
            "Het analyseoverzicht staat achter de bestaande overzichtsknop. Een compacte status houdt bronproblemen en een onvolledige commissiebeoordeling zichtbaar; details, bronpagina’s en herstelacties blijven bereikbaar.",
            "Uitklapbare categorieën hebben één volledig klikbare kop, inclusief titel, aantal en pijltje. Dezelfde bediening geldt voor de raad en commissies, met behoud van de punten en volledige bronnen.",
            "Nieuwe commissiebeoordelingen delen passages meteen in op onderwerp. Bij een bewuste commissiewissel of hervatte beoordeling worden ontbrekende onderwerpgegevens uit oudere beoordelingen automatisch aangevuld. Opgeslagen werkdocumenten openen zonder een nieuwe AI-opdracht; bestaande beoordelingen en onderwerpkeuzes blijven behouden."
        ]),
        .init(version: "5.28.1", date: "30 oktober 2026", changes: [
            "Knoppen volgen in het hoofdscherm, de leesweergave, instellingen, zoeken, export en overige appvensters dezelfde rustige Focus-stijl. Primaire acties, secundaire acties en pictogramacties blijven duidelijk van elkaar te onderscheiden.",
            "De bovenste werkbalk heeft neutrale pictogrammen en menu’s, met subtiele reactie bij aanwijzen, indrukken en toetsenbordfocus. Werkdocument en het meer-menu krijgen niet meer onnodig de accentkleur.",
            "Herstelacties en onderwerpindeling sluiten aan op de overige bediening. Bestaande functies, sneltoetsen, uitgeschakelde toestanden, volledige brontekst en de twee leesdelen blijven behouden. Apple Intelligence en ChatGPT analyseren op dezelfde manier."
        ]),
        .init(version: "5.28.0", date: "29 oktober 2026", changes: [
            "Het Focus-ontwerp geeft punten duidelijkere titels, prettig leesbare samenvattingen en ruimere kaarten. Rustige broninformatie, subtiele schaduwen en consistente bediening ondersteunen het lezen naast de oorspronkelijke PDF. Ook de bovenste werkbalk sluit aan op het Focus-ontwerp, met behoud van alle acties.",
            "De kaart waarvan de bron in beeld is krijgt een accentkleurige omlijning. Bronknoppen, volledige passages, bredere context, Details, deelpunten, sterren, notities en eigen broncontrole blijven beschikbaar.",
            "Zoeknavigatie gebruikt ook voor nog niet opgebouwde commissiekaarten dezelfde bronalinea-identiteit. Hiermee wordt de route naar punten verderop in een lange lijst hersteld; broninhoud en zoekresultaten blijven gelijk.",
            "De twee naast elkaar staande leesdelen, alle punten, zoeken, selectie, export en waarschuwingen blijven behouden. Lichte en donkere weergave en toegankelijkheidsvoorkeuren blijven ondersteund. De AI-analyse en opgeslagen broninhoud zijn niet gewijzigd."
        ]),
        .init(version: "5.27.1", date: "29 oktober 2026", changes: [
            "Werkdocument openen en bewaren hebben vaste opdrachten in het bestandsmenu. ⌘⇧O en ⌘S werken voor het actieve venster, ook voordat het werkbalkmenu is geopend. De bestaande controles tijdens verwerking en modale vensters blijven gelden.",
            "Een geannuleerde exportvoorbereiding kan geen ouder resultaat meer terugzetten na een snelle wisseling van exportkeuzes. Bronvalidatie voor commissie-export wordt bij sluiten en vernieuwen geannuleerd en controleert de actuele documentrevisie.",
            "De volledige bron-PDF, analyse, commissiebeoordelingen, selectie, notities en exportinhoud blijven behouden. De werking van ChatGPT en Apple Intelligence is ongewijzigd."
        ]),
        .init(version: "5.27.0", date: "29 oktober 2026", changes: [
            "De exportwizard bereidt punten, selecties, vragen en brongegevens één keer op de achtergrond voor en hergebruikt die bij stapwisselingen. Gewijzigde keuzes krijgen een actuele momentopname; verouderde voorbereiding wordt geannuleerd. Exportbereiken, volgorde en volledige bronnen blijven behouden.",
            "Commissieoverzichten hergebruiken de koppeling tussen volledige bronpassages en punten zolang de resultaten niet veranderen. Pagina- en controlefilters blijven direct werken; alle passages, deelpunten en bestaande bronacties blijven bereikbaar.",
            "Een tekstindelingscorrectie hergebruikt ongewijzigde pagina’s wanneer de actuele uitleesgegevens beschikbaar zijn. Vervolgtabellen worden opnieuw samengevoegd met dezelfde regels. Een ouder werkdocument zonder deze tijdelijke gegevens gebruikt eerst de volledige uitlezing. Analyse op gewijzigde tekst moet zoals voorheen opnieuw worden uitgevoerd.",
            "Commissiebeoordeling, herstel en onderwerpindeling krijgen afzonderlijke lokale tijdmetingen. Dit verandert geen AI-opdrachten, modelkeuzes, broncontroles of gelijktijdigheid.",
            "Notities bewaren alleen de nieuwste nog niet begonnen schrijftoestand per bestand. Lopende schrijfacties worden afgemaakt; atomair bewaren, foutmeldingen en wachten op opslag bij afsluiten blijven behouden.",
            "Zoeken in de volledige leesweergave hergebruikt een achtergrondindex van de oorspronkelijke tekst. Oude zoektaken worden geannuleerd en tijdelijke gegevens worden bij sluiten vrijgegeven. De volledige tekst, Unicode-markeringen en vervolgpagina’s blijven behouden.",
            "Zoekresultaten beginnen met drie treffers per soort. Kies desgewenst één resultaatsoort en toon per groep meer; Alle resultaten en alle bestaande bronverwijzingen blijven beschikbaar. Exact zoeken, typefoutsuggesties en optionele woordvormen behouden hun werking.",
            "Documentoverzicht en Commissiepunten maken het bereik duidelijker. Werkdocumenten houden een herkenbaar mapicoon met een aparte wijzigingsmarkering. Bronknoppen hebben een rustige, consistente stijl; Vernieuw analyse krijgt minder nadruk. Starten, hervatten en stoppen blijven op dezelfde plaats beschikbaar.",
            "Documentpunten en documentkernpunten worden duidelijker benoemd. De leesweergave gebruikt het juiste enkelvoud bij één treffer. De indeling van de bovenste bedieningsruimte is niet verplaatst; OCR-regels, zoekrevisie, lijstvirtualisatie en cacheopruiming zijn niet aangepast."
        ]),
        .init(version: "5.26.0", date: "29 oktober 2026", changes: [
            "Belangrijkste toont bij commissies alleen belangrijk bevonden bronpassages. Twijfelgevallen en nog niet beoordeelde passages blijven bereikbaar onder Nog controleren. Alle punten blijft alle passages en bestaande analysepunten tonen.",
            "Nog in te delen heeft binnen Alle punten vier herkenbare onderverdelingen: Relevant/belangrijk — onderwerp ontbreekt, Twijfel, Nog niet beoordeeld en Overige passages. Deze weergave gebruikt alleen de bestaande beoordeling en verzint geen onderwerp of foutoorzaak.",
            "Onderwerpen met de meeste belangrijke passages staan bij het openen vooraan. De volgorde blijft tijdens het lezen stabiel; opgeslagen open of gesloten categorieën blijven gerespecteerd. Aantallen en zoekverwijzingen blijven verbonden aan de volledige bronalinea.",
            "Eén compacte statusstrook bundelt voorbereiding, analyse, commissiebeoordeling en broncontroles. Uitleg en herstelacties staan onder Details; lopende beoordeling, stoppen en waarschuwingen voor niet-meegenomen PDF-pagina’s blijven direct zichtbaar.",
            "Volledige bronpassages, vervolgpagina’s, broncontext, extra punten uit dezelfde alinea, selectie, notities, eigen broncontrole en export blijven behouden. De AI-analyse, modelkeuzes en onderwerpindeling van Apple Intelligence en ChatGPT zijn niet gewijzigd."
        ]),
        .init(version: "5.25.0", date: "29 oktober 2026", changes: [
            "Zoeken kan bij een typefout een spelling voorstellen die in het document voorkomt. Alleen een klik op de suggestie verandert de zoekopdracht. Getallen, bedragen en gemengde letter-/cijferopdrachten worden niet automatisch gecorrigeerd.",
            "Met Ook andere woordvormen vind je aanvullende Nederlandse woordvormen. Deze optie staat standaard uit. Exacte resultaten blijven vooraan; extra treffers staan apart omdat de betekenis kan verschillen.",
            "Alle resultaten blijven verbonden aan hun oorspronkelijke punt, tabel, pagina, notitie of zelfgekozen passage. De volledige broninhoud, bestaande exacte zoekfunctie en bronacties blijven behouden.",
            "De lokale zoekhulp gebruikt RapidFuzz en Snowball zonder AI-aanvragen of Python. De aanvullende index wordt op de achtergrond opgebouwd en binnen de zoekweergave hergebruikt. De analyse met Apple Intelligence en ChatGPT blijft ongewijzigd.",
            "Instellingen bevat de meegeleverde opensourcelicenties. pdfplumber blijft uitsluitend buiten de app in onderzoek; Swift Collections is niet toegevoegd."
        ]),
        .init(version: "5.24.1", date: "28 oktober 2026", changes: [
            "Onvolledige commissiebeoordelingen tonen onder Waarom ontbreken beoordelingen welke verwerking of broncontrole niet lukte. Geen oordeel, ontbrekende uitleg, ontbrekend citaat en een niet teruggevonden citaat krijgen afzonderlijke meldingen. Oudere algemene foutmeldingen worden niet achteraf als een precieze oorzaak voorgesteld.",
            "Hervatten met dezelfde modelkeuze bewaart alle geldige eerdere beoordelingen en behandelt alleen de nog onbeoordeelde passages, ook als de tijdelijke cache ontbreekt. Stoppen en opnieuw openen behouden de gemaakte resultaten. Een andere modelkeuze wordt duidelijk als nieuwe beoordeling benoemd.",
            "ChatGPT krijgt bij veilig herkenbare tabelregels afzonderlijke letterlijke broncontext met bijvoorbeeld jaren, eenheden en voetnoten. Een passende unieke kop kan korte tekst verduidelijken. Bij twijfel wordt geen context gekoppeld; het citaat moet uit de oorspronkelijke beoordeelde passage komen.",
            "De gebruikte broncontext blijft apart onder Details bereikbaar en wordt met het werkdocument bewaard. De volledige brontekst, bestaande beoordelingen, selectie, notities en bronnen blijven behouden.",
            "Apple Intelligence behoudt de bestaande analyseopdrachten en lokale verwerking. De extra tabelcontext geldt uitsluitend voor ChatGPT. De broncontrole blijft streng; de correctie garandeert niet dat ieder AI-antwoord inhoudelijk juist is."
        ]),
        .init(version: "5.24.0", date: "28 oktober 2026", changes: [
            "Commissiepunten staan onder onderwerpen die bij de gekozen commissie passen. Belangrijkste en Alle punten, paginafilters en eigen broncontrole blijven beschikbaar. Iedere volledige bronalinea staat eenmaal in een hoofdcategorie; twijfel over de indeling blijft onder Nog in te delen.",
            "Titel en samenvatting staan centraal op de kaarten. De commissiereden en het losse broncitaat staan onder Details; alle deelpunten, volledige passages, sterren, notities en bronacties blijven behouden.",
            "Nieuwe commissiebeoordelingen geven ook een onderwerpindeling. Bestaande beoordelingen kun je afzonderlijk indelen zonder punten of belang opnieuw te beoordelen. Bestaande geldige categorieën worden hergebruikt. Open categorieën en tabellen worden in het werkdocument onthouden.",
            "Het gekozen vergaderdoel en het onderscheid tussen afgeronde analyse en broncontroles zijn zichtbaar. Meldingen linken naar de betreffende PDF-pagina of tabel. De documentleeswijzer staat vóór de compacte toegang tot letterlijke bronpassages.",
            "Starten, hervatten en vernieuwen zijn duidelijker benoemd. Bronacties gebruiken vaste namen. Bij export kies je expliciet het hele document, een commissie of Mijn selectie; onzekerheden, volledige bronnen en algemene onderdelen blijven herkenbaar.",
            "Tabeluitleg bewaart expliciete schalen zoals × € 1.000; onduidelijke of conflicterende eenheden leiden niet tot stellige euroverschillen. Tabeltitels tonen herkenbare onderwerpen en zoeken opent de juiste tabelkaart.",
            "Recente werkdocumenten tonen ontbrekende of ontoegankelijke bestanden. Je kunt een nieuwe locatie kiezen of alleen de verwijzing uit de lijst verwijderen. De bestaande laadweergave bij het openen van werkdocumenten is niet gewijzigd.",
            "De oorspronkelijke analyseopdrachten voor Apple Intelligence en ChatGPT, de volledige bron-PDF, selectie, bewaren en bestaande exports blijven beschikbaar. De categorie-indeling is een aanvullend onderwerpsoordeel en vervangt geen broncontrole."
        ]),
        .init(version: "5.23.0", date: "28 oktober 2026", changes: [
            "Bij import begint na het lezen van de PDF eerst de voorbereiding voor de gekozen commissie. Daarna volgen punten, samenvatting en kernselectie. Raad behoudt de bestaande volgorde. Stoppen en AI-gebruiksgrenzen blijven gecontroleerd afgehandeld.",
            "ChatGPT bewaart je modelkeuzes en redeneerniveaus, ook als een model tijdelijk niet in de modellenlijst staat. Zonder eerdere keuze is de standaard GPT-6.1 Sol High als orchestrator met GPT-6 Luna High als subagent. Bestaande eigen keuzes blijven behouden.",
            "Het importscherm toont maximaal vijf recent geopende of bewaarde werkdocumenten. Openen herstelt de bewaarde resultaten zonder nieuwe AI-analyse.",
            "Nieuwe werkdocumenten bewaren ook de in deze versie geopende gesprekken met broncitaten, nieuwe selectiesamenvattingen met hun volledige geselecteerde tekst en nieuw gemaakte diagramuitleg met de afbeelding. Je vindt die terug via Bewaarde antwoorden. De volledige PDF, analyse, commissiebeoordelingen, selectie, notities en leespositie blijven behouden.",
            "Een OCR-melding wordt niet meer ten onrechte als handmatig geselecteerd tekstgebied getoond. Afbeeldingstabellen blijven herkenbaar apart gemeld. De leesvolgordecontrole zelf is niet versoepeld."
        ]),
        .init(version: "5.22.2", date: "28 oktober 2026", changes: [
            "De commissieopdracht noemt alle aangeleverde onderwerpen nu expliciet, waaronder vergunningen en handhaving, dierenwelzijn, kerngerichte aanpak, educatie en Thuis in Nissewaard.",
            "Nieuwe beoordelingen gebruiken de volledige onderwerpenlijst. Eerder opgeslagen beoordelingen blijven leesbaar met hun eigen modelherkomst; de oorspronkelijke analyse en broninhoud blijven behouden."
        ]),
        .init(version: "5.22.1", date: "28 oktober 2026", changes: [
            "Een zoekresultaat opent ook in een lange commissielijst de juiste puntkaart. De weergave brengt eerst de volledige bronalinea in beeld en springt daarna naar het gekozen deelpunt.",
            "De commissiekeuze en lopende beoordeling blijven behouden bij zoeken. De aanvullende beoordeling, volledige bronnen, selectie en overige functies zijn ongewijzigd."
        ]),
        .init(version: "5.22.0", date: "28 oktober 2026", changes: [
            "Kies bij import Raad, Bestuur, Leefomgeving of Sociaal Domein. De bestaande documentanalyse start automatisch. Voor een commissie volgt daarna een aparte beoordeling van relevantie en belang, zonder de PDF opnieuw in te lezen.",
            "Iedere commissie heeft Belangrijkste en Alle punten. De beoordeling gebruikt volledige bronalinea’s, ook als daar eerder geen analysepunt uit kwam. Alle oorspronkelijke punten en volledige bronnen blijven bereikbaar. Samenhangende deelpunten blijven bij hun bronalinea.",
            "De AI toont een reden en een letterlijk gecontroleerd broncitaat. Dit verifieert de herkomst van het citaat, niet de inhoudelijke juistheid van het oordeel. Twijfel en niet beoordeelde passages blijven herkenbaar; lange alinea’s worden niet afgekapt of ten onrechte als onbelangrijk weggelaten.",
            "Beoordelingen worden per commissie, model en bron bewaard en kunnen worden gestopt of hervat. Een ander doel vraagt alleen de aanvullende beoordeling. Werkdocumenten bewaren de resultaten en weergave; oudere documenten blijven leesbaar.",
            "De bestaande raadweergave, documentanalyse met Apple Intelligence en ChatGPT, bronnen, sterren, notities, eigen passages, zoeken en export blijven beschikbaar. De commissiebeoordeling is een afzonderlijke optionele AI-stap."
        ]),
        .init(version: "5.21.1", date: "28 oktober 2026", changes: [
            "De voortgang van de ChatGPT-kernselectie noemt nu het uitvoerende subagentmodel. Bij verschillende modellen voor orchestrator en subagents werd hier ten onrechte de orchestrator getoond.",
            "Dit herstelt alleen de modelvermelding. De feitelijke routering, AI-opdrachten, resultaten, broncontrole en werking van Apple Intelligence blijven gelijk."
        ]),
        .init(version: "5.21.0", date: "28 oktober 2026", changes: [
            "Na tijdelijke ChatGPT-druk kan de gelijktijdigheid voorzichtig herstellen richting de oorspronkelijke grens van maximaal 32. Alleen een stabiele periode met geslaagde nieuwe aanvragen telt mee; cachetreffers zijn daarvoor geen bewijs. Nieuwe druk verlaagt het tempo opnieuw en echte gebruiksgrenzen blijven stoppen.",
            "Tijdens ChatGPT-analyse kun je gecontroleerd van model wisselen. De lopende verwerking wordt eerst gestopt; de huidige fase begint opnieuw met de nieuwe keuze. Eerder afgeronde fasen en de volledige bron-PDF blijven behouden. De gebruikte modellen worden per onderdeel bijgehouden.",
            "Bij een eenduidig herkenbare tabelvoetnoot worden de letterlijke subtotaalrij, voetnoot en oorspronkelijke tabelkop samen als aparte context aangeboden. De bronalinea wordt niet vervangen en onzekere koppelingen worden niet ingevuld.",
            "Apple Intelligence behoudt de bestaande analysewerking. Broncontrole, handmatige selecties, bewaren en exporteren blijven beschikbaar."
        ]),
        .init(version: "5.20.1", date: "28 oktober 2026", changes: [
            "Aanvullend herstel voor Bewaar en ga door bij afsluiten: de afsluitactie wordt via de macOS-gebeurtenislus hervat, zodat wachten op achtergrondopslag de beëindiging niet blokkeert.",
            "De bestaande controles op niet-bewaarde wijzigingen, achtergrondopslag en opslagfouten blijven behouden. Analyse, tabelcontext en Apple Intelligence veranderen niet."
        ]),
        .init(version: "5.20.0", date: "28 oktober 2026", changes: [
            "Neutrale ChatGPT-alineapunten en kernselectie krijgen bij herkenbare tabellen de oorspronkelijke jaren, eenheid, tekenbetekenis en voetnoten als aparte broncontext. De volledige bronalinea en eigen bronverwijzingen blijven behouden.",
            "Bij een duidelijk herkenbare tabel die op de volgende pagina doorgaat, kan de oorspronkelijke tabelkop worden meegenomen. Onzekere aansluitingen, ontbrekende cellen en eenheden worden niet ingevuld en bedragen worden niet automatisch omgerekend.",
            "De kernselectie kan nu ook bedragenrijen beoordelen waarvan de euro-eenheid uitsluitend in de bijbehorende tabelkop staat. Eerdere beoordelingen zonder deze tabelcontext worden voor die rijen vernieuwd.",
            "Het puntenoverzicht gebruikt bekende hoofdstukken direct voor de indeling en vermijdt herhaald zoeken en rangschikken. Tijdens neutrale ChatGPT-analyse worden de afgeleide puntgroepen op de achtergrond voorbereid. De selectie, volgorde, sterren, bronnen en overige acties blijven behouden.",
            "Bewaren en daarna afsluiten wacht niet meer op een afsluitactie binnen dezelfde lopende taak. De bestaande controles op niet-bewaard werk en opslagfouten blijven gelden.",
            "De verbeterde ChatGPT-limietafhandeling uit 5.19.2 blijft actief. Apple Intelligence behoudt de bestaande analyseopdrachten, cache en lokale verwerking."
        ]),
        .init(version: "5.19.2", date: "26 oktober 2026", changes: [
            "ChatGPT herkent ook duidelijke tijdelijke limietmeldingen in het tekstveld detail, mits een geldige wachttijd is opgegeven. Gebruiksgrenzen, quota en niet-herkende foutcodes blijven stoppen.",
            "Gelijktijdige afwijzingen uit dezelfde reeks verlagen de gelijktijdigheid eenmaal. De lopende reeks wordt afgewacht, waarna de gezamenlijke wachttijd en begrensde herstelpogingen volgen. Zo leidt één druktegolf niet meteen tot één enkele aanvraag tegelijk.",
            "De standaard blijft maximaal 32 aanvragen voor alle ChatGPT-modellen. Alle bronnen, resultaten en de werking van Apple Intelligence blijven behouden."
        ]),
        .init(version: "5.19.1", date: "26 oktober 2026", changes: [
            "Herstellen van ChatGPT-alineapunten ververst de weergave begrensd, met behoud van het eerste en laatste resultaat en alle gemaakte punten. De rangschikking berekent prioriteiten minder vaak; selectie en volgorde blijven gelijk.",
            "Een niet-herkende ChatGPT-limiet krijgt een eigen melding met de eventuele wachttijd. Beperkte technische foutcodes helpen de echte oorzaak vast te stellen, zonder documenttekst, foutberichten of aanmeldgegevens te bewaren.",
            "Apple Intelligence behoudt de bestaande analyseopdrachten en verwerking. Tijdelijke ChatGPT-druk en echte gebruiksgrenzen blijven afzonderlijk behandeld."
        ]),
        .init(version: "5.19.0", date: "26 oktober 2026", changes: [
            "De neutrale ChatGPT-analyse mag per alineapunt meer uitleg geven wanneer dat nodig is om bedragen, termijnen, voorwaarden en uitzonderingen te behouden: maximaal zes korte zinnen en 120 woorden per punt.",
            "Een volledige alinea blijft de basis. De bronverwijzingen en volledige passage blijven beschikbaar; verschillende alinea’s worden niet automatisch inhoudelijk samengevoegd.",
            "Eerdere korte ChatGPT-punten worden bij opnieuw analyseren niet uit de oude cache overgenomen. Bestaande werkdocumenten worden niet automatisch herschreven; kies Analyseer voor nieuwe punten.",
            "Apple Intelligence, de programmavergelijking, documentsamenvatting, kernselectie, handmatige passages en export behouden hun bestaande werking. De limietoplossing van 5.18.1 blijft actief.",
            "De voorafgaande proef vond bij Astra medium beter behoud van geselecteerde feiten, maar geen foutloosheidsgarantie. Ook een ruimere samenvatting kan belangrijke informatie weglaten."
        ]),
        .init(version: "5.18.1", date: "26 oktober 2026", changes: [
            "ChatGPT maakt onderscheid tussen tijdelijke druk, een gebruiksgrens voor de koppeling en een onbekende limietmelding. Een gebruiksgrens wordt niet zinloos opnieuw geprobeerd.",
            "Bij tijdelijke druk wacht de verwerkingsgroep voordat nieuwe taken of herstelpogingen starten. De app verlaagt dan de gelijktijdigheid en respecteert een opgegeven wachttijd. Maximaal drie herstelpogingen per taak en een begrensde totale wachttijd voorkomen eindeloos proberen.",
            "De standaard blijft maximaal 32 gelijktijdige taken voor alle ChatGPT-modellen. Reeds beschikbare resultaten en de bestaande cache blijven behouden. Een echte account- of gebruiksgrens kan de app niet opheffen.",
            "Foutdiagnose bewaart alleen beperkte technische foutgegevens, zonder documenttekst, prompts, antwoorden of aanmeldgegevens. Apple Intelligence, broninhoud en analyseopdrachten zijn niet gewijzigd."
        ]),
        .init(version: "5.18.0", date: "26 oktober 2026", changes: [
            "De kernselectie gebruikt dezelfde volledige bronalinea’s als de alineapunten, inclusief herkende vervolgen op de volgende pagina. Een alinea wordt eenmaal beoordeeld en kan in meerdere passende categorieën verschijnen.",
            "Punten uit dezelfde bronpassage staan bij elkaar in het puntenoverzicht. Alle deelpunten, sterren en andere acties blijven beschikbaar. Lees passage opent de volledige gezamenlijke bron zonder de AI-teksten samen te voegen.",
            "Te lange of niet succesvol beoordeelde alinea’s blijven zichtbaar als niet automatisch beoordeeld. De volledige tekst wordt niet afgekapt om toch een AI-beoordeling te krijgen.",
            "Broncontext en werkdocumenten bewaren de volledige alinea en bijbehorende pagina’s. Oude werkdocumenten blijven leesbaar; kies Analyseer om een oudere kernselectie met de nieuwe bronindeling te vernieuwen.",
            "Er is geen automatische inhoudelijke bundeling van verschillende alinea’s toegevoegd. De bestaande AI-samenvattingsopdrachten voor punten blijven behouden; volledigheid en juistheid van AI-teksten zijn niet gegarandeerd."
        ]),
        .init(version: "5.17.0", date: "26 oktober 2026", changes: [
            "Alle ChatGPT-analysefasen kunnen maximaal 32 onafhankelijke aanvragen tegelijk uitvoeren, voor ieder gekozen model en redeneerniveau. Dit geldt voor zowel één model als orchestrator en subagents.",
            "Bij een snelheidslimiet of tijdelijke overbelasting verlaagt de betreffende verwerking automatisch de gelijktijdigheid. De getroffen taak krijgt maximaal één herstelpoging binnen die verwerking.",
            "Onderling afhankelijke stappen blijven op elkaar wachten. De afzonderlijke analyseopdrachten, broninformatie, resultaatvolgorde en bestaande controles blijven behouden. De werkelijke snelheid hangt af van het model, het document en de beschikbare capaciteit.",
            "Apple Intelligence behoudt de bestaande lokale verwerking. Deze wijziging voegt geen bundeling van passages of gewijzigde inhoudelijke beoordeling toe."
        ]),
        .init(version: "5.16.1", date: "26 oktober 2026", changes: [
            "Het verwerkingsscherm toont een korte hoofdstatus en een compacte stappenrij voor document lezen, punten, samenvatting en kernselectie.",
            "Technische status, modelgegevens en verstreken tijd staan onder uitklapbare Details. De voortgangsteller, tijdschatting, grote documentanimatie en bestaande knoppen blijven behouden.",
            "De analyse, bronverwerking en gelijktijdigheid van aanvragen veranderen niet."
        ]),
        .init(version: "5.16.0", date: "26 oktober 2026", changes: [
            "ChatGPT voegt deelsamenvattingen met Astra medium als orchestrator met maximaal 32 aanvragen tegelijk samen. Bij een tijdelijke overbelasting verlaagt de app de gelijktijdigheid en probeert de getroffen aanvraag één keer opnieuw. Andere modellen en de overige analysefasen behouden hun bestaande grenzen.",
            "Bij ChatGPT staan kerngegevens uit de bron vóór de AI-leeswijzer. Een citaat wordt alleen als letterlijke bron getoond als het exact voorkomt op de genoemde pagina. AI-titels en statusinterpretaties zijn apart uitklapbaar; de selectie kan onvolledig zijn.",
            "Open volledige broncontext om alle beschikbare tekst van de bronpagina en de aangrenzende pagina’s te lezen of te kopiëren. De originele PDF blijft bereikbaar voor tabellen, opmaak en verdere context.",
            "De AI-leeswijzer blijft beschikbaar en kan informatie missen. Deze wijziging garandeert geen volledige of foutloze AI-analyse. Apple Intelligence, volledige bronnen, selecties, werkdocumenten en bestaande export blijven behouden."
        ]),
        .init(version: "5.15.1", date: "26 oktober 2026", changes: [
            "Bij het samenvoegen van ChatGPT-deelsamenvattingen telt de voortgang iedere afgeronde samenvoeging. De teller blijft niet meer op nul staan terwijl er wel resultaten binnenkomen.",
            "De voortgang en tijdschatting gebruiken het aantal samenvoegingen, ook binnen een PDF-pagina. De tijdschatting bouwt op uit afgeronde stappen en wordt niet bij iedere samenvoegronde opnieuw gewist.",
            "De inhoudelijke analyse, samenvattingsopdrachten en werking van Apple Intelligence blijven behouden. Verdere versnelling van ChatGPT wordt afzonderlijk onderzocht."
        ]),
        .init(version: "5.15.0", date: "26 oktober 2026", changes: [
            "Zelf gekozen passages en ander automatisch bewaard werk worden op de achtergrond omgezet en opgeslagen. Snelle wijzigingen blijven in volgorde bewaard; de laatste versie blijft behouden.",
            "Bij afsluiten wacht de app op lopende opslag en controleert opnieuw of er niet-bewaarde wijzigingen zijn. Opslagfouten worden gemeld en onderbreken het afsluiten.",
            "Lange zelf gekozen passages openen in de bestaande leesweergave, met de volledige letterlijke selectietekst, zoeken, kopiëren en bronpagina’s. Korte passages blijven direct uitklapbaar.",
            "Eigen notities staan apart en ingeklapt in de leesweergave. Trefwoordhulp en bronmarkeringen zijn optioneel en staan bij zelf gekozen passages standaard uit."
        ]),
        .init(version: "5.14.0", date: "26 oktober 2026", changes: [
            "Het documentoverzicht staat vooraan. De leesagenda is ingeklapt, toont alleen categorieën met punten en houdt zichtbaar wanneer de verwerking nog niet afgerond is.",
            "Zoek lokaal ook in zelf gekozen passages, titels, notities en puntnotities. Een zoekresultaat opent de bijbehorende selectiekaart of het punt, ook als eerder ingestelde puntfilters de kaart zouden verbergen.",
            "Vergelijk punten en de rondleiding staan bij de hulpmiddelen; rondleiding is ook vanaf het welkomstscherm bereikbaar. De vijf vaste onderdelen en bestaande hoofdacties blijven beschikbaar.",
            "Tijdens het verwerken kun je met Open document en resultaten naar de beschikbare werkruimte gaan. Dit verandert de analysevolgorde niet.",
            "De exportvoorinstellingen blijven snel bereikbaar; Inhoud aanpassen toont de losse onderdelen. De bevestiging volgt dezelfde volgorde als de PDF. Je kunt het renderen annuleren voordat het bestand atomair wordt opgeslagen.",
            "Diagnosemetingen scheiden testuitvoer per proces in een tijdelijke map, zodat tests de gebruikersgeschiedenis niet verdringen. Rapporten bevatten appversie en build en meten ook de tijd tot de documentsamenvatting; documenttekst en prompts worden niet opgeslagen."
        ]),
        .init(version: "5.13.0", date: "26 oktober 2026", changes: [
            "Selecteer tekst in de PDF en kies Opnemen in samenvatting. De letterlijke passage en fysieke bronpagina’s worden in Mijn selectie bewaard, ook zonder AI-analyse.",
            "Zelf gekozen passages hebben een herkenbare eigen plek. Je kunt een titel en eigen notitie toevoegen, de volgorde aanpassen, de volledige passage lezen en de bijbehorende bronpagina’s openen.",
            "Je passages blijven behouden bij opnieuw analyseren en worden bewaard in werkdocumenten en bij het opnieuw openen van dezelfde PDF. Eerdere werkdocumenten blijven leesbaar.",
            "De PDF-export neemt zelf gekozen passages standaard op als apart onderdeel, met volledige tekst, bronpagina’s en eigen toelichting. Je kunt dit onderdeel in de exportwizard uitschakelen.",
            "De bestaande actie Vat selectie samen, automatische analyse, Apple Intelligence en ChatGPT, AI-punten, selectie en overige exportonderdelen blijven beschikbaar. Het opnemen van passages doet geen extra AI-aanvragen."
        ]),
        .init(version: "5.12.0", date: "26 oktober 2026", changes: [
            "ChatGPT heeft een expliciete keuze tussen één model voor alle taken en een orchestrator met afzonderlijke subagents. Bestaande modelkeuzes blijven behouden. De voortgang vermeldt het model dat de huidige fase uitvoert.",
            "De neutrale ChatGPT-analyse verwerkt met Astra medium als uitvoerend model maximaal vier alinea-aanvragen tegelijk. Andere modellen of redeneerniveaus behouden twee. De afzonderlijke analyseopdracht en broncontrole blijven gelijk. Bij overbelasting wordt de gelijktijdigheid verlaagd en volgt één begrensde herstelpoging per getroffen aanvraag.",
            "Afgeronde ChatGPT-alinea’s worden eerder zichtbaar, in de oorspronkelijke documentvolgorde. De voortgang vermeldt herstelpogingen en wacht langer met een tijdschatting totdat voldoende voortgang is gemeten.",
            "Het samen versturen van meerdere alinea’s is na de inhoudelijke proef niet geactiveerd. Apple Intelligence behoudt de bestaande lokale verwerking. Programmavergelijking behoudt de kandidaatvolgorde en broncontrole; automatische start, leesweergave, selectie, werkdocumenten en export blijven beschikbaar."
        ]),
        .init(version: "5.11.0", date: "22 oktober 2026", changes: [
            "De leesweergave heeft optionele bronmarkeringen voor datums en termijnen, geldbedragen en woorden bij voorwaarden of status. Iedere categorie staat bij openen standaard uit.",
            "Korte markeringen wijzen naar de oorspronkelijke tekst. Op verzoek kun je ruimere context bekijken, inclusief omliggende alinea’s, lijstinleidingen en tabelkoppen. De volledige opgeslagen brontekst blijft altijd beschikbaar.",
            "De bronhulp werkt lokaal en doet geen extra AI-aanvragen. Markeringen zijn zoekhulp en geen garantie dat alle relevante informatie is gevonden of een datum een deadline is.",
            "Zoeken, bestaande vindplaatsen, bronpagina’s, tekstselectie en kopiëren blijven beschikbaar. De analyse met Apple Intelligence en ChatGPT, export en werkdocumenten behouden hun werking."
        ]),
        .init(version: "5.10.0", date: "22 oktober 2026", changes: [
            "Analysepunten worden na het inlezen als eerste verwerkt. Het documentoverzicht en de kernselectie volgen daarna en blijven volledig beschikbaar.",
            "Bij gewijzigde lange alinea’s worden eerder opgeslagen deelresultaten alleen hergebruikt als ook de volledige bronpassage overeenkomt. Zo blijft de leesweergave aan de juiste bron gekoppeld.",
            "De kernselectie herkent nu ook uitgeschreven relatieve termijnen, zoals binnen zes weken. Dit blijft een leeshulp en geen garantie dat alle termijnen zijn gevonden.",
            "ChatGPT-programmavergelijking kan bij hervatten geslaagde kandidaatdelen hergebruiken. Fouten en afgebroken aanvragen worden niet als geslaagde uitkomsten bewaard; de bestaande broncontrole blijft behouden.",
            "Lokale meetbestanden tonen verwerkingstijd per fase, aanvragen, herhaalpogingen en cachegebruik. Ze bevatten geen documentnamen, brontekst, prompts of antwoorden; maximaal twintig meetbestanden blijven bewaard.",
            "Apple Intelligence en ChatGPT behouden hun analysefuncties, volledige bronpassages, selectie, export en werkdocumenten. Experimentele automatische feitencontrole en grotere samenvattingsinvoer zijn niet toegevoegd."
        ]),
        .init(version: "5.9.0", date: "22 oktober 2026", changes: [
            "Lees passage opent een aparte leesweergave met de volledige opgeslagen alineabron, ook als die over meerdere PDF-pagina’s loopt. De bestaande bronknop blijft beschikbaar.",
            "Zoek in de brontekst en blader tussen gemarkeerde vindplaatsen zonder tekst in te korten. De omliggende tekst blijft leesbaar en selecteerbaar.",
            "Een optionele trefwoordhulp biedt letterlijke vindplaatsen rond termijnen, voorwaarden en besluiten. De hulp staat standaard dicht en is geen volledige voorwaardenlijst of inhoudelijke beoordeling.",
            "Bij oudere werkdocumenten zonder volledige alineabron toont de leesweergave de bewaarde passage met een duidelijke toelichting.",
            "De bestaande analyse met Apple Intelligence en ChatGPT, automatische start, selectie, vragen, export en werkdocumenten behouden hun werking."
        ]),
        .init(version: "5.8.0", date: "21 oktober 2026", changes: [
            "Analysepunten gebruiken volledige alinea’s als basis, met het herkenbare vervolg op de volgende PDF-pagina. Dit geldt voor Apple Intelligence en ChatGPT.",
            "Relevante omliggende brontekst kan verwijzingen en voorwaarden verduidelijken. Gebruikte contextbronnen zijn bij het punt terug te vinden.",
            "Lange alinea’s worden in gekoppelde delen gelezen met behoud van de volledige bron. Apple Intelligence blijft lokaal werken; deelpunten worden niet opnieuw samengevat tot één mogelijk onvolledige tekst.",
            "Hoofdpunten, achtergrond en onzekere bevindingen worden onderscheiden met een korte reden. Achtergrond blijft beschikbaar bij Alle punten en vult niet automatisch de belangrijkste punten.",
            "Alineadelen, relevantiebeoordeling en contextbronnen blijven behouden in werkdocumenten en export. Bestaande werkdocumenten blijven leesbaar.",
            "Automatische inhoudelijke samenvoeging van zelfstandige alinea’s blijft buiten de app. Bronverwijzingen en verwerkingsdekking zijn geen garantie voor feitelijke juistheid."
        ]),
        .init(version: "5.7.0", date: "20 oktober 2026", changes: [
            "Een compacte leesagenda helpt je vanuit Overzicht naar bestaande punten over besluiten, geld, termijnen en open vragen te springen.",
            "Een opvraagbaar dekkingsoverzicht onderscheidt leesbare pagina’s, voltooide verwerking en tabellen die broncontrole nodig hebben. Onbekende dekking blijft herkenbaar.",
            "Mijn selectie biedt de statussen Bespreken, Vraag stellen en Afgehandeld en een eigen volgorde voor je vergadervoorbereiding. Die volgorde wordt meegenomen in de selectie-export.",
            "Bekijk gerelateerde punten naast elkaar met behoud van de afzonderlijke teksten en bronpagina’s.",
            "Werkdocumenten bewaren ook je weergavestand, selectiestatussen en volgorde. Onbewaarde wijzigingen zijn zichtbaar; vóór sluiten of vervangen kun je bewaren, verwerpen of annuleren.",
            "Oude werkdocumenten blijven leesbaar. De bestaande automatische analyse en de verwerking met Apple Intelligence en ChatGPT blijven behouden."
        ]),
        .init(version: "5.6.3", date: "18 oktober 2026", changes: [
            "Werkdocumenten kunnen nu ook worden bewaard wanneer een onzekere teksttabel een wisselend aantal cellen per rij heeft. De oorspronkelijke koppen en cellen blijven volledig behouden.",
            "De controles op betrouwbare teksttabellen, OCR-tabellen en geldige bronpagina’s blijven behouden. Dit verhelpt de onterechte melding over een ongeldig werkdocument bij onder meer het Bestuursverslag Sociaal Domein over 2025."
        ]),
        .init(version: "5.6.2", date: "17 oktober 2026", changes: [
            "Bedienlabels volgen consequenter de gekozen Nederlandse of Engelse interfacetaal. Brontekst en analyseresultaten behouden hun oorspronkelijke taal.",
            "Tabelcontrole, tekstindeling en diagramselectie passen zich aan kleinere vensters aan. De inhoud kan scrollen terwijl de afsluitende acties bereikbaar blijven.",
            "Puntgroepen kunnen ook bij Compact lezen daadwerkelijk worden in- en uitgeklapt. Zoeken en bronverwijzingen blijven de juiste groep openen.",
            "Tekstindeling controleren opent op de PDF-pagina die op dat moment zichtbaar is, ook nadat je door de PDF hebt gescrold.",
            "De bestaande analyse, AI-providers, broncontrole, opslag en automatische analyse na het openen van een PDF zijn behouden."
        ]),
        .init(version: "5.6.1", date: "17 oktober 2026", changes: [
            "Annuleren tijdens het inlezen van een vervangende PDF behoudt het huidige document, de analyseresultaten en je eigen werk.",
            "Een tekstindelingscorrectie behoudt de afzonderlijke opslag van geopende werkdocumenten. Vragen, notities en selecties van een gewone PDF worden bij de juiste indeling geladen.",
            "Werkdocumenten met ongeldige OCR-tabelstructuur of ongeldige tabelpagina’s worden afgewezen voordat ze de huidige werkruimte vervangen.",
            "De OCR-verwerking hergebruikt bestaande afbeeldingsgegevens, zodat dezelfde afbeelding niet voor iedere onzekere numerieke cel opnieuw hoeft te worden omgezet. De herkenningsregels blijven gelijk."
        ]),
        .init(version: "5.6.0", date: "7 oktober 2026", changes: [
            "Rustiger ontwerp met neutrale achtergronden, subtiele leeskaarten, kleinere koppen en consequente afrondingen. Het accent blijft voor belangrijke acties en de actieve tab.",
            "Het welkomstscherm geeft PDF toevoegen de hoofdrol. De importkaart heeft een subtiele rand; het neerzetten van een bestand blijft duidelijk zichtbaar. Het scherm kan scrollen bij weinig verticale ruimte.",
            "Afkortingen en Tekstindeling staan samen onder Leesopties. Analyseoverzicht blijft naast PDF inklappen. De actieve tab is herkenbaar aan een onderstreping en toegankelijkheidsstatus.",
            "Actieve punten krijgen naast kleur een label. Leesacties tonen een uitgeschakelde toestand en focusrand; schermovergangen respecteren Verminder beweging. Tabeltekst krijgt ruimte om door te lopen.",
            "De analyse, AI-providers, broncontrole en werkdocumenten blijven dezelfde werking behouden."
        ]),
        .init(version: "5.5.0", date: "7 oktober 2026", changes: [
            "Onzekere numerieke OCR-cellen worden met meerdere uitsneden, vergrotingen en contrasten opnieuw gelezen. Alleen overeenstemmende waarden worden overgenomen; ontbrekende cijfers worden nooit uit totalen afgeleid.",
            "Controleer en corrigeer cellen en kolomkoppen naast een uitsnede van de oorspronkelijke PDF. Rekencontroles tonen aansluitende bedragen en afwijkingen; lege cellen blijven onderscheiden van nul.",
            "Na jouw volledige broncontrole kun je afzonderlijke tabelleespunten laten kiezen met de geselecteerde AI-provider. De app toont uitsluitend exacte gecontroleerde broncellen met omschrijving, kolom en pagina, ook in Overzicht.",
            "Werkdocumenten bewaren correcties, broncontrole en tabelleespunten. Bij een celwijziging vervallen controle en leespunten. Tabel-export vermeldt de controlestatus. De bestaande automatische documentanalyse blijft gelijk."
        ]),
        .init(version: "5.4.0", date: "7 oktober 2026", changes: [
            "Afbeeldingstabellen met duidelijke rasterlijnen worden bij PDF-import lokaal met OCR gelezen. De herkende rijen en kolommen zijn zichtbaar in Tabellen, inclusief lege cellen en bronpagina.",
            "OCR-tabellen hebben de melding Nog controleren. Ze leveren geen automatische cijfervergelijkingen en worden niet toegevoegd aan de AI-analyse. Controleer bedragen, mintekens en kolomkoppen in de bron.",
            "Herkende OCR-tabellen worden meegenomen in werkdocumenten en kunnen met duidelijke controlewaarschuwing worden geëxporteerd. De oorspronkelijke PDF blijft ongewijzigd."
        ]),
        .init(version: "5.3.1", date: "7 oktober 2026", changes: [
            "Het analyseoverzicht is standaard verborgen. Met de knop Analyseoverzicht naast PDF inklappen toon of verberg je de kaart met voortgang en herstelacties. Bij een nieuw document wordt de kaart weer verborgen.",
            "Het tabblad Tabellen legt bij ontbrekende teksttabellen uit dat tabellen als afbeelding eerst OCR nodig hebben."
        ]),
        .init(version: "5.3.0", date: "6 oktober 2026", changes: [
            "Paginakeuzes gelden consequent voor overzicht, analysepunten en concrete bronpassages. Ook de hoofdknop gebruikt je gekozen bereik.",
            "Een compacte analysekaart toont bereik, provider, voortgang, verstreken tijd en direct bereikbare herstelacties. Je kunt alleen ontbrekende onderdelen opnieuw laten verwerken met de oorspronkelijke modelkeuze.",
            "ChatGPT vult vrijgekomen werkplekken direct aan en voegt onafhankelijke samenvattingsparen gelijktijdig samen. Succesvolle programmastappen worden apart bewaard; broncontrole hergebruikt voorbereid zoekmateriaal. Apple Intelligence behoudt de bestaande modelverwerking.",
            "Bewaar een lokaal werkdocument met bron-PDF, resultaten, selectie, notities, instellingen van de opdracht en leespositie. Open het later zonder verplichte heranalyse via Werkdocument.",
            "Voeg eigen notities en controlemarkeringen toe aan punten. Bij gewijzigde AI-uitleg is opnieuw controleren nodig. Compact lezen en filters op pagina en controle helpen bij lange documenten.",
            "Export biedt Kort overzicht, Mijn selectie met bronnen en Volledig dossier, met een lokaal PDF-voorbeeld en optionele eigen notities.",
            "Samenvatten van geselecteerde tekst heeft een herstelknop. Annuleren van de exportmapkeuze toont geen fout. Herhaalde commissievragen behouden alle bronpagina’s."
        ]),
        .init(version: "5.2.0", date: "6 oktober 2026", changes: [
            "Alleen bij ChatGPT: kies een apart model en redeneerniveau voor de orchestrator en de subagents. Subagents verwerken passages; de orchestrator maakt het documentoverzicht en controleert de bronnen bij programmavergelijking.",
            "ChatGPT kan maximaal twee onafhankelijke aanvragen tegelijk uitvoeren. Document- en alineasamenvattingen gebruiken grotere tekstblokken, met behoud van bronpagina’s en resultaatvolgorde. Apple Intelligence behoudt de bestaande verwerking.",
            "Bij programmavergelijking blijven bronblokken, programmakandidaten en citaatcontrole behouden; alleen het onafhankelijke werk wordt bij ChatGPT gelijktijdig ingepland.",
            "Instellingen verklaart na het vernieuwen van modellen of GPT-6.1 Sol ontbreekt in de serverlijst, verborgen is teruggegeven of onvolledige modelgegevens heeft. De app voegt geen niet-aangeboden modellen toe.",
            "Beide modelkeuzes worden bij de start vastgelegd. Bestaande Apple-cache blijft behouden; ChatGPT-samenvattingscache is vernieuwd voor de aangepaste verwerking."
        ]),
        .init(version: "5.1.1", date: "5 oktober 2026", changes: [
            "ChatGPT-antwoorden worden correct ingelezen, ook wanneer de netwerkverbinding tekst in kleine delen verstuurt. Een fout waardoor de analyse kon stoppen op 0% is hersteld.",
            "Een volledig afgerond ChatGPT-antwoord wordt direct verwerkt; de app wacht niet meer tot de verbinding sluit. Onderbroken of geweigerde antwoorden blijven uitgesloten.",
            "Als de documentsamenvatting mislukt, verschijnt de fout ook direct bij handmatige heranalyse, zodat stoppen niet ongemerkt blijft."
        ]),
        .init(version: "5.1.0", date: "5 oktober 2026", changes: [
            "Kies Apple Intelligence of ChatGPT als AI-provider. Na het openen van een PDF start de analyse automatisch met de gekozen provider.",
            "Log in met ChatGPT vanuit Instellingen en kies uit de modellen van je account, inclusief het ondersteunde redeneerniveau. Inloggegevens worden in de macOS-sleutelhanger bewaard.",
            "ChatGPT ondersteunt documentoverzicht, alineapunten, programmavergelijking, bronpassages, passagevragen en documentchat. De interface vermeldt dat documentinhoud online naar OpenAI wordt verstuurd.",
            "Modelkeuzes worden per opdracht vastgelegd; caches onderscheiden provider, model en redeneerniveau. Onderbroken of geweigerde ChatGPT-antwoorden gelden niet als voltooid. Diagramuitleg blijft via Apple Intelligence lopen."
        ]),
        .init(version: "5.0.1", date: "5 oktober 2026", changes: [
            "De AI-analyse start weer automatisch zodra een PDF is ingelezen, zoals in eerdere versies. De keuze om automatische analyse uit te zetten is verwijderd."
        ]),
        .init(version: "5.0.0", date: "5 oktober 2026", changes: [
            "Afzonderlijke app en lokale opslag, met eenmalige kopie van bestaande instellingen en werk. De app gebruikt eigen opslag en een neutrale naam.",
            "Vaste navigatie naar Overzicht, Punten, Tabellen, Mijn selectie en Zoeken. Puntkaarten hebben direct een bronknop; zoekresultaten openen het gevonden punt.",
            "Zoeken gebeurt op de achtergrond, met korte invoerpauze en annulering van verouderde zoekopdrachten. Zoektekst wordt vooraf voorbereid.",
            "PDF-tekst, leesvolgorde en tabellen gebruiken één extractiestap. Stoppen wordt ook binnen grote woord- en rijlussen gecontroleerd. De programma-index wordt per analyse hergebruikt.",
            "Focuswijzigingen behouden leesstructuur en waarschuwingen. Paginabereik wordt vóór analyse gecontroleerd; hervatten gebruikt de oorspronkelijke selectie en instellingen.",
            "Openen zonder automatische AI-analyse is mogelijk. Verwerkingsstatus is zichtbaar per onderdeel; herstelacties richten zich op het betreffende onderdeel. Tijdschattingen gelden voor de actuele fase.",
            "Export vanuit Mijn selectie volgt de huidige selectie. Een ontbrekende standaardmap blokkeert opslaan niet meer. Export gebruikt een vaste momentopname en rendert en schrijft op de achtergrond.",
            "Passagevragen en documentgesprekken worden lokaal bewaard. Puntkaarten maken de kerntekst toegankelijk voor VoiceOver; diagramgebieden kunnen ook met het toetsenbord worden opgegeven."
        ]),
        .init(version: "3.7.2", date: "5 oktober 2026", changes: [
            "CommissieWijzer gebruikt uitsluitend Apple Intelligence op deze Mac. De Ollama-ondersteuning, modelkeuze en automatische providerwissel zijn verwijderd.",
            "Instellingen toont de beschikbaarheid van Apple Intelligence met een controleknop. De rondleiding laat zien hoe je die controleert. Als Apple Intelligence niet beschikbaar is, krijg je de reden te zien.",
            "Bestaande AI-instellingen worden overgezet naar Apple Intelligence. Documenten, partijprogramma, weergave- en exportinstellingen blijven behouden."
        ]),
        .init(version: "3.7.1", date: "4 oktober 2026", changes: [
            "Samenvattingspunten openen met een compacte kernselectie: maximaal twaalf punten in totaal en maximaal drie per onderwerp. Alle oorspronkelijke punten blijven onder Alle punten beschikbaar.",
            "De kaart biedt Belangrijkste, Alle punten en Mijn selectie met aantallen. Mijn selectie toont per onderwerp hoeveel punten zijn bewaard en plaatst concrete besluiten, geld en termijnen vooraan.",
            "Puntkaarten tonen standaard een korte kerntekst, bronpagina en waar duidelijk herkenbaar een rustig tekstlabel. Uitklappen toont de volledige tekst, bron en bestaande acties."
        ]),
        .init(version: "3.7.0", date: "4 oktober 2026", changes: [
            "Nieuwe gebruikers starten met een neutrale samenvatting. Voor programmavergelijking toont CommissieWijzer wanneer een partijprogramma ontbreekt.",
            "Bij import is de voortgang per gelezen PDF-pagina zichtbaar. Annuleren stopt ook het inlezen; bij een gescande PDF zonder tekstlaag krijg je een aanwijzing voor OCR.",
            "Nieuwe pdf opent direct de bestandskiezer. Het huidige document blijft beschikbaar totdat de vervangende PDF is ingelezen. Cmd-O opent een PDF en Cmd-F zet de cursor in de zoekbalk.",
            "De verwerkingsmodus heeft een compactere plaats. Stopknoppen maken duidelijk of je teruggaat naar import of de huidige resultaten behoudt. Na de hoofdsamenvatting verschijnen kernpunten eerder.",
            "Een puntkaart klapt open zonder de PDF tegelijk naar de bron te laten springen. Geavanceerde AI-keuzes staan in Instellingen achter een uitklapbare sectie."
        ]),
        .init(version: "3.6.3", date: "26 september 2026", changes: [
            "Start analyse in het hoofdscherm houdt het hoofdscherm zichtbaar. Ook opnieuw samenvatten en ontbrekende stappen opnieuw proberen openen het splashscherm niet meer. Het splashscherm blijft voor PDF-import en de automatische analyse daarna."
        ]),
        .init(version: "3.6.2", date: "26 september 2026", changes: [
            "Bekijk tussentijdse resultaten opent vanuit het splashscherm met een rustige fade het hoofdscherm. De analyse gaat door en nieuwe resultaten blijven verschijnen. De knop wordt beschikbaar zodra de PDF is ingeladen."
        ]),
        .init(version: "3.6.1", date: "26 september 2026", changes: [
            "Het splashscherm ontvouwt vloeiender en bouwt de abstracte tekstregels kort na elkaar op. De scanlijn versnelt en vertraagt rustig, met een zachte gloed en subtiel oplichtende regels.",
            "Analysestappen vervagen naar de volgende tekst en de voortgangsbalk beweegt soepel mee. Bij voltooiing verschijnt kort een vinkje voordat het hoofdscherm opent.",
            "De effecten blijven beperkt tot de kleine illustratie; bij Verminder beweging blijven de illustratie en voortgangsovergangen stil."
        ]),
        .init(version: "3.6.0", date: "26 september 2026", changes: [
            "Na PDF-import blijft een rustig verwerkingsscherm zichtbaar tijdens het inladen en de analyse, met een ontvouwende documentillustratie, scanlijn, percentage en geschatte resterende tijd.",
            "Na voltooiing verschijnt het hoofdscherm met een vloeiende fade. Stop analyse annuleert de verwerking en brengt je terug naar het importscherm.",
            "Bij onvolledige verwerking kun je de melding lezen en de beschikbare resultaten openen. De animatie blijft licht en staat stil bij Verminder beweging."
        ]),
        .init(version: "3.5.4", date: "25 september 2026", changes: [
            "De kop van iedere categorie in Samenvattingspunten is nu over de volle breedte klikbaar. Een ruimere klikzone maakt openen en sluiten makkelijker, zonder extra kleurvlakken in de kaart."
        ]),
        .init(version: "3.5.3", date: "25 september 2026", changes: [
            "Tijdens de analyse worden zoekgegevens, samenvattingspagina’s en gegroepeerde punten alleen opnieuw opgebouwd wanneer de bijbehorende resultaten veranderen. Dit beperkt werk op de hoofdthread bij voortgangsupdates.",
            "Lange lijsten met samenvattingen en aandachtspunten worden pas getekend wanneer ze in beeld komen. De AI-analyse en broncontroles zijn niet gewijzigd."
        ]),
        .init(version: "3.5.0", date: "25 september 2026", changes: [
            "Selecteer zelf een cirkel- of staafdiagram in de PDF met de knop Diagram selecteren. De uitleg opent naast de gekozen uitsnede en vermeldt de bronpagina.",
            "Op macOS 27 gebruikt de diagramuitleg het lokale beeldmodel van Apple Intelligence. Zichtbare cijfers worden alleen als waarde getoond als tekstherkenning ze in de uitsnede bevestigt; onzekere gegevens blijven buiten de uitleg.",
            "Je kunt de diagramuitleg kopiëren. Op Macs zonder beschikbare lokale beeldanalyse toont CommissieWijzer een duidelijke melding."
        ]),
        .init(version: "3.4.2", date: "25 september 2026", changes: [
            "De knop Rondleiding staat nu rechtsboven in de vaste bovenbalk en blijft zichtbaar wanneer een PDF is geopend.",
            "Het uploadvak bevat alleen nog de bediening voor het toevoegen van een PDF. De rondleiding blijft ook bereikbaar via Instellingen."
        ]),
        .init(version: "3.4.1", date: "25 september 2026", changes: [
            "De aanwijzer in de rondleiding beweegt vloeiend naar knoppen, vertraagt voor een klik en laat daarna het resultaat zien.",
            "Bij het selecteren van PDF-tekst volgt de aanwijzer de tekstregel. De selectiemarkering groeit mee voordat ‘Vat selectie samen’ verschijnt.",
            "Met ‘Verminder beweging’ blijft de rondleiding direct het stilstaande eindbeeld tonen."
        ]),
        .init(version: "3.4.0", date: "25 september 2026", changes: [
            "De rondleiding toont nu echte CommissieWijzer-bediening en kaarten met een fictieve PDF. De voorbeelden blijven daardoor gelijk aan de interface die je buiten de rondleiding gebruikt.",
            "De demonstraties volgen de werkelijke knoppen en schermdelen, van PDF openen en analyse tot tekstselectie, zoeken, bronverwijzingen en export.",
            "De voorbeelden werken geïsoleerd met oefengegevens: ze wijzigen geen eigen bestanden of instellingen en starten geen AI-aanvragen."
        ]),
        .init(version: "3.3.1", date: "24 september 2026", changes: [
            "De tutorial laat nu per stap de handeling zelf zien: een zichtbare aanwijzer gaat naar de knop of sleept over PDF-tekst, gevolgd door het resultaat op de juiste plek in de voorbeeldinterface.",
            "Korte onderschriften benoemen de handeling en het resultaat. De voorbeelden voor bronverwijzing, tekstselectie, zoeken en export zijn aangepast aan de werkelijke bediening van CommissieWijzer."
        ]),
        .init(version: "3.3.0", date: "24 september 2026", changes: [
            "De twaalf tutorialvoorbeelden spelen nu bij het openen van een stap een korte demonstratie af. Ze tonen onder meer het openen van een PDF, analysevoortgang, bronverwijzingen, tekstselectie, zoeken en exporteren.",
            "Elke demonstratie stopt op een leesbaar eindbeeld en kan met ‘Opnieuw afspelen’ opnieuw starten. Bij de macOS-instelling ‘Verminder beweging’ verschijnt direct het stilstaande eindbeeld."
        ]),
        .init(version: "3.2.0", date: "24 september 2026", changes: [
            "Een optionele rondleiding in een modal legt de twaalf basisstappen van CommissieWijzer uit met visuele voorbeelden en korte uitleg. De voorbeelden zijn fictief en veranderen geen documenten of instellingen.",
            "Open de rondleiding vanaf het welkomstscherm via ‘Bekijk de rondleiding’ of later via Instellingen → ‘Zo werkt CommissieWijzer’. Blader met Vorige en Volgende; sluit wanneer je wilt via de knop rechtsboven."
        ]),
        .init(version: "3.1.0", date: "24 september 2026", changes: [
            "Eén zoekveld boven de inhoud doorzoekt de PDF-tekst, document- en paginasamenvattingen, aandachtspunten, tabeluitleg en afkortingen. Het eerdere zoekveld binnen de aandachtspuntenkaart is vervallen.",
            "Zoekresultaten tonen een kort fragment en hun herkomst. Een klik opent waar mogelijk direct de fysieke PDF-pagina; een afkorting opent de gefilterde afkortingenlijst.",
            "Zoeken gebeurt lokaal zonder AI-aanvraag of internetverbinding. Resultaten verschijnen ook terwijl een analyse nog bezig is."
        ]),
        .init(version: "3.0.2", date: "23 september 2026", changes: [
            "Patch notes tonen nu een versiegeschiedenis. Elke update krijgt bovenaan een eigen sectie met het versienummer en de wijzigingen; oudere versies blijven beschikbaar."
        ]),
        .init(version: "3.0.1", date: "23 september 2026", changes: [
            "Als Apple Intelligence de hoofdsamenvatting niet kan samenvoegen, verschijnt automatisch een gemarkeerd overzicht uit de beschikbare deelsamenvattingen, met paginaverwijzingen. Hiervoor wordt geen nieuwe AI-aanvraag gedaan.",
            "Het compacte overzicht bevat maximaal 25 zinnen. Alle beschikbare delen blijven onder Uitgebreide samenvatting staan. Ontbrekende verwerking en de waarschuwing gaan mee in de export.",
            "De knop Patch notes in Instellingen opent een venster met de wijzigingen."
        ]),
        .init(version: "3.0.0", date: "23 september 2026", changes: [
            "Samenvattingspunten staan in uitklapbare groepen per hoofdstuk of onderwerp. Bijna identieke punten worden behoudend samengevoegd, met behoud van bronverwijzingen. De export neemt deze groepering over.",
            "Automatische leesvolgorde voor maximaal drie tekstkolommen, met extra herkenning bij ongelijke regelhoogten. Onzekere pagina’s worden overgeslagen en gemeld.",
            "Tekstindeling biedt een optioneel vangnet: kies per pagina een kolomaantal of tekstgebied en bekijk de herkende leesvolgorde."
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
