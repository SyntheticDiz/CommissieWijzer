import SwiftUI

struct CloudLibraryView: View {
    @ObservedObject var cloud: CloudSyncController
    var open: (CloudDossier, CloudCheckout) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var opening: UUID?
    @State private var localError: String?
    @State private var committeeVersion: CloudCommitteeVersion?

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(UIStrings.text("iCloud-dossiers"))
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer()
                Button { Task { await cloud.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 44, height: 44)
                }
                    .accessibilityLabel(UIStrings.text("Ververs"))
                    .disabled(!cloud.enabled || cloud.busy)
            }
            Text(UIStrings.text("Kies een dossier om de beschikbare versie te openen. Openen start geen nieuwe analyse."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let message = cloud.error ?? localError { Text(UIStrings.text(message)).foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true) }
            if cloud.dossiers.isEmpty && cloud.committeeVersions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "icloud").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(UIStrings.text("Geen iCloud-dossiers")).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(UIStrings.text(cloud.busy ? "Bibliotheek wordt bijgewerkt…" : "Dossiers verschijnen hier nadat je ze expliciet synchroniseert."))
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(cloud.dossiers) { dossier in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dossier.title).font(.headline).lineLimit(2)
                            Spacer()
                            if dossier.isConflict { Label(UIStrings.text("Conflict"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                        }
                        HStack(spacing: 8) {
                            Text(dossier.hasLocalChanges ? UIStrings.text("Wacht op synchronisatie") : "\(UIStrings.text("Bijgewerkt")) \(dossier.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                            if dossier.isDownloaded { Text("· \(UIStrings.text("lokaal beschikbaar"))") }
                        }.font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button(UIStrings.text("Open versie"), systemImage: "doc.text.magnifyingglass") {
                                opening = dossier.id
                                Task {
                                    do { let checkout = try await cloud.checkout(id: dossier.id); open(dossier, checkout); dismiss() }
                                    catch { localError = error.localizedDescription }
                                    opening = nil
                                }
                            }.disabled(opening != nil || cloud.busy)
                        }.buttonStyle(.bordered)
                    }.padding(.vertical, 5)
                    Divider()
                }
            if cloud.committeeSyncEnabled, !cloud.committeeVersions.isEmpty {
                Divider()
                Text(UIStrings.text("Bewaarde commissielijsten")).font(.headline)
                ForEach(cloud.committeeVersions) { version in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(version.committees.count) \(UIStrings.text("commissies"))")
                            Text(version.modifiedAt.formatted(date: .abbreviated, time: .shortened) + (version.isConflict ? " · \(UIStrings.text("Conflict"))" : ""))
                                .font(.caption).foregroundStyle(version.isConflict ? .orange : .secondary)
                        }
                        Spacer()
                        Button(UIStrings.text("Toepassen")) { committeeVersion = version }
                    }
                }
            }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                if !cloud.status.isEmpty { Text(UIStrings.text(cloud.status)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                HStack { Spacer(); Button(UIStrings.text("Gereed")) { dismiss() }.keyboardShortcut(.defaultAction) }
            }
        }.padding(24).frame(maxWidth: .infinity)
        }.frame(minHeight: 360)
            .task { await cloud.loadLocalLibrary() }
            .alert(UIStrings.text("Commissielijst toepassen?"), isPresented: Binding(
                get: { committeeVersion != nil }, set: { if !$0 { committeeVersion = nil } }
            )) {
                Button(UIStrings.text("Toepassen")) {
                    guard let committeeVersion else { return }
                    do { try cloud.applyCommitteeVersion(committeeVersion) }
                    catch { localError = error.localizedDescription }
                    self.committeeVersion = nil
                }
                Button(UIStrings.text("Annuleer"), role: .cancel) { committeeVersion = nil }
            } message: {
                Text(UIStrings.text("De gekozen definities worden aan je lokale commissielijst toegevoegd of bijgewerkt. Bestaande werkdocumenten en bewaarde analyses blijven behouden."))
            }
    }
}
