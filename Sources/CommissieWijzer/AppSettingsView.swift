import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct AppSettingsView: View {
    #if os(iOS)
    @Environment(\.appPresentationContext) private var appPresentationContext
    #endif
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("uiLanguage") private var uiLanguage = "nl"
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("exportFolder") private var exportFolder = ""
    @State private var selectedSection: SettingsSection?
    @State private var isInitialPresentation = true
    @State private var showingPatchNotes = false
    @State private var showingTutorial = false
    @State private var showingLicenses = false
    @State private var showingCommitteeManager = false
    @State private var choosingFolder = false
    @State private var exportError: String?
    @State private var appleStatus = ""
    @ObservedObject private var completionNotifications: AnalysisCompletionNotifications
    @ObservedObject private var cloudSync: CloudSyncController
    @Bindable private var accentPalette = AccentPalette.shared

    private let refreshOnAppear: Bool
    private let partyProgramURL: URL

    @MainActor
    init(initialSection: SettingsSection? = nil,
         completionNotifications: AnalysisCompletionNotifications? = nil,
         cloudSync: CloudSyncController? = nil,
         refreshOnAppear: Bool = true,
         partyProgramURL: URL = PartyProgram.storageURL) {
        _selectedSection = State(initialValue: initialSection)
        self.completionNotifications = completionNotifications ?? .shared
        self.cloudSync = cloudSync ?? .shared
        self.refreshOnAppear = refreshOnAppear
        self.partyProgramURL = partyProgramURL
    }

    private func checkApple() {
        appleStatus = AppleAIService.unavailability() ?? "Beschikbaar · Nederlands ondersteund · Volledig lokaal"
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSidebar = geometry.size.width >= 660 && !dynamicTypeSize.isAccessibilitySize
            let activeSection = selectedSection ?? (usesSidebar ? .general : nil)
            VStack(spacing: 0) {
                header(showsBack: !usesSidebar && activeSection != nil)
                Divider()
                HStack(spacing: 0) {
                    if usesSidebar || activeSection == nil {
                        categoryList(usesSidebar: usesSidebar, activeSection: activeSection)
                            .frame(width: usesSidebar ? 214 : geometry.size.width)
                    }
                    if usesSidebar { Divider() }
                    detailPanes(activeSection: activeSection)
                        .frame(width: activeSection == nil ? 0 : nil)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                Divider()
                Text(localized("Keuzes worden automatisch bewaard."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.surface)
            }
            .background(AppTheme.background)
        }
        .platformReadingFrame(minWidth: 320, idealWidth: 820, minHeight: 400, idealHeight: 680)
        #if os(macOS)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        #else
        .preferredColorScheme(.dark)
        .presentationSizing(.page)
        #endif
        .sheet(isPresented: $showingPatchNotes) { PatchNotesView() }
        .sheet(isPresented: $showingTutorial) { TutorialView() }
        .sheet(isPresented: $showingLicenses) { ThirdPartyLicensesView() }
        .sheet(isPresented: $showingCommitteeManager) { CommitteeManagerView() }
        .task {
            checkApple()
            guard refreshOnAppear else { return }
            await completionNotifications.refreshAuthorization()
            await cloudSync.activateIfNeeded()
        }
        .onAppear { isInitialPresentation = false }
        .onChange(of: scenePhase) { _, phase in
            guard refreshOnAppear, phase == .active else { return }
            Task { await completionNotifications.refreshAuthorization() }
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            #if os(iOS)
            switch result {
            case .success(let url):
                do {
                    try iPadFileAccess.setPreferredExportDirectory(url)
                    exportFolder = url.path
                    exportError = nil
                } catch { exportError = error.localizedDescription }
            case .failure(let error):
                if !ImportFailure.isCancellation(error) { exportError = error.localizedDescription }
            }
            #else
            let choice = ExportFolderChoice.applying(result, currentPath: exportFolder)
            exportFolder = choice.path
            exportError = choice.message
            #endif
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private func header(showsBack: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                if showsBack { backButton }
                headerTitle.fixedSize(horizontal: true, vertical: true)
                Spacer(minLength: 0)
                doneButton
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if showsBack { backButton }
                    Spacer(minLength: 0)
                    doneButton
                }
                headerTitle.fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
    }

    private var headerTitle: some View {
        Text(localized("Instellingen"))
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
    }

    private var backButton: some View {
        Button { selectSection(nil) } label: {
            Image(systemName: "chevron.backward")
        }
        .accessibilityLabel(localized("Terug"))
        .help(localized("Terug"))
        .accessibilityIdentifier("settings-back")
    }

    private var doneButton: some View {
        Button(localized("Gereed")) { dismiss() }
            .keyboardShortcut(.defaultAction)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("settings-done")
    }

    private func categoryList(usesSidebar: Bool, activeSection: SettingsSection?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    let isSelected = activeSection == section
                    Button { selectSection(section) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbol)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            Text(localized(section.title))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if !usesSidebar {
                                Image(systemName: "chevron.forward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(SettingsNavigationRowStyle(isSelected: isSelected))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("settings-section-\(section.rawValue)")
                }
            }
            .padding(usesSidebar ? 12 : 16)
        }
        .background(AppTheme.paneSurface)
    }

    private func detailPanes(activeSection: SettingsSection?) -> some View {
        // Retain each pane's scroll position and in-progress settings work while navigating.
        ZStack {
            ForEach(SettingsSection.allCases) { section in
                let isVisible = section == activeSection
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(localized(section.title))
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 2)
                        sectionContent(section)
                    }
                    .frame(maxWidth: 660, alignment: .leading)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .groupBoxStyle(SettingsGroupBoxStyle())
                .opacity(isVisible ? 1 : 0)
                // A presented settings sheet can inherit an animated transaction. Keep
                // its first pane layout immediate, then animate only explicit navigation.
                .transaction { transaction in
                    if isInitialPresentation {
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
                .disabled(!isVisible)
                .allowsHitTesting(isVisible)
                .accessibilityHidden(!isVisible)
            }
        }
    }

    private func selectSection(_ section: SettingsSection?) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            selectedSection = section
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .general:
            interfaceSettings
            notificationSettings
        case .ai:
            ChatGPTSettingsView(refreshOnAppear: refreshOnAppear)
            appleSettings
        case .preparation:
            committeeSettings
            PartyProgramSettings(storageURL: partyProgramURL)
        case .storage:
            CloudSyncSettingsView(cloud: cloudSync)
            exportSettings
        case .help:
            helpSettings
        }
    }

    private func localized(_ value: String) -> String {
        UIStrings.text(value, language: uiLanguage)
    }

    private var interfaceSettings: some View {
        SettingsCard(localized("Taal en weergave"), systemImage: "circle.lefthalf.filled") {
            SettingsMenuPicker(localized("Taal van de interface"), selection: $uiLanguage,
                               selectedTitle: localized(uiLanguage == "nl" ? "Nederlands" : "English")) {
                Text(localized("Nederlands")).tag("nl")
                Text(localized("English")).tag("en")
            }
            Text(localized("Alleen de bediening verandert van taal. Samenvattingen, aandachtspunten en AI-antwoorden blijven Nederlands."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            #if os(macOS)
            SettingsMenuPicker(localized("Weergave"), selection: $appearance,
                               selectedTitle: localized(appearance == "light" ? "Lichte modus" : appearance == "dark" ? "Donkere modus" : "Systeeminstelling")) {
                Text(localized("Systeeminstelling")).tag("system")
                Text(localized("Lichte modus")).tag("light")
                Text(localized("Donkere modus")).tag("dark")
            }
            #else
            Text(localized("Weergave"))
                .font(.callout.weight(.medium))
            Text(localized("Donkere modus"))
                .font(.callout)
                .foregroundStyle(.secondary)
            #endif

            Divider()
            accentSettings
        }
    }

    private var accentSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("Accentkleur"))
                .font(.callout.weight(.medium))
            ForEach(AccentPreset.allCases) { preset in
                let isSelected = accentPalette.selected == preset
                Button {
                    accentPalette.selected = preset
                } label: {
                    HStack(spacing: 10) {
                        let swatchRGB = colorScheme == .dark ? preset.darkAccentRGB : preset.lightAccentRGB
                        Circle()
                            .fill(Color(red: swatchRGB.red, green: swatchRGB.green, blue: swatchRGB.blue))
                            .frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
                            .accessibilityHidden(true)
                        Text(localized(preset.title))
                        Spacer(minLength: 8)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(localized("Accentkleur")): \(localized(preset.title))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("accent-preset-\(preset.rawValue)")
            }
            Text(localized("De accentkleur past knoppen, focus en selecties aan."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notificationSettings: some View {
        SettingsCard(localized("Meldingen"), systemImage: "bell.badge") {
            Toggle(isOn: Binding(
                get: { completionNotifications.isEnabled },
                set: { enabled in
                    Task {
                        await completionNotifications.setEnabled(enabled)
                        await completionNotifications.refreshAuthorization()
                    }
                }
            )) {
                Text(localized("Melding als analyse klaar is"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .platformCheckboxStyle()

            Text(localized("Lokale melding zodra de documentanalyse is afgerond. Documentinhoud wordt niet in de melding getoond."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            #if os(iOS)
            Text(localized("iPadOS kan een analyse op de achtergrond pauzeren. De melding volgt zodra de analyse daadwerkelijk is afgerond."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            #endif

            if let status = completionNotifications.statusMessage {
                Text(localized(status))
                    .font(.caption)
                    .foregroundStyle(completionNotifications.authorizationStatus == .denied ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if completionNotifications.authorizationStatus == .notDetermined {
                Button(localized("Sta meldingen toe"), systemImage: "bell.badge") {
                    Task {
                        await completionNotifications.setEnabled(true)
                        await completionNotifications.refreshAuthorization()
                    }
                }
            }
        }
    }

    private var appleSettings: some View {
        SettingsCard(localized("Apple Intelligence op deze Mac"), systemImage: "sparkles") {
            Text(localized(appleStatus))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(localized("Bij Apple Intelligence blijft de AI-verwerking op deze Mac. Deze provider vereist een beschikbaar lokaal model. Lange documenten worden in delen verwerkt."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(localized("Controleer beschikbaarheid")) { checkApple() }
        }
    }

    private var committeeSettings: some View {
        SettingsCard(localized("Commissies"), systemImage: "person.3") {
            Text(localized("Pas commissieonderwerpen aan of maak een eigen profiel. Bestaande werkdocumenten behouden hun opgeslagen profiel."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(localized("Commissies beheren"), systemImage: "person.3") {
                showingCommitteeManager = true
            }
        }
    }

    private var exportSettings: some View {
        SettingsCard(localized("Standaardmap voor exports"), systemImage: "folder") {
            Text(exportFolder.isEmpty ? localized("Geen vaste map ingesteld") : exportFolder)
                .font(.callout)
                .lineLimit(3)
                .truncationMode(.middle)
            Text(localized("Het exportvenster opent in deze map. Je kunt daar nog een andere locatie kiezen."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    chooseExportFolder.fixedSize()
                    clearExportFolder.fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    chooseExportFolder
                    clearExportFolder
                }
            }
            if let exportError {
                Text(localized(exportError))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var chooseExportFolder: some View {
        Button(localized("Kies map…")) {
            #if os(iOS)
            iPadFileAccess.chooseExportDirectory(context: appPresentationContext) { result in
                switch result {
                case .success(let url):
                    exportFolder = url?.path ?? ""
                    exportError = nil
                case .failure(let error) where ImportFailure.isCancellation(error): break
                case .failure(let error): exportError = error.localizedDescription
                }
            }
            #else
            choosingFolder = true
            #endif
        }
    }

    private var clearExportFolder: some View {
        Button(localized("Wis mapkeuze")) {
            #if os(iOS)
            do {
                try iPadFileAccess.setPreferredExportDirectory(nil)
                exportFolder = ""
            } catch { exportError = error.localizedDescription }
            #else
            exportFolder = ""
            #endif
        }
        .disabled(exportFolder.isEmpty)
    }

    private var helpSettings: some View {
        SettingsCard(localized("CommissieWijzer · ") + PatchNotesView.version, systemImage: "doc.text") {
            Button(localized("Zo werkt CommissieWijzer"), systemImage: "questionmark.circle") { showingTutorial = true }
            Button(localized("Versiegeschiedenis"), systemImage: "text.badge.star") { showingPatchNotes = true }
            Button(localized("Opensourcelicenties"), systemImage: "doc.text") { showingLicenses = true }
        }
    }
}
