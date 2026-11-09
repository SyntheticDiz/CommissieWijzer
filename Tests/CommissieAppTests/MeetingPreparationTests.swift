import XCTest
import PDFKit
@testable import CommissieWijzer

@MainActor
final class MeetingPreparationTests: XCTestCase {
    private let firstPage = "De proef met buurtbussen start in september."
    private let secondPage = "De raad ontvangt in december de evaluatie."

    func testApprovedQuestionsRoundTripWithAllStatusesAndIndependentSources() throws {
        let legacy = try makeArchive()
        let workspace = SimpleWorkspace()
        try workspace.restore(legacy, persist: false)
        XCTAssertFalse(workspace.hasUnsavedChanges)
        XCTAssertTrue(workspace.meetingQuestions.isEmpty)
        XCTAssertEqual(workspace.passageQuestions, legacy.questions)

        let originalDocument = workspace.documentID
        let point = try XCTUnwrap(workspace.selectedInsightsInOrder.first)
        let chosen = try XCTUnwrap(workspace.chosenPassages.first)
        let toAsk = MeetingQuestion(question: "Wanneer begint de proef?", source: .init(point: point))
        let answered = MeetingQuestion(question: "Wie ontvangt de evaluatie?", source: .init(passage: chosen))
        let selection = SelectedPDFText(text: firstPage + "\n" + secondPage, pages: [1, 2],
            sources: [.init(page: 1, quote: firstPage), .init(page: 2, quote: secondPage)])
        let followUp = MeetingQuestion(question: "Wie volgt de proef op?", source: .init(selection: selection))
        XCTAssertTrue(workspace.saveMeetingQuestion(toAsk, expectedDocumentID: originalDocument))
        XCTAssertTrue(workspace.hasUnsavedChanges)
        XCTAssertTrue(workspace.saveMeetingQuestion(answered, expectedDocumentID: originalDocument))
        XCTAssertTrue(workspace.saveMeetingQuestion(followUp, expectedDocumentID: originalDocument))

        var edited = answered
        edited.question = "Welke instantie ontvangt de evaluatie?"
        edited.answer = "De gemeenteraad."
        edited.status = .answered
        XCTAssertTrue(workspace.saveMeetingQuestion(edited, expectedDocumentID: originalDocument))
        workspace.setMeetingQuestionStatus(.followUp, id: followUp.id, expectedDocumentID: originalDocument)
        var expectedFollowUp = followUp
        expectedFollowUp.status = .followUp
        XCTAssertEqual(workspace.meetingQuestions, [toAsk, edited, expectedFollowUp])

        workspace.chosenPassages = []
        workspace.starred = []
        workspace.insights = []
        let reopened = try roundTrip(workspace.archive(readingPage: 1))
        try workspace.restore(reopened, persist: false)

        XCTAssertEqual(reopened.formatVersion, 1)
        XCTAssertTrue(workspace.chosenPassages.isEmpty)
        XCTAssertTrue(workspace.selectedInsightsInOrder.isEmpty)
        XCTAssertEqual(workspace.meetingQuestions, [toAsk, edited, expectedFollowUp])
        XCTAssertEqual(workspace.meetingQuestions[2].source.pages, selection.sources)
        XCTAssertEqual(workspace.meetingQuestions[2].source.excerpt, selection.text)
        XCTAssertEqual(workspace.passageQuestions, legacy.questions)
        XCTAssertFalse(workspace.hasUnsavedChanges)

        let pdf = try XCTUnwrap(PDFDocument(data: reopened.pdf))
        for page in selection.sources {
            XCTAssertNotNil(PDFPassageLocator.selection(in: pdf, page: page.page, quote: page.quote))
        }

        workspace.setMeetingQuestionStatus(.answered, id: toAsk.id, expectedDocumentID: originalDocument)
        workspace.removeMeetingQuestion(id: toAsk.id, expectedDocumentID: originalDocument)
        XCTAssertFalse(workspace.saveMeetingQuestion(toAsk, expectedDocumentID: originalDocument))
        XCTAssertEqual(workspace.meetingQuestions, [toAsk, edited, expectedFollowUp])
        XCTAssertFalse(workspace.hasUnsavedChanges)
    }

    func testLegacyArchiveWithoutMeetingFieldDecodesAndKeepsGeneratedSuggestionsSeparate() throws {
        let archive = try makeArchive()
        let encoded = try JSONEncoder().encode(archive)
        let oldFormat = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(oldFormat["meetingQuestions"])
        let decoded = try JSONDecoder().decode(WorkspaceArchive.self, from: encoded)
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertNil(decoded.meetingQuestions)

        let workspace = SimpleWorkspace()
        try workspace.restore(decoded, persist: false)
        XCTAssertEqual(workspace.passageQuestions, archive.questions)
        XCTAssertTrue(workspace.meetingQuestions.isEmpty)
        XCTAssertFalse(workspace.hasUnsavedChanges)
    }

