# Privacybeleid — CommissieWijzer

Laatst bijgewerkt: 6 november 2026. Dit document beschrijft de Mac- en iPad-implementatie, inclusief eigen commissies in ontwikkelversie 1.1.2. De eerder ingediende builds worden hierdoor niet vervangen.

## In het kort

CommissieWijzer heeft geen eigen gebruikersaccount, backend, telemetrie, advertenties, analytics of tracking. Pdf’s, werkdocumenten, notities, voorkeuren, analysecache en diagnostische bestanden worden in lokale appopslag bewaard. Op iPad maakt de app bij openen een lokale werkkopie van een werkdocument. Bewaren via Bestanden maakt een afzonderlijke exportkopie; er is geen automatische synchronisatie. Je kiest zelf een locatie, eventueel bij een cloudprovider die je gebruikt. Een online provider of externe woordenlijst is optioneel; daarvoor wordt de benodigde inhoud rechtstreeks naar de betreffende dienst gestuurd.

## Lokaal op Mac en iPad

De app bewaart lokaal op beide platforms:

- de pdf die je opent en een werkdocument dat je zelf opslaat;
- de beschikbare analyse, bronverwijzingen, geselecteerde passages en notities;
- voorkeuren, eigen commissieprofielen (naam, onderwerpen en aandachtspunten) en lokale cachebestanden;
- begrensde diagnostiek voor ChatGPT-verbindingsproblemen, zoals de foutcategorie, HTTP-status, beperkte technische foutcodes, een OpenAI-request-ID, wachttijd en appversie.

De lokale ChatGPT-diagnostiek bewaart geen documentinhoud, prompts, antwoordtekst, tokens, wachtwoorden of volledige serverresponses. Op Mac staan appgegevens in lokale appopslag en kies je zelf waar werkdocumenten en exports worden opgeslagen. Op iPad staan appgegevens in lokale appopslag. Een geopend werkdocument wordt daar als lokale werkkopie bewaard; bewaren via Bestanden maakt een overdraagbare kopie op de locatie die jij kiest. Wijzigingen aan de werkkopie werken een eerdere export niet automatisch bij: exporteer opnieuw om de bijgewerkte versie over te zetten. CommissieWijzer synchroniseert of voegt werk tussen apparaten niet samen. Een gekozen cloudlocatie valt voor opslag en synchronisatie onder de betreffende provider.

## Lokale meldingen

Als je toestemming geeft, toont CommissieWijzer na een afgeronde analyse een lokale systeemmelding op Mac of iPad. De melding bevat geen documentnaam, documentinhoud, commissieomschrijving of accountgegevens. De app gebruikt hiervoor geen pushserver, tracking of extra gegevensoverdracht. Je kunt meldingen in de app uitschakelen; de toestemming en presentatie beheer je daarnaast via de meldingsinstellingen van het besturingssysteem.

## Apple Intelligence

Apple Intelligence is een optionele analyseprovider die lokaal beschikbaar is op geschikte Macs met macOS 26 of later en geschikte iPads met iPadOS 26 of later. CommissieWijzer verstuurt je documenten niet naar een eigen server. De beschikbaarheid en verwerking hangen af van het apparaat, de systeemversie, taal en Apple-instellingen.

## ChatGPT en OpenAI

ChatGPT is optioneel en werkt online. Je meldt je aan via OpenAI OAuth. Op Mac opent dit in je browser; op iPad gebruikt de app de systeem-Safariweergave binnen de app. De app vraagt OpenAI om de ChatGPT-toegang die nodig is voor directe modelaanvragen en modelbeschikbaarheid; deze app heeft geen OpenAI API-sleutelinstelling.

Tijdens aanmelding ontvangt de app je e-mailadres en OpenAI’s stabiele `sub`-accountidentifier uit het gecontroleerde ID-token. Een door de app gegenereerde vaste, willekeurige hostidentifier wordt met de OAuth-aanvraag meegestuurd. Bij heraanmelding kan de app een e-mailhint en bestaand ID-token als OpenAI-loginhints gebruiken. OAuth-tokens en accountgegevens worden in de lokale sleutelhanger bewaard: op Mac beschikbaar na de eerste ontgrendeling (`AfterFirstUnlock`) en op iPad alleen op dit apparaat beschikbaar wanneer het ontgrendeld is (`WhenUnlockedThisDeviceOnly`). De hostidentifier staat lokaal in appvoorkeuren.

