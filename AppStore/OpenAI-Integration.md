# OpenAI-integratie en aanvraagstatus

Laatst bijgewerkt: 8 november 2026. Deze pagina beschrijft de implementatie en de laatst bekende status van de commerciële aanvraag. De status is gebaseerd op de ontvangst van 7 november; bij deze vastlegging was geen latere reactie bekend.

## Huidige appintegratie

CommissieWijzer is een zelfstandige macOS- en iPadOS-app van een onafhankelijke ontwikkelaar zonder bedrijf. De gebruiker kan optioneel aanmelden met een ChatGPT-account en ChatGPT kiezen als analyseprovider; de app gebruikt daarvoor de OpenAI Responses API. De accountaanmelding loopt via de dynamische agentclient; de app gebruikt `ChatGPTAccount.swift` en `ChatGPTService.swift`. Hiervoor is geen API-sleutelveld in de app. Bij een gekozen analyse worden benodigde documentfragmenten en, indien van toepassing, het geselecteerde partijprogramma naar OpenAI verzonden. De app leest geen ChatGPT-gesprekken. De overige appfuncties omvatten eigen commissies, analysemeldingen en een optionele private iCloud-bibliotheek; die functies zijn niet afhankelijk van deze commerciële aanvraag.

De aangevraagde commerciële opzet gaat uit van gebruikers met een eigen geschikt betaald ChatGPT-abonnement. De daadwerkelijke toegang volgt de accountrechten en gebruikslimieten van OpenAI. Abonnementskosten voor gebruikers staan los van eventuele kosten voor de ontwikkelaar; de commerciële voorwaarden moeten nog door OpenAI worden bevestigd.

## Aanvraag en open vragen

Op 7 november 2026 is het interesseformulier voor Sign in with ChatGPT ingediend via [OpenAI’s formulier](https://openai.com/form/sign-in-with-chatgpt-interest/). De ontvangst meldt dat de aanvraag is ontvangen en dat OpenAI contact opneemt als het product bij het programma past. Op 8 november was er geen partnergoedkeuring, prijsopgave, contract of commerciële gebruikstoestemming vastgelegd.

De aanvraag beschrijft een mogelijk betaalde App Store-app voor Mac en iPad en vraagt OpenAI om schriftelijk te bevestigen:

- of een onafhankelijke ontwikkelaar zonder bedrijf en een betaalde open-source app-distributie voor dit programma in aanmerking kunnen komen;
- wat de juiste integratieroute is voor deze bestaande app en of de bestaande OAuth- en Responses API-integratie kan worden gebruikt;
- alle ontwikkelaarskosten: aanvraag, onboarding, licenties, terugkerende kosten, kosten per gebruiker of verzoek, tokenkosten, minimumafname of -commitment en revenue share;
- indien er geen ontwikkelaarskosten zijn, een expliciete schriftelijke bevestiging daarvan;
- welke voorwaarden of beperkingen gelden, en welke kosten rechtstreeks bij gebruikers blijven.

Er is geen betaald contract aanvaard. Beschikbaarheid van een werkende login of Apple-goedkeuring voor de app betekent niet dat OpenAI commerciële toestemming heeft verleend.

## Gepubliceerde OpenAI-documentatie

- [Token sharing voor open-source apps](https://developers.openai.com/siwc/token-sharing-open-source) beschrijft de gedocumenteerde route voor open-source en lokaal draaiende apps en verwijst betaalde of extern gehoste apps naar het interesseformulier.
- [Een client-ID aanvragen](https://developers.openai.com/siwc/request-client-id) beschrijft client-ID-aanvragen en verwijst naar selectie van commerciële partners.

Deze documentatie helpt de aanvraag te richten, maar beslist niet of CommissieWijzer voor betaalde Mac- en iPad-distributie in aanmerking komt. Die vraag, de juiste integratieroute en eventuele kosten blijven bij OpenAI ter bevestiging.
