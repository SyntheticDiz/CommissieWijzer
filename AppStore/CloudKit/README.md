# CloudKit-schema

`schema.ckdb` beschrijft de CloudKit-recordtypen die de optionele persoonlijke synchronisatie gebruikt. `Dossier` bewaart de dossier-ID, titel, wijzigingsdatum, SHA-256-hash, archiefformaatversie en het volledige `.spdfwork`-archief als asset. `CommitteeVersion` bewaart afzonderlijke commissielijstversies als JSON-asset met dezelfde hash- en datumvelden.

De app schrijft deze records in de private database, in de custom zone `CommissieWijzerPersonal`. De nieuwe recordtypen hebben daarom geen openbare lees- of schrijfrechten. De bestaande `Users`-definitie is ongewijzigd overgenomen uit het huidige ontwikkelschema.

De transportcode leest alleen recordmetadata met `recordZoneChanges` en vraagt daarvoor expliciet de benodigde velden op. Die CloudKit-zonewijzigingen vereisen geen query-index. De PDF en andere archiefdata worden pas als asset opgehaald wanneer een dossier wordt geopend.

Het toevoegen of deployen van dit schema naar een CloudKit-container is bewust een aparte releasehandeling. Beperk schema-import en eventuele promotie tot de eigen container `iCloud.nl.commissiewijzer.app`; controleer het schema in de CloudKit Console en voer daarna nog een echte ontwikkelaccounttest uit voor zone-aanmaak, asset-upload, metadata-refresh, downloaden en conflictafhandeling. Deze bronbestanden voeren geen CloudKit-deployment of live synchronisatie uit.


Op 6 november 2026 is dit schema in de eigen container geïmporteerd en zijn uitsluitend de twee nieuwe recordtypen naar Production gedeployed; de bestaande Users-definitie en rollen zijn behouden. De ongewijzigde productietransportcode is daarna in Development op een geautoriseerde Mac live gecontroleerd met fictieve gegevens. Zone-aanmaak, metadata, dossier- en commissie-assets, update en bescherming tegen verouderde writes slagen. Dit bewijst geen fysieke Mac/iPad-overdracht of live Production-overdracht. Versie 1.2.0 is nog niet bij de Store ingediend.
