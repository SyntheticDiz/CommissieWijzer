import SwiftUI

struct MeetingQuestionEditorRequest: Identifiable {
    var id: UUID { draft.id }
    let documentID: UUID
    let draft: MeetingQuestion
    let editingExisting: Bool
    var suggestions: [PassageQuestion] = []
}

struct MeetingPreparationView: View {
    @ObservedObject var workspace: SimpleWorkspace
    let documentID: UUID
    let pdf: Data
    var close: () -> Void
    var draftQuestion: (MeetingQuestionSource, [PassageQuestion]) -> Void
    var editQuestion: (MeetingQuestion) -> Void

    @State private var sourcePresentation: MeetingSourcePresentation?
    @State private var pendingRemoval: MeetingQuestion?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    questions
                }
                .frame(maxWidth: 850)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $sourcePresentation) { presentation in
            MeetingPDFSourceView(pdf: pdf, source: presentation.source)
        }
        .confirmationDialog(UIStrings.text("Vraag verwijderen?"), isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        ), titleVisibility: .visible, presenting: pendingRemoval) { question in
            Button(UIStrings.text("Verwijder vraag"), role: .destructive) {
                workspace.removeMeetingQuestion(id: question.id, expectedDocumentID: documentID)
            }
            Button(UIStrings.text("Annuleer"), role: .cancel) {}
        }
        .accessibilityIdentifier("meeting.questionList")
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                heading
                Spacer(minLength: 8)
                closeButton
            }
            VStack(alignment: .leading, spacing: 8) {
                heading
                closeButton
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heading: some View {
        Text(UIStrings.text("Vragenlijst")).font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var closeButton: some View {
        Button(UIStrings.text("Terug naar werkveld"), systemImage: "arrow.left", action: close)
            .buttonStyle(FocusSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
    }

    private var questions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.text("Goedgekeurde vragen"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if workspace.meetingQuestions.isEmpty {
                Text(UIStrings.text("Er staan nog geen goedgekeurde vragen op je lijst."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            questionSourceMenu
            Text(UIStrings.text("Kies een bron uit Mijn selectie of selecteer tekst in de PDF om een vraag op te stellen."))
                .font(.caption).foregroundStyle(.secondary)
            Text(UIStrings.text("Bewaar je vragen met het werkdocument."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(workspace.meetingQuestions) { question in
                questionRow(question)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var questionSourceMenu: some View {
        Menu {
            ForEach(workspace.chosenPassages) { passage in
                Button(passage.title.isEmpty ? UIStrings.text("Gekozen passage") : passage.title) {
                    draftQuestion(.init(passage: passage), [])
                }
            }
            ForEach(workspace.selectedInsightsInOrder) { point in
                Button(point.title) {
                    let suggestions = workspace.passageQuestions[SimpleWorkspace.selectionKey(point)] ?? []
                    draftQuestion(.init(point: point), suggestions)
                }
            }
        } label: {
            Label(UIStrings.text("Vraag opstellen"), systemImage: "plus")
        }
        .focusMenu()
        .disabled(!workspace.canEditMeetingQuestions || (workspace.chosenPassages.isEmpty && workspace.selectedInsightsInOrder.isEmpty))
    }

    private func questionRow(_ question: MeetingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.question).font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !question.answer.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UIStrings.text("Eigen antwoord")).font(.caption.weight(.semibold))
                    Text(question.answer).font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    statusMenu(question)
                    sourceButton(question.source)
                    editButton(question)
                }
                VStack(alignment: .leading, spacing: 6) {
                    statusMenu(question)
                    sourceButton(question.source)
                    editButton(question)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .readingSurface()
    }

    private func statusMenu(_ question: MeetingQuestion) -> some View {
        Menu {
            ForEach(MeetingQuestionStatus.allCases, id: \.self) { status in
                Button {
                    workspace.setMeetingQuestionStatus(status, id: question.id, expectedDocumentID: documentID)
                } label: {
                    if status == question.status { Label(UIStrings.text(status.title), systemImage: "checkmark") }
                    else { Text(UIStrings.text(status.title)) }
                }
            }
        } label: {
            Label(UIStrings.text(question.status.title), systemImage: statusSymbol(question.status))
        }
        .focusMenu()
        .accessibilityLabel(UIStrings.text("Vraagstatus"))
        .accessibilityValue(UIStrings.text(question.status.title))
        .disabled(!workspace.canEditMeetingQuestions)
    }

    private func editButton(_ question: MeetingQuestion) -> some View {
        Menu {
            Button(UIStrings.text("Wijzig vraag of antwoord"), systemImage: "pencil") { editQuestion(question) }
            Button(UIStrings.text("Verwijder vraag"), systemImage: "trash", role: .destructive) { pendingRemoval = question }
        } label: { Label(UIStrings.text("Meer"), systemImage: "ellipsis") }
        .focusMenu()
        .disabled(!workspace.canEditMeetingQuestions)
    }

    private func sourceButton(_ source: MeetingQuestionSource) -> some View {
        Button(UIStrings.text("Toon bron"), systemImage: "doc.text.magnifyingglass") {
            sourcePresentation = MeetingSourcePresentation(source: source)
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private func statusSymbol(_ status: MeetingQuestionStatus) -> String {
        switch status {
        case .toAsk: "questionmark.circle"
        case .answered: "checkmark.circle"
        case .followUp: "arrow.turn.down.right"
        }
    }
}

struct MeetingQuestionEditor: View {
    @Environment(\.dismiss) private var dismiss
    let request: MeetingQuestionEditorRequest
    let pdf: Data
    let save: (MeetingQuestion) -> Bool

    @State private var draft: MeetingQuestion
    @State private var sourcePresentation: MeetingSourcePresentation?
    @State private var saveFailed = false

    init(request: MeetingQuestionEditorRequest, pdf: Data, save: @escaping (MeetingQuestion) -> Bool) {
        self.request = request
        self.pdf = pdf
        self.save = save
        _draft = State(initialValue: request.draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(UIStrings.text(request.editingExisting ? "Vraag wijzigen" : "Vraag opstellen"))
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(UIStrings.text("Bron")).font(.headline)
                        Text(draft.source.title == "Gekozen passage" ? UIStrings.text("Gekozen passage") : draft.source.title).font(.callout)
                        Button(UIStrings.text("Toon bron"), systemImage: "doc.text.magnifyingglass") {
                            sourcePresentation = MeetingSourcePresentation(source: draft.source)
                        }
                        .buttonStyle(FocusSecondaryButtonStyle())
                    }
                    if !request.editingExisting && !request.suggestions.isEmpty {
                        DisclosureGroup(UIStrings.text("Bewaarde vraagsuggesties")) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(request.suggestions.enumerated()), id: \.offset) { _, suggestion in
                                    Button(suggestion.question) {
                                        draft = MeetingQuestion(id: draft.id, question: suggestion.question, answer: draft.answer,
                                            status: draft.status, source: request.draft.source.forSuggestion(quote: suggestion.quote))
                                    }
                                        .buttonStyle(FocusQuietActionStyle())
                                        .multilineTextAlignment(.leading)
                                }
                            }.padding(.top, 8)
                        }
                    }
                    editor("Vraag", text: $draft.question, height: 84)
                    editor("Eigen antwoord", text: $draft.answer, height: 96)
                    FocusMenuPicker(UIStrings.text("Vraagstatus"), selection: $draft.status,
                                    selectedTitle: UIStrings.text(draft.status.title)) {
                        ForEach(MeetingQuestionStatus.allCases, id: \.self) { status in
                            Text(UIStrings.text(status.title)).tag(status)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if saveFailed {
                Text(UIStrings.text("De vraag kon niet worden bewaard.")).font(.caption).foregroundStyle(.red)
            }
            ViewThatFits(in: .horizontal) {
                HStack { cancelButton; Spacer(minLength: 8); saveButton }
                VStack(alignment: .trailing, spacing: 8) { saveButton; cancelButton }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
        .platformSheetSize(width: 540, height: 560)
        .interactiveDismissDisabled(draft != request.draft)
        .sheet(item: $sourcePresentation) { presentation in
            MeetingPDFSourceView(pdf: pdf, source: presentation.source)
        }
        .accessibilityIdentifier("meeting.questionEditor")
    }

    private var cancelButton: some View {
        Button(UIStrings.text("Annuleer")) { dismiss() }
            .buttonStyle(FocusSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
    }

    private var saveButton: some View {
        Button(UIStrings.text(request.editingExisting ? "Bewaar" : "Goedkeuren en toevoegen")) {
            if save(draft) { dismiss() }
            else { saveFailed = true }
        }
        .buttonStyle(FocusPrimaryButtonStyle())
        .disabled(draft.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func editor(_ title: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(UIStrings.text(title)).font(.headline)
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Color.primary)
                .padding(8)
                .frame(height: height)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel(UIStrings.text(title))
        }
    }
}

private struct MeetingSourcePresentation: Identifiable {
    let id = UUID()
    let source: MeetingQuestionSource
}

private struct MeetingPDFSourceView: View {
    @Environment(\.dismiss) private var dismiss
    let pdf: Data
    let source: MeetingQuestionSource
    private let quotesForHighlight: [Int: String]
    private let excerptIsVerified: Bool
    @StateObject private var controls = PDFControls()
    @State private var selectedPage: Int
    @State private var navigationID = UUID()
    @State private var showingExcerpt = false

    init(pdf: Data, source: MeetingQuestionSource) {
        self.pdf = pdf
        self.source = source
        let verified = source.verify(inPDF: pdf)
        quotesForHighlight = verified.quotesForHighlight
        excerptIsVerified = verified.excerptIsVerified
        _selectedPage = State(initialValue: source.pages.first?.page ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack { heading; Spacer(minLength: 8); closeButton }
                VStack(alignment: .leading, spacing: 8) { heading; closeButton }
            }
            if source.pages.count > 1 {
                Picker(UIStrings.text("Bronpagina"), selection: $selectedPage) {
                    ForEach(source.pages, id: \.page) { entry in
                        Text(UIStrings.text("PDF-pagina \(entry.page)")).tag(entry.page)
                    }
                }.pickerStyle(.menu)
            } else {
                Text(UIStrings.text("PDF-pagina \(selectedPage)")).font(.caption).foregroundStyle(.secondary)
            }
            if quotesForHighlight[selectedPage] == nil {
                Text(UIStrings.text("Geen bevestigd citaat op deze pagina; controleer de PDF zelf."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !source.excerpt.isEmpty {
                let label = excerptIsVerified ? "Broncitaat" : "Bewaarde brontekst (niet bevestigd)"
                DisclosureGroup(UIStrings.text(label), isExpanded: $showingExcerpt) {
                    ScrollView { Text(source.excerpt).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 110)
                }
            }
            PDFPreview(data: pdf, page: selectedPage, navigationID: navigationID, controls: controls)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 140, maxHeight: .infinity)
            if !controls.highlightNotice.isEmpty {
                Text(UIStrings.text(controls.highlightNotice)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .platformSheetSize(width: 700, height: 640)
        .onAppear { showSourcePage() }
        .onChange(of: selectedPage) { _, _ in showSourcePage() }
        .accessibilityIdentifier("meeting.sourcePDF")
    }

    private var heading: some View {
        Text(UIStrings.text("Originele PDF")).font(.headline).accessibilityAddTraits(.isHeader)
    }

    private var closeButton: some View {
        Button(UIStrings.text("Gereed")) { dismiss() }
            .buttonStyle(FocusSecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
    }

    private func showSourcePage() {
        navigationID = UUID()
        guard let quote = quotesForHighlight[selectedPage] else {
            controls.resetHighlight()
            return
        }
        controls.pin(.init(id: "meeting-source-\(selectedPage)", page: selectedPage, quote: quote))
    }
}
