# CloudKit-schema

`schema.ckdb` beschrijft de CloudKit-recordtypen die de optionele persoonlijke synchronisatie gebruikt. `Dossier` bewaart de dossier-ID, titel, wijzigingsdatum, SHA-256-hash, archiefformaatversie en het volledige `.spdfwork`-archief als asset. `CommitteeVersion` bewaart afzonderlijke commissielijstversies als JSON-asset met dezelfde hash- en datumvelden.

De app schrijft deze records in de private database, in de custom zone `CommissieWijzerPersonal`. De nieuwe recordtypen hebben daarom geen openbare lees- of schrijfrechten. De bestaande `Users`-definitie is ongewijzigd overgenomen uit het huidige ontwikkelschema.

De transportcode leest alleen recordmetadata met `recordZoneChanges` en vraagt daarvoor expliciet de benodigde velden op. Die CloudKit-zonewijzigingen vereisen geen query-index. De PDF en andere archiefdata worden pas als asset opgehaald wanneer een dossier wordt geopend.

Het toevoegen of deployen van dit schema naar een CloudKit-container is bewust een aparte releasehandeling. Beperk schema-import en eventuele promotie tot de eigen container `iCloud.nl.commissiewijzer.app`; controleer het schema in de CloudKit Console en voer daarna nog een echte ontwikkelaccounttest uit voor zone-aanmaak, asset-upload, metadata-refresh, downloaden en conflictafhandeling. Deze bronbestanden voeren geen CloudKit-deployment of live synchronisatie uit.


Op 6 november 2026 is dit schema in de eigen container geïmporteerd en zijn uitsluitend de twee nieuwe recordtypen naar Production gedeployed; de bestaande Users-definitie en rollen zijn behouden. De ongewijzigde productietransportcode is daarna in Development op een geautoriseerde Mac live gecontroleerd met fictieve gegevens. Zone-aanmaak, metadata, dossier- en commissie-assets, update en bescherming tegen verouderde writes slagen. De ondertekende lokale Mac-app heeft daarna ook de persoonlijke Production-bibliotheek succesvol ververst. Dit bewijst geen fysieke Mac/iPad-overdracht of upload/download-rondgang in Production.

De eerdere lokale Mac-preview had geen iCloud-bevoegdheden. Voor lokaal gebruik met de Production-bibliotheek is een passend ondertekende `local-production`-build nodig, die na controle de bestaande `dist/CommissieWijzer.app` vervangt (geen extra gebruikersinstallatie); zie de [bouwinstructies](../../README.md#vereisten-en-bouwen). Een preview of simulator is geen vervanging voor een echte iCloud-test.

Versie 1.2.0 is op 6 november voor beide platforms ingediend. Op 7 november was de vastgelegde indieningsstatus Mac **1.2.0 (8)** en iPad **1.2.1 (9)**, beide **Waiting for Review**; de iPad-update verandert alleen versiemetadata en Store-beelden ten opzichte van de inmiddels vrijgegeven iPad 1.2.0. Dit is historische ontvangstinformatie, geen nieuwe controle van Apple. Zie [HANDOFF](../../HANDOFF.md) voor de releasevolgorde en resterende verificatiebeperkingen.
