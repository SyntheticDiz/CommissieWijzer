import SwiftUI
import UniformTypeIdentifiers

struct AppSettingsView: View {
#if os(iOS)
    @Environment(\.appPresentationContext) private var appPresentationContext
#endif
    @AppStorage("uiLanguage") private var uiLanguage = "nl"
    @Environment(\.dismiss) private var dismiss
    @State private var showingPatchNotes = false
    @State private var showingTutorial = false
    @State private var showingLicenses = false
    @State private var message = ""
    @State private var failed = false
    @State private var choosingFolder = false
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("exportFolder") private var exportFolder = ""

    @State private var appleStatus = ""

    private func checkApple() { appleStatus = AppleAIService.unavailability() ?? "Beschikbaar · Nederlands ondersteund · Volledig lokaal" }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text(UIStrings.text("Instellingen")).font(.largeTitle.bold())
            #if os(macOS)
            HStack {
                Text(UIStrings.text("CommissieWijzer · ") + PatchNotesView.version).foregroundStyle(.secondary)
                Spacer()
                Button(UIStrings.text("Zo werkt CommissieWijzer"), systemImage: "questionmark.circle") { showingTutorial = true }
                Button(UIStrings.text("Versiegeschiedenis"), systemImage: "text.badge.star") { showingPatchNotes = true }
            }
            #else
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(UIStrings.text("CommissieWijzer · ") + PatchNotesView.version).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button(UIStrings.text("Zo werkt CommissieWijzer"), systemImage: "questionmark.circle") { showingTutorial = true }
                    Button(UIStrings.text("Versiegeschiedenis"), systemImage: "text.badge.star") { showingPatchNotes = true }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(UIStrings.text("CommissieWijzer · ") + PatchNotesView.version).foregroundStyle(.secondary)
                    Button(UIStrings.text("Zo werkt CommissieWijzer"), systemImage: "questionmark.circle") { showingTutorial = true }
                    Button(UIStrings.text("Versiegeschiedenis"), systemImage: "text.badge.star") { showingPatchNotes = true }
                }
            }
            #endif
            Button(UIStrings.text("Opensourcelicenties"), systemImage: "doc.text") { showingLicenses = true }
                .font(.callout)
            FocusMenuPicker(UIStrings.text("Taal van de interface"), selection: $uiLanguage,
                            selectedTitle: UIStrings.text(uiLanguage == "nl" ? "Nederlands" : "English")) {
                Text(UIStrings.text("Nederlands")).tag("nl")
                Text(UIStrings.text("English")).tag("en")
            }
            Text(UIStrings.text("Alleen de bediening verandert van taal. Samenvattingen, aandachtspunten en AI-antwoorden blijven Nederlands.")).font(.caption).foregroundStyle(.secondary)
            ChatGPTSettingsView()
            Label(UIStrings.text("Apple Intelligence"), systemImage: "sparkles").font(.headline)
            GroupBox(UIStrings.text("Apple Intelligence op deze Mac")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(UIStrings.text(appleStatus))
                    Button(UIStrings.text("Controleer beschikbaarheid")) { checkApple() }
                    Text(UIStrings.text("Bij Apple Intelligence blijft de AI-verwerking op deze Mac. Deze provider vereist een beschikbaar lokaal model. Lange documenten worden in delen verwerkt."))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            Divider()
            Label(UIStrings.text("Analyse"), systemImage: "slider.horizontal.3").font(.headline)
            PartyProgramSettings()
            Divider()
            Label(UIStrings.text("Weergave"), systemImage: "circle.lefthalf.filled").font(.headline)
            #if os(macOS)
            FocusMenuPicker(UIStrings.text("Weergave"), selection: $appearance,
                            selectedTitle: UIStrings.text(appearance == "light" ? "Lichte modus" : appearance == "dark" ? "Donkere modus" : "Systeeminstelling")) {
                Text(UIStrings.text("Systeeminstelling")).tag("system")
                Text(UIStrings.text("Lichte modus")).tag("light")
                Text(UIStrings.text("Donkere modus")).tag("dark")
            }
            #else
            Text(UIStrings.text("Donkere modus")).foregroundStyle(.secondary)
            #endif
            Divider()
            Label(UIStrings.text("Export"), systemImage: "square.and.arrow.up").font(.headline)
            GroupBox(UIStrings.text("Standaardmap voor exports")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(UIStrings.text(exportFolder.isEmpty ? "Geen vaste map ingesteld" : exportFolder))
                        .font(.callout).lineLimit(3).truncationMode(.middle)
                    HStack {
                        Button(UIStrings.text("Kies map…")) {
#if os(iOS)
                            iPadFileAccess.chooseExportDirectory(context: appPresentationContext) { result in
                                switch result {
                                case .success(let url):
                                    exportFolder = url?.path ?? ""; message = ""; failed = false
                                case .failure(let error) where ImportFailure.isCancellation(error): break
                                case .failure(let error): message = error.localizedDescription; failed = true
                                }
                            }
#else
                            choosingFolder = true
#endif
                        }
                        Button(UIStrings.text("Wis mapkeuze")) {
                            #if os(iOS)
                            do { try iPadFileAccess.setPreferredExportDirectory(nil); exportFolder = "" }
                            catch { message = error.localizedDescription; failed = true }
                            #else
                            exportFolder = ""
                            #endif
                        }.disabled(exportFolder.isEmpty)
                    }
                    Text(UIStrings.text("Het exportvenster opent in deze map. Je kunt daar nog een andere locatie kiezen."))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            if failed { Text(UIStrings.text(message)).foregroundStyle(.red) }
            HStack {
                Text(UIStrings.text("Keuzes worden automatisch bewaard."))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(UIStrings.text("Gereed")) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        }.platformReadingFrame(minWidth: 540, idealWidth: 600, minHeight: 500, idealHeight: 720)
        #if os(macOS)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        #else
        .preferredColorScheme(.dark)
        #endif
        .sheet(isPresented: $showingPatchNotes) { PatchNotesView() }
        .sheet(isPresented: $showingTutorial) { TutorialView() }
        .sheet(isPresented: $showingLicenses) { ThirdPartyLicensesView() }
        .task { checkApple() }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            #if os(iOS)
            switch result {
            case .success(let url):
                do {
                    try iPadFileAccess.setPreferredExportDirectory(url)
                    exportFolder = url.path; message = ""; failed = false
                } catch { message = error.localizedDescription; failed = true }
            case .failure(let error):
                if !ImportFailure.isCancellation(error) { message = error.localizedDescription; failed = true }
            }
            #else
            let choice = ExportFolderChoice.applying(result, currentPath: exportFolder)
            exportFolder = choice.path
            message = choice.message ?? ""
            failed = choice.message != nil
            #endif
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }
}