    func testRejectsInvalidQuestionAndSourceAndDoesNotChangeAnApprovedSource() throws {
        let archive = try makeArchive()
        let workspace = SimpleWorkspace()
        try workspace.restore(archive, persist: false)
        let id = workspace.documentID
        let invalidSource = MeetingQuestionSource(title: "Ongeldige bron", excerpt: firstPage, pageNumbers: [3], citations: [])
        let invalid = MeetingQuestion(question: "Ongeldige vraag?", source: invalidSource)
        XCTAssertFalse(workspace.saveMeetingQuestion(invalid, expectedDocumentID: id))
        let validSource = MeetingQuestionSource(title: "Proef", excerpt: firstPage, pageNumbers: [1], citations: [])
        XCTAssertFalse(workspace.saveMeetingQuestion(.init(question: " \n ", source: validSource), expectedDocumentID: id))
        XCTAssertFalse(workspace.hasUnsavedChanges)

        let approved = MeetingQuestion(question: "Hoe lang duurt de proef?", source: validSource)
        XCTAssertTrue(workspace.saveMeetingQuestion(approved, expectedDocumentID: id))
        let changedSource = MeetingQuestion(id: approved.id, question: approved.question,
            source: .init(title: "Evaluatie", excerpt: secondPage, pageNumbers: [2], citations: []))
        XCTAssertFalse(workspace.saveMeetingQuestion(changedSource, expectedDocumentID: id))

        var invalidArchive = archive
        invalidArchive.meetingQuestions = [invalid]
        XCTAssertThrowsError(try invalidArchive.validatedForWriting())
        XCTAssertThrowsError(try workspace.restore(invalidArchive, persist: false))
        XCTAssertEqual(workspace.documentID, id)
        XCTAssertEqual(workspace.meetingQuestions, [approved])

        invalidArchive.meetingQuestions = [approved, approved]
        XCTAssertThrowsError(try invalidArchive.validatedForWriting())

        workspace.removeMeetingQuestion(id: approved.id, expectedDocumentID: id)
        XCTAssertTrue(workspace.meetingQuestions.isEmpty)
        XCTAssertNil(try workspace.archive(readingPage: 1).meetingQuestions)
    }

    func testSeparateWorkspacesForTheSamePDFSaveTheirOwnApprovedQuestions() throws {
        let original = try makeArchive()
        let left = SimpleWorkspace()
        let right = SimpleWorkspace()
        try left.restore(original, persist: false)
        try right.restore(original, persist: false)
        let source = MeetingQuestionSource(title: "Proef", excerpt: firstPage, pageNumbers: [1], citations: [])
        let first = MeetingQuestion(question: "Wat is de looptijd?", source: source)
        let second = MeetingQuestion(question: "Wie evalueert?", source: source)
        XCTAssertTrue(left.saveMeetingQuestion(first, expectedDocumentID: left.documentID))
        XCTAssertTrue(right.saveMeetingQuestion(second, expectedDocumentID: right.documentID))

        XCTAssertEqual(try roundTrip(left.archive(readingPage: 1)).meetingQuestions, [first])
        XCTAssertEqual(try roundTrip(right.archive(readingPage: 1)).meetingQuestions, [second])
    }

    func testUnverifiedSourceIsKeptWithoutClaimingAQuoteOrHighlight() throws {
        let pages = [firstPage, secondPage]
        let forged = MeetingQuestionSource(title: "Evaluatie", excerpt: "Verzonnen tekst", pageNumbers: [1, 2],
            citations: [.init(page: 1, quote: "Een verzonnen bedrag van € 500.")])
        XCTAssertTrue(forged.isValid(pageCount: 2))
        XCTAssertNil(forged.verifiedQuote(on: 1, in: pages))
        XCTAssertNil(forged.verifiedQuote(on: 2, in: pages))
        XCTAssertFalse(forged.excerptIsVerified(in: pages))

        let twoPages = MeetingQuestionSource(title: "Evaluatie", excerpt: firstPage + "\n" + secondPage,
            pageNumbers: [1, 2], citations: [.init(page: 1, quote: firstPage), .init(page: 2, quote: secondPage)])
        XCTAssertTrue(twoPages.excerptIsVerified(in: pages))
        XCTAssertEqual(twoPages.verifiedQuote(on: 2, in: pages), secondPage)

        let userQuestion = MeetingQuestion(question: "Welke bron is bedoeld?", answer: "In de vergadering navragen.",
            status: .followUp, source: forged)
        var archive = try makeArchive()
        archive.meetingQuestions = [userQuestion]
        let encoded = try JSONEncoder().encode(archive.validatedForWriting())
        let workspace = SimpleWorkspace()
        try workspace.restore(JSONDecoder().decode(WorkspaceArchive.self, from: encoded), persist: false)
        XCTAssertEqual(workspace.meetingQuestions, [userQuestion])
        XCTAssertFalse(try XCTUnwrap(workspace.meetingQuestions.first).source.excerptIsVerified(in: pages))
    }

