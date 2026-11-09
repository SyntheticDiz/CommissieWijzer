import SwiftUI

struct CloudSyncSettingsView: View {
    @ObservedObject var cloud: CloudSyncController
    var body: some View {
        SettingsCard(UIStrings.text("Persoonlijke iCloud-synchronisatie"), systemImage: "icloud") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { cloud.enabled }, set: { value in Task { await cloud.setEnabled(value) } }
                )) { Text(UIStrings.text("Synchroniseer gekozen dossiers via iCloud")).fixedSize(horizontal: false, vertical: true) }.platformCheckboxStyle()
                Text(UIStrings.text("Staat standaard uit. Je kiest per dossier of je het synchroniseert. De pdf, bewaarde analyse, selectie, notities en leespositie worden naar je eigen iCloud-account geüpload. De app bewaart ook een lokale kopie; uitzetten stopt toekomstige synchronisatie maar verwijdert bestaande iCloud-kopieën niet. Offline dossiers blijven lokaal leesbaar."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if cloud.enabled {
                    Toggle(isOn: Binding(
                        get: { cloud.committeeSyncEnabled }, set: { value in Task { await cloud.setCommitteeSyncEnabled(value) } }
                    )) { Text(UIStrings.text("Synchroniseer ook mijn commissielijst")).fixedSize(horizontal: false, vertical: true) }.platformCheckboxStyle()
                    Text(UIStrings.text("Commissies worden als aparte versies bewaard. Een ontvangen versie wordt pas toegepast nadat je die kiest."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let error = cloud.error { Text(UIStrings.text(error)).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                if !cloud.status.isEmpty { Text(UIStrings.text(cloud.status)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
