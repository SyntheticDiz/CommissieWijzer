import SwiftUI

@MainActor
struct CommitteeManagerView: View {
    let savedPurposes: [MeetingPurpose]
    @ObservedObject private var library = CommitteeLibrary.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editingPurpose: MeetingPurpose?
    @State private var showingNewForm = false
    @State private var deleteTarget: MeetingPurpose?
    @State private var message = ""

    init(savedPurposes: [MeetingPurpose] = []) {
        self.savedPurposes = savedPurposes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(UIStrings.text("Commissies beheren"))
                            .font(.largeTitle.bold())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        Button(UIStrings.text("Gereed")) { dismiss() }
                            .keyboardShortcut(.cancelAction)
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        Button(UIStrings.text("Gereed")) { dismiss() }
                            .keyboardShortcut(.cancelAction)
                        Text(UIStrings.text("Commissies beheren"))
                            .font(.largeTitle.bold())
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(UIStrings.text("Maak een eigen commissieprofiel of pas een voorbeeld aan. Wijzigingen gelden voor nieuwe analyses; bestaande werkdocumenten behouden hun opgeslagen profiel."))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(UIStrings.text("Nieuwe commissie"), systemImage: "plus") {
                    showingNewForm = true
                }
                .buttonStyle(FocusSecondaryButtonStyle())
                .disabled(!library.canEdit)

                if let loadError = library.loadErrorMessage {
                    Label(UIStrings.text(loadError), systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(.red)
                }

                if library.committees.isEmpty {
                    ContentUnavailableView(UIStrings.text("Nog geen commissieprofielen"),
                                           systemImage: "person.3",
                                           description: Text(UIStrings.text("Voeg een commissie toe om analyses op je eigen onderwerpen af te stemmen.")))
                } else {
                    VStack(spacing: 10) {
                        ForEach(library.committees, id: \.self) { purpose in
                            profileRow(purpose)
                        }
                    }
                }

                if !importableSavedPurposes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(UIStrings.text("Uit dit werkdocument")).font(.title3.bold())
                            Text(UIStrings.text("Deze profielen zijn in dit werkdocument opgeslagen. Bewaar een kopie in je eigen commissielijst om ze ook voor nieuwe documenten te gebruiken."))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(importableSavedPurposes, id: \.self) { purpose in
                            savedProfileRow(purpose)
                        }
                    }
                    .padding(.top, 8)
                }

                if !message.isEmpty {
                    Label(UIStrings.text(message), systemImage: "exclamationmark.circle.fill")
                        .font(.callout).foregroundStyle(.red)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .platformReadingFrame(minWidth: 540, idealWidth: 760, maxWidth: .infinity,
                              minHeight: 480, idealHeight: 720, maxHeight: .infinity)
        .sheet(isPresented: $showingNewForm) {
            CommitteeDefinitionEditor(title: "Nieuwe commissie", definition: nil, onSave: save)
        }
        .sheet(item: $editingPurpose) { purpose in
            CommitteeDefinitionEditor(title: "Commissie aanpassen", definition: purpose.editableDefinition, onSave: save)
        }
        .confirmationDialog(UIStrings.text("Commissie verwijderen?"), isPresented: deleteDialogBinding, titleVisibility: .visible) {
            Button(UIStrings.text("Verwijder commissie"), role: .destructive) {
                guard let purpose = deleteTarget else { return }
                library.remove(purpose)
                deleteTarget = nil
                if let loadError = library.loadErrorMessage { message = loadError }
            }
            Button(UIStrings.text("Annuleer"), role: .cancel) { deleteTarget = nil }
        } message: {
            Text(UIStrings.text("Dit verwijdert alleen het profiel uit de lijst. Bestaande werkdocumenten en daarin opgeslagen analyses blijven behouden."))
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private func profileRow(_ purpose: MeetingPurpose) -> some View {
        VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            profileInfo(purpose)
                            Spacer(minLength: 8)
                            profileActions(purpose)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            profileInfo(purpose)
                            profileActions(purpose)
                        }
                    }
            if !purpose.boundaries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(purpose.boundaries).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .readingSurface()
    }

    private func savedProfileRow(_ purpose: MeetingPurpose) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(purpose.title).font(.headline)
            Text(purpose.topics.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(3)
            if !purpose.boundaries.isEmpty {
                Text(purpose.boundaries).font(.caption).foregroundStyle(.secondary)
            }
            Button(UIStrings.text("Bewaar in mijn commissies"), systemImage: "square.and.arrow.down") {
                do {
                    try library.save(purpose.editableDefinition)
                    message = ""
                } catch {
                    message = error.localizedDescription
                }
            }
            .buttonStyle(FocusSecondaryButtonStyle())
            .disabled(!library.canEdit)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .readingSurface()
    }