    func testSourceRequiresAUniqueLiteralMatchOnItsPage() {
        let full = "De raad ontvangt de evaluatie op 12.500 plaatsen."
        func verified(_ quote: String, on page: String) -> String? {
            MeetingQuestionSource(title: "Evaluatie", excerpt: quote, pageNumbers: [1], citations: [])
                .verifiedQuote(on: 1, in: [page])
        }
        XCTAssertEqual(verified("de evaluatie", on: "De raad ontvangt de\n evaluatie."), "de evaluatie")
        XCTAssertNil(verified("evaluatie", on: "De eindevaluatie staat gepland."))
        XCTAssertNil(verified("12", on: full))
        XCTAssertNil(verified("evaluatie", on: "De evaluatie is een evaluatie van de proef."))
        XCTAssertNil(verified("jaar jaar", on: "jaar jaar jaar"))

        let source = MeetingQuestionSource(title: "Evaluatie", excerpt: full, pageNumbers: [1], citations: [])
        XCTAssertEqual(source.forSuggestion(quote: "de evaluatie").excerpt, "de evaluatie")
        XCTAssertEqual(source.forSuggestion(quote: "12"), source)
        XCTAssertEqual(source.forSuggestion(quote: "Ontbrekende tekst"), source)
    }

    func testHighlightRequiresTheVerifiedQuoteToBeTheFirstAndOnlyPDFMatch() {
        let source = MeetingQuestionSource(title: "Evaluatie", excerpt: "evaluatie", pageNumbers: [1], citations: [])
        XCTAssertEqual(source.quoteForHighlight(on: 1, in: [secondPage]), "evaluatie")
        XCTAssertNil(source.quoteForHighlight(on: 1, in: ["EVALUATIE: de evaluatie volgt."]))
        XCTAssertNil(source.quoteForHighlight(on: 1, in: ["Eindevaluatie: de evaluatie volgt."]))
        XCTAssertNil(source.quoteForHighlight(on: 1, in: [""]))
    }

    func testSavedPageTextCannotVerifyAQuoteMissingFromTheEmbeddedPDF() throws {
        let archive = try makeArchive()
        let fabricatedText = "De proef is afgelast."
        let forged = MeetingQuestionSource(title: "Proef", excerpt: fabricatedText, pageNumbers: [1], citations: [])
        XCTAssertEqual(forged.verifiedQuote(on: 1, in: [fabricatedText, secondPage]), fabricatedText)
        let unverified = forged.verify(inPDF: archive.pdf)
        XCTAssertTrue(unverified.quotesForHighlight.isEmpty)
        XCTAssertFalse(unverified.excerptIsVerified)

        let literal = MeetingQuestionSource(title: "Proef", excerpt: firstPage, pageNumbers: [1], citations: [])
        let verified = literal.verify(inPDF: archive.pdf)
        XCTAssertEqual(verified.quotesForHighlight, [1: firstPage])
        XCTAssertTrue(verified.excerptIsVerified)
    }

    private func makeArchive() throws -> WorkspaceArchive {
        let pages = [firstPage, secondPage]
        let pdf = PDFDocument()
        for (index, text) in pages.enumerated() {
            let pdfData = try BriefingPDF.data(document: OpenPDF(name: "Voorbeeldstad.pdf", data: Data(), pages: [], findings: []),
                                               insights: [], analyzed: false, title: text)
            let onePage = try XCTUnwrap(PDFDocument(data: pdfData))
            let page = try XCTUnwrap(onePage.page(at: 0))
            pdf.insert(page, at: index)
        }
        let data = try XCTUnwrap(pdf.dataRepresentation())
        let workspace = SimpleWorkspace()
        workspace.document = OpenPDF(name: "Voorbeeldstad - buurtbusproef.pdf", data: data, pages: pages, findings: [],
            readings: pages.map { PageReading(text: $0) })
        let point = Insight(title: "Buurtbusproef", summary: firstPage, relevance: "", question: "", quote: firstPage, page: 1,
                            passageID: "buurtbusproef", relevanceClass: "main",
                            passageSources: [.init(page: 1, quote: firstPage)])
        let key = SimpleWorkspace.selectionKey(point)
        workspace.insights = [point]
        workspace.analyzed = true
        workspace.neutralAnalysis = true
        workspace.analysisState = .complete
        workspace.analysisScope = "Hele document"
        workspace.starred = [key]
        workspace.annotations = [key: .init(note: "Vraag ook naar rolstoeltoegankelijkheid.")]
        workspace.selectionMetadata = .init(order: [key], statuses: [key: .askQuestion])
        workspace.chosenPassages = [.init(title: "Evaluatiemoment", note: "Zet december in de planning.",
                                          text: secondPage, pages: [2], sources: [.init(page: 2, quote: secondPage)])]
        workspace.passageQuestions = [key: [.init(question: "Is er al een precieze startdatum?", quote: firstPage)]]
        var archive = try workspace.archive(readingPage: 1, viewState: .init(section: "Mijn selectie"))
        archive.analysisCompletedPages = Array(1...pages.count)
        return archive
    }

    private func roundTrip(_ archive: WorkspaceArchive) throws -> WorkspaceArchive {
        let data = try JSONEncoder().encode(archive.validatedForWriting())
        let restored = try JSONDecoder().decode(WorkspaceArchive.self, from: data)
        try restored.validate()
        return restored
    }
}