Wanneer je ChatGPT als provider kiest en een analyse start, stuurt de app de daarvoor benodigde documenttekst of passages rechtstreeks naar OpenAI. Bij een commissieanalyse gaan de naam, onderwerpen en aanvullende aandachtspunten van het gekozen commissieprofiel mee; bij programmavergelijking ook het programma dat je zelf kiest. De online woordenlijst kan daarnaast de opgehaalde openbare tekst en relevante documentcontext naar de gekozen AI-provider sturen voor de uitleg. Je ChatGPT-account, beschikbare modellen en gebruikslimieten zijn van toepassing. OpenAI’s voorwaarden en privacybeleid gelden voor gegevens die je daarheen stuurt; CommissieWijzer beheert die verwerking niet.

De app leest of importeert geen ChatGPT-gesprekken. Ze gebruikt een eigen aanvraag voor de gekozen taak. Afmelden verwijdert of trekt de lokaal opgeslagen tokens in, voor zover OpenAI de intrekking bevestigt. OpenAI kan eigen retentie- en veiligheidsprocessen toepassen; lokaal opslaan door CommissieWijzer betekent niet dat gegevens die naar OpenAI zijn gestuurd daar direct worden gewist.

Gebruik ChatGPT niet voor vertrouwelijke stukken als dat niet is toegestaan binnen jouw organisatie. Controleer je eigen regels voordat je online verwerking inschakelt.

## Externe woordenlijst

Je kunt voor een afkorting expliciet een online woordenlijst raadplegen. De app stuurt de zoekterm naar de Nederlandstalige Wikipedia API. De gevonden openbare bron wordt lokaal gecachet. Voor een AI-uitleg stuurt de app de term, beperkte documentcontext en gevonden bronpassages naar de op dat moment gekozen AI-provider. Als je ChatGPT gebruikt, is die uitleg online; als je Apple Intelligence kiest, verloopt de AI-uitleg via die provider. Zonder externe zoekopdracht blijft de lokale woordenlijst beschikbaar.

## Bewaartermijn en verwijderen

De app bewaart lokale gegevens totdat jij ze verwijdert of de bijbehorende appbestanden wist. Je kunt werkdocumenten en geëxporteerde pdf’s zelf beheren in Finder op Mac of Bestanden op iPad. Je kunt lokaal opgeslagen ChatGPT-toegang via Instellingen afmelden; appbestanden en werkdocumenten verwijder je zelf. Apple Intelligence-, Wikipedia- en OpenAI-gegevens vallen daarnaast onder de bewaartermijnen en voorwaarden van die diensten.

## App Privacy-vragenlijst

Deze vier gegevenscategorieën staan in de gepubliceerde App Privacy-vragenlijst voor de Mac-versie. De iPad-versie is afzonderlijk ingediend en wacht op beoordeling door Apple.

| Gegevenstype | Voorbeeld in deze app | Doel | Tracking |
| --- | --- | --- | --- |
| E-mailadres | OpenAI-accountadres dat via OAuth wordt teruggegeven en lokaal wordt getoond/bewaard | Appfunctionaliteit: aanmelden en accountstatus | Nee |
| Gebruikers-ID | OpenAI `sub`-accountidentifier | Appfunctionaliteit: het aangemelde account herkennen | Nee |
| Apparaat-ID | App-specifieke willekeurige hostidentifier | Appfunctionaliteit: OAuth-clientcontext | Nee |
| Andere gebruikersinhoud | Documentfragmenten, het gekozen commissieprofiel en een geselecteerd programma bij optionele ChatGPT-analyse | Appfunctionaliteit: de door de gebruiker gestarte analyse | Nee |

Deze gegevens worden niet gebruikt voor advertenties of tracking. Documentinhoud wordt met OpenAI gedeeld wanneer je ChatGPT kiest voor analyse of uitleg. Diagnostische records blijven lokaal.

## Website

De productwebsite laadt geen externe lettertypen, advertentiepixels of analysetrackers. Een bezoek aan GitHub, Wikipedia, OpenAI of een andere gelinkte dienst valt onder het privacybeleid van die dienst.

## Vragen

Stel een privacyvraag via [GitHub Issues](https://github.com/SyntheticDiz/CommissieWijzer/issues). Plaats geen vertrouwelijke pdf’s, persoonsgegevens, tokens, wachtwoorden of andere gevoelige informatie in een openbaar issue.
