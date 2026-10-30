# Privacybeleid — CommissieWijzer

Laatst bijgewerkt: 30 oktober 2026. Dit document beschrijft de huidige appimplementatie voor releasevoorbereiding. Controleer de definitieve App Store-build en Apple’s actuele App Privacy-vragen vóór inzending. De App Store-vragenlijst is nog niet ingediend.

## In het kort

CommissieWijzer heeft geen eigen gebruikersaccount, backend, cloudopslag, telemetrie, advertenties, analytics of tracking. Pdf’s, werkdocumenten, notities, voorkeuren, analysecache en diagnostische bestanden blijven op je Mac. Je kunt optioneel een online provider of externe woordenlijst gebruiken; in die gevallen wordt de benodigde inhoud rechtstreeks naar de betreffende dienst gestuurd.

## Lokaal op je Mac

De app bewaart lokaal:

- de pdf die je opent en een werkdocument dat je zelf opslaat;
- de beschikbare analyse, bronverwijzingen, geselecteerde passages en notities;
- voorkeuren en lokale cachebestanden;
- begrensde diagnostiek voor ChatGPT-verbindingsproblemen, zoals de foutcategorie, HTTP-status, beperkte technische foutcodes, een OpenAI-request-ID, wachttijd en appversie.

De lokale ChatGPT-diagnostiek bewaart geen documentinhoud, prompts, antwoordtekst, tokens, wachtwoorden of volledige serverresponses. Bestanden staan in de door macOS en de app gekozen lokale opslag. Werkdocumenten staan op de locatie die jij kiest.

## Apple Intelligence

Apple Intelligence is een optionele analyseprovider die op geschikte Macs met macOS 26 of later lokaal beschikbaar is. CommissieWijzer verstuurt je documenten niet naar een eigen server. De beschikbaarheid en de verwerking van Apple Intelligence zijn afhankelijk van de Mac, systeemversie, taal en Apple-instellingen.

## ChatGPT en OpenAI

ChatGPT is optioneel en werkt online. Je meldt je aan via OpenAI OAuth in je browser. De app vraagt OpenAI om de ChatGPT-toegang die nodig is voor directe modelaanvragen en modelbeschikbaarheid; deze app heeft geen OpenAI API-sleutelinstelling.

Tijdens aanmelding ontvangt de app je e-mailadres en OpenAI’s stabiele `sub`-accountidentifier uit het gecontroleerde ID-token. Een door de app gegenereerde vaste, willekeurige hostidentifier wordt met de OAuth-aanvraag meegestuurd. Bij heraanmelding kan de app een e-mailhint en bestaand ID-token als OpenAI-loginhints gebruiken. OAuth-tokens, accountgegevens, de clientidentificatie, scopes en vervaltijd worden in de macOS-sleutelhanger bewaard. De hostidentifier staat lokaal in appvoorkeuren.

Wanneer je ChatGPT als provider kiest en een analyse start, stuurt de app de daarvoor benodigde documenttekst of passages rechtstreeks naar OpenAI. Bij programmavergelijking gaat ook het programma dat je zelf kiest mee. De online woordenlijst kan daarnaast de opgehaalde openbare tekst en relevante documentcontext naar de gekozen AI-provider sturen voor de uitleg. Je ChatGPT-account, beschikbare modellen en gebruikslimieten zijn van toepassing. OpenAI’s voorwaarden en privacybeleid gelden voor gegevens die je daarheen stuurt; CommissieWijzer beheert die verwerking niet.

De app leest of importeert geen ChatGPT-gesprekken. Ze gebruikt een eigen aanvraag voor de gekozen taak. Afmelden verwijdert of trekt de lokaal opgeslagen tokens in, voor zover OpenAI de intrekking bevestigt. OpenAI kan eigen retentie- en veiligheidsprocessen toepassen; lokaal opslaan door CommissieWijzer betekent niet dat gegevens die naar OpenAI zijn gestuurd daar direct worden gewist.

Gebruik ChatGPT niet voor vertrouwelijke stukken als dat niet is toegestaan binnen jouw organisatie. Controleer je eigen regels voordat je online verwerking inschakelt.

## Externe woordenlijst

Je kunt voor een afkorting expliciet een online woordenlijst raadplegen. De app stuurt de zoekterm naar de Nederlandstalige Wikipedia API. De gevonden openbare bron wordt lokaal gecachet. Voor een AI-uitleg stuurt de app de term, beperkte documentcontext en gevonden bronpassages naar de op dat moment gekozen AI-provider. Als je ChatGPT gebruikt, is die uitleg online; als je Apple Intelligence kiest, verloopt de AI-uitleg via die provider. Zonder externe zoekopdracht blijft de lokale woordenlijst beschikbaar.

## Bewaartermijn en verwijderen

De app bewaart lokale gegevens totdat jij ze verwijdert of de bijbehorende appbestanden wist. Je kunt werkdocumenten en geëxporteerde pdf’s zelf beheren in Finder. Je kunt lokaal opgeslagen ChatGPT-toegang via Instellingen afmelden; appbestanden en werkdocumenten verwijder je zelf. Apple Intelligence-, Wikipedia- en OpenAI-gegevens vallen daarnaast onder de bewaartermijnen en voorwaarden van die diensten.

## App Privacy-vragenlijst

De onderstaande implementatiefeiten zijn bedoeld om de App Store-vragenlijst correct te beantwoorden. Dit is geen verklaring dat de vragenlijst al in App Store Connect is ingevuld of gepubliceerd. Controleer voor inzending of Apple’s definities voor de definitieve build dezelfde antwoorden vereisen.

| Gegevenstype | Voorbeeld in deze app | Doel | Tracking |
| --- | --- | --- | --- |
| E-mailadres | OpenAI-accountadres dat via OAuth wordt teruggegeven en lokaal wordt getoond/bewaard | Appfunctionaliteit: aanmelden en accountstatus | Nee |
| Gebruikers-ID | OpenAI `sub`-accountidentifier | Appfunctionaliteit: het aangemelde account herkennen | Nee |
| Apparaat-ID | App-specifieke willekeurige hostidentifier | Appfunctionaliteit: OAuth-clientcontext | Nee |
| Andere gebruikersinhoud | Documentfragmenten en een geselecteerd programma bij optionele ChatGPT-analyse | Appfunctionaliteit: de door de gebruiker gestarte analyse | Nee |

Deze gegevens worden niet gebruikt voor advertenties of tracking. De inhoud wordt alleen gedeeld met OpenAI wanneer je de ChatGPT-provider of online woordenlijst met die provider kiest. Diagnostische records blijven lokaal.

## Website

De productwebsite laadt geen externe lettertypen, advertentiepixels of analysetrackers. Een bezoek aan GitHub, Wikipedia, OpenAI of een andere gelinkte dienst valt onder het privacybeleid van die dienst.

## Vragen

Stel een privacyvraag via [GitHub Issues](https://github.com/SyntheticDiz/CommissieWijzer/issues). Plaats geen vertrouwelijke pdf’s, persoonsgegevens, tokens, wachtwoorden of andere gevoelige informatie in een openbaar issue.