    private var importableSavedPurposes: [MeetingPurpose] {
        let localIDs = Set(library.committees.map(\.profileID))
        var snapshotsByProfileID: [String: MeetingPurpose] = [:]
        for purpose in savedPurposes where purpose.committee != nil && !localIDs.contains(purpose.profileID) {
            snapshotsByProfileID[purpose.profileID] = purpose
        }
        return snapshotsByProfileID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @ViewBuilder private func profileInfo(_ purpose: MeetingPurpose) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(purposeTitle(purpose)).font(.headline)
            Text(purpose.topics.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileActions(_ purpose: MeetingPurpose) -> some View {
        HStack(spacing: 10) {
            Button(UIStrings.text("Wijzig"), systemImage: "pencil") { editingPurpose = purpose }
                .labelStyle(.titleAndIcon)
                .accessibilityLabel(UIStrings.text("Wijzig commissie: \(purpose.title)"))
                .disabled(!library.canEdit)
            Button(role: .destructive) { deleteTarget = purpose } label: {
                Label(UIStrings.text("Verwijder"), systemImage: "trash")
            }
            .accessibilityLabel(UIStrings.text("Verwijder commissie: \(purpose.title)"))
            .disabled(!library.canEdit)
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    private func save(_ definition: CommitteeDefinition) -> String? {
        do {
            try library.save(definition)
            message = ""
            showingNewForm = false
            editingPurpose = nil
            return nil
        } catch {
            message = error.localizedDescription
            return error.localizedDescription
        }
    }

    private func purposeTitle(_ purpose: MeetingPurpose) -> String {
        guard purpose.committee == nil else { return purpose.title }
        return UIStrings.text(purpose.title)
    }
}

struct CommitteeDefinitionEditor: View {
    let title: String
    let definition: CommitteeDefinition?
    let onSave: (CommitteeDefinition) -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var topicsText = ""
    @State private var attention = ""
    @State private var validationMessage = ""

    init(title: String, definition: CommitteeDefinition?, onSave: @escaping (CommitteeDefinition) -> String?) {
        self.title = title
        self.definition = definition
        self.onSave = onSave
    }

    var body: some View {
        Group {
            #if os(macOS)
            macEditor
            #else
            ipadEditor
            #endif
        }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            guard let definition else { return }
            name = definition.name
            topicsText = definition.topics.joined(separator: "\n")
            attention = definition.attention
        }
    }

    #if os(macOS)
    private var macEditor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(UIStrings.text(title)).font(.title2.bold())
                    Text(UIStrings.text("Vul naam, onderwerpen en eventueel extra aandacht in."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 18)

            if !validationMessage.isEmpty {
                Label(UIStrings.text(validationMessage), systemImage: "exclamationmark.circle.fill")
                    .font(.callout).foregroundStyle(.red)
                    .padding(.bottom, 14)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(UIStrings.text("Naam")).font(.headline)
                        TextField(UIStrings.text("Bijvoorbeeld: Wonen en Zorg"), text: $name)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.75), lineWidth: 1))
                            .accessibilityLabel(UIStrings.text("Naam"))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(UIStrings.text("Onderwerpen")).font(.headline)
                        TextEditor(text: $topicsText)
                            .scrollContentBackground(.hidden)
                            .frame(height: 130)
                            .padding(8)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.75), lineWidth: 1))
                            .accessibilityLabel(UIStrings.text("Onderwerpen"))
                        Text(UIStrings.text("Vul één onderwerp per regel in. Komma’s mogen ook als scheidingsteken."))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(UIStrings.text("Extra aandacht (optioneel)")).font(.headline)
                        TextEditor(text: $attention)
                            .scrollContentBackground(.hidden)
                            .frame(height: 95)
                            .padding(8)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.75), lineWidth: 1))
                            .accessibilityLabel(UIStrings.text("Extra aandacht"))
                        Text(UIStrings.text("Beschrijf afbakeningen of onderwerpen die extra aandacht verdienen."))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Label {
                        Text(UIStrings.text("Profielen worden lokaal bewaard. Bij analyse met ChatGPT worden de profielnaam, onderwerpen en extra aandacht samen met documentcontext naar OpenAI verstuurd."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.55), lineWidth: 1))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().padding(.top, 16).padding(.bottom, 12)
            HStack(spacing: 10) {
                Spacer()
                Button(UIStrings.text("Annuleer")) { dismiss() }
                    .buttonStyle(FocusSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(UIStrings.text("Bewaar"), systemImage: "checkmark", action: submit)
                    .buttonStyle(FocusPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .background(AppTheme.background)
        .platformReadingFrame(minWidth: 540, idealWidth: 620, maxWidth: .infinity,
                              minHeight: 620, idealHeight: 680, maxHeight: .infinity)
    }
    #endif

    #if os(iOS)
    private var ipadEditor: some View {
        NavigationStack {
            Form {
                Section(UIStrings.text("Naam")) {
                    TextField(UIStrings.text("Bijvoorbeeld: Wonen en Zorg"), text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    TextEditor(text: $topicsText)
                        .frame(minHeight: 130)
                        .accessibilityLabel(UIStrings.text("Onderwerpen"))
                    Text(UIStrings.text("Vul één onderwerp per regel in. Komma’s mogen ook als scheidingsteken."))
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text(UIStrings.text("Onderwerpen"))
                }
                Section {
                    TextEditor(text: $attention)
                        .frame(minHeight: 95)
                        .accessibilityLabel(UIStrings.text("Extra aandacht"))
                } header: {
                    Text(UIStrings.text("Extra aandacht (optioneel)"))
                } footer: {
                    Text(UIStrings.text("Beschrijf afbakeningen of onderwerpen die extra aandacht verdienen."))
                }
                Section {
                    Text(UIStrings.text("Profielen worden lokaal bewaard. Bij analyse met ChatGPT worden de profielnaam, onderwerpen en extra aandacht samen met documentcontext naar OpenAI verstuurd."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !validationMessage.isEmpty {
                    Text(UIStrings.text(validationMessage)).foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(UIStrings.text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(UIStrings.text("Annuleer")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(UIStrings.text("Bewaar"), action: submit)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(maxWidth: 620)
        .background(AppTheme.background)
        .platformReadingFrame(minWidth: 420, idealWidth: 620, maxWidth: .infinity,
                              minHeight: 420, idealHeight: 620, maxHeight: .infinity)
    }
    #endif

    private func submit() {
        let topics = topicsText
            .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidate = CommitteeDefinition(
            id: definition?.id ?? UUID().uuidString,
            revision: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            topics: topics,
            attention: attention.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try candidate.validate()
            validationMessage = ""
            if let failure = onSave(candidate) {
                validationMessage = failure
            } else {
                validationMessage = ""
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
