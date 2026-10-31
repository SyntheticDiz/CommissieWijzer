import XCTest
import PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import CommissieWijzer

@MainActor
final class WorkspaceArchiveTests: XCTestCase {
    func testArchiveRoundTripPreservesReviewSourcesAndWorkspaceStateWithoutAI() throws {
        let pages = ["De gemeente reserveert geld voor betaalbare woningen in de wijk."]
        let basePDF = try BriefingPDF.data(document: OpenPDF(name: "Begroting.pdf", data: Data(), pages: [], findings: []),
                                           insights: [], analyzed: false, title: "Begroting")
        let readings = [PageReading(text: pages[0], notice: "", columns: 1, headings: ["Wonen"])]
        let workspace = SimpleWorkspace()
        workspace.document = OpenPDF(name: "Begroting.pdf", data: basePDF, pages: pages, findings: [], readings: readings)
        workspace.tables = [DocumentTable(id: "table-1", title: "Woningbouw", pages: [1],
                                         headers: ["Onderdeel", "Aantal"], rows: [["Betaalbare woningen", "25"]],
                                         notes: ["Raadsvoorstel"], reliable: true)]
        workspace.documentSummary = DocumentSummary(digest: .init(overview: "Woningen in de wijk.", bullets: ["25 woningen"]),
                                                    sections: [.init(page: 1, digest: .init(overview: "Woonbeleid", bullets: ["25 woningen"]))],
                                                    incompleteNotice: "Samenvatting is lokaal bewaard.", fallbackNotice: "Broncontrole blijft nodig.")
        workspace.summaryScope = "Hele document"
        workspace.keyPoints = [.init(kind: .decisions, page: 1, quote: pages[0], title: "Woningbouw", importance: 2)]
        workspace.highlightScope = "Hele document"
        workspace.keyPointsReady = true
        workspace.insights = [Insight(title: "Betaalbare woningen", summary: "25 woningen in de wijk.", relevance: "", question: "", quote: pages[0], page: 1,
                                       programSource: "Partijprogramma", otherSources: [.init(page: 1, quote: pages[0])],
                                       passageID: "base-passage", relevanceClass: "main", relevanceReason: "Letterlijk voorstel.",
                                       contextSources: [.init(page: 1, quote: pages[0])], passagePartIndex: 1, passagePartCount: 1,
                                       passageSources: [.init(page: 1, quote: pages[0])])]
        workspace.analyzed = true
        workspace.neutralAnalysis = false
        workspace.analysisState = .complete
        workspace.analysisScope = "PDF-pagina’s 1"
        workspace.analysisContext = "Woonbeleid"
        workspace.analysisIssues = "Geen aanvullende fout"
        workspace.citationWarning = "Controleer bron aan de PDF."
        workspace.starred = ["selected-point"]
        workspace.selectionMetadata = SavedSelectionMetadata(order: ["selected-point"], statuses: ["selected-point": .askQuestion])
        workspace.annotations = ["selected-point": PointAnnotation(note: "Vraag naar planning.", checkedSignature: "checked")]
        workspace.passageQuestions = ["base-passage": [PassageQuestion(question: "Wanneer start de bouw?", quote: pages[0])]]
        workspace.chosenPassages = [ChosenPassage(title: "Woonalinea", note: "Navragen", text: pages[0], pages: [1],
                                                  sources: [.init(page: 1, quote: pages[0])])]
        workspace.meetingPurpose = .leefomgeving
        workspace.activeModel = "fixture-model"
        workspace.focus = "Woonbeleid"
        workspace.page = 1
        let viewState = WorkspaceViewState(section: "Punten", pointsMode: "all", openGroups: ["housing"],
                                           pointPageFilter: "1", reviewFilter: 2, pdfVisible: true,
                                           pointsExpanded: true, compactReading: false, search: "woningen",
                                           committeeShowAll: [MeetingPurpose.leefomgeving.rawValue: true])

        var archive = try workspace.archive(readingPage: 1, viewState: viewState)
        let passage = try XCTUnwrap(PassageEngine.passages(pages).first)
        let currentReview = makeReview(passage: passage, purpose: .leefomgeving, model: "fixture-model", rating: .important)
        let historicalReview = makeReview(passage: passage, purpose: .leefomgeving, model: "older-model", rating: .relevant)
        archive.committeeReviews = [historicalReview, currentReview]
        let chatSource = ChatSource(id: "D1", page: 1, text: pages[0], isProgram: false, name: "Begroting.pdf")
        archive.savedChatThreads = [SavedChatThread(id: "scope-wonen", pages: [1], model: "fixture-model", focus: "Woonbeleid",
                                                    wholeDocument: true, passage: nil,
                                                    messages: [ChatMessage(isUser: true, text: "Wanneer start de bouw?"),
                                                               ChatMessage(isUser: false, text: "De bron noemt een planning.",
                                                                           citations: [.init(sourceID: "D1", quote: "betaalbare woningen")],
                                                                           sources: [chatSource])])]
        archive.savedSelectionSummaries = [SavedSelectionSummary(selection: .init(text: pages[0], pages: [1]),
            summary: "De oorspronkelijke bijdrage en termijn blijven behouden.", notice: "Controleer bron.", model: "fixture-model")]
        let chartImage = try makePNG()
        archive.savedChartAnalyses = [SavedChartAnalysis(id: UUID(), page: 1, imagePNG: chartImage,
            explanation: ChartExplanation(kind: "staafdiagram", title: "Woningen", summary: "25 woningen zijn zichtbaar.",
                                         observations: ["De tabel toont 25 woningen."], visibleValues: ["25"],
                                         caution: "Controleer het label in de bron."))]

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("complete.spdfwork")
        try archive.write(url)
        if let output = ProcessInfo.processInfo.environment["CW_PORTABLE_FIXTURE_OUTPUT"] {
            try archive.write(URL(fileURLWithPath: output))
        }
        let loaded = try WorkspaceArchive.read(url)

        XCTAssertEqual(loaded.pdf, basePDF)
        XCTAssertEqual(loaded.pages, pages)
        XCTAssertEqual(loaded.readings.map(\.text), readings.map(\.text))
        XCTAssertEqual(loaded.tables.first?.rows, [["Betaalbare woningen", "25"]])
        XCTAssertEqual(loaded.summary?.digest.overview, "Woningen in de wijk.")
        XCTAssertEqual(loaded.summary?.incompleteNotice, "Samenvatting is lokaal bewaard.")
        XCTAssertEqual(loaded.highlights.first?.title, "Woningbouw")
        XCTAssertTrue(loaded.highlightsReady)
        XCTAssertEqual(loaded.insights.first?.passageSources?.first?.quote, pages[0])
        XCTAssertEqual(loaded.analysisContext, "Woonbeleid")
        XCTAssertEqual(loaded.citationWarning, "Controleer bron aan de PDF.")
        XCTAssertEqual(loaded.starred, ["selected-point"])
        XCTAssertEqual(loaded.selectionMetadata?.statuses["selected-point"], .askQuestion)
        XCTAssertEqual(loaded.annotations["selected-point"]?.note, "Vraag naar planning.")
        XCTAssertEqual(loaded.questions["base-passage"]?.first?.question, "Wanneer start de bouw?")
        XCTAssertEqual(loaded.chosenPassages?.first?.text, pages[0])
        XCTAssertEqual(loaded.meetingPurpose, .leefomgeving)
        XCTAssertEqual(loaded.viewState, viewState)
        XCTAssertEqual(loaded.committeeReviews?.count, 2)
        XCTAssertEqual(loaded.committeeReviews?.map(\.model), ["older-model", "fixture-model"])
        XCTAssertEqual(loaded.committeeReviews?.last?.entries.first?.sources.map { "\($0.page):\($0.quote)" }, passage.sources.map { "\($0.page):\($0.quote)" })
        XCTAssertEqual(loaded.savedChatThreads?.first?.messages.count, 2)
        XCTAssertEqual(loaded.savedChatThreads?.first?.messages.last?.citations.first?.quote, "betaalbare woningen")
        XCTAssertEqual(loaded.savedChartAnalyses?.first?.imagePNG, chartImage)
        XCTAssertEqual(loaded.savedChartAnalyses?.first?.explanation.title, "Woningen")

        let restored = SimpleWorkspace()
        restored.generateCommitteeReview = { _, _, _, _ in
            XCTFail("Opening a saved workdocument must not make another AI request.")
            throw CancellationError()
        }
        try restored.restore(loaded, persist: false)
        XCTAssertEqual(restored.document?.data, basePDF)
        XCTAssertEqual(restored.insights.first?.quote, pages[0])
        XCTAssertEqual(restored.committeeReviews[MeetingPurpose.leefomgeving.rawValue]?.entries.first?.sources.map { "\($0.page):\($0.quote)" }, passage.sources.map { "\($0.page):\($0.quote)" })
        XCTAssertEqual(restored.savedChatThreads.first?.messages.count, 2)
        XCTAssertEqual(restored.savedChatThreads.first?.messages.last?.citations.first?.quote, "betaalbare woningen")
        XCTAssertEqual(restored.savedChartAnalyses.first?.imagePNG, chartImage)
        XCTAssertEqual(restored.savedChartAnalyses.first?.explanation.title, "Woningen")
        XCTAssertEqual(loaded.savedSelectionSummaries?.first?.selection.text, pages[0])
        XCTAssertEqual(restored.savedSelectionSummaries.first?.summary, "De oorspronkelijke bijdrage en termijn blijven behouden.")
        XCTAssertEqual(restored.savedSelectionSummaries.first?.notice, "Controleer bron.")
    }

    func testMalformedSupplementsBlockSaveInsteadOfSilentlyDroppingData() throws {
        let page = "De gemeente bouwt woningen."
        let pdfData = try BriefingPDF.data(document: OpenPDF(name: "Basis.pdf", data: Data(), pages: [], findings: []),
                                           insights: [], analyzed: false, title: "Basis")
        let workspace = SimpleWorkspace()
        workspace.document = OpenPDF(name: "Basis.pdf", data: pdfData, pages: [page], findings: [])
        var archive = try workspace.archive(readingPage: 1)
        archive.savedChatThreads = [SavedChatThread(id: "bad-thread", pages: [2], model: "fixture", focus: "",
                                                    wholeDocument: false, passage: nil, messages: [])]
        archive.savedChartAnalyses = [SavedChartAnalysis(id: UUID(), page: 2, imagePNG: Data(),
            explanation: ChartExplanation(kind: "chart", title: "Title", summary: "Summary",
                                         observations: [], visibleValues: [], caution: "Check source"))]
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("base.spdfwork")

        XCTAssertThrowsError(try archive.write(url))
        // Simulate an older/external archive containing malformed optional records.
        // The supported writer refuses it; the reader keeps the valid base document.
        try JSONEncoder().encode(archive).write(to: url)
        let restored = try WorkspaceArchive.read(url)
        XCTAssertEqual(restored.pages, [page])
        XCTAssertEqual(restored.savedChatThreads?.count, 0)
        XCTAssertEqual(restored.savedChartAnalyses?.count, 0)
    }

    func testLegacyInsightSourcesCannotCitePagesOutsideArchivedPDF() throws {
        let page = "De gemeente bouwt woningen."
        let pdfData = try BriefingPDF.data(document: OpenPDF(name: "Basis.pdf", data: Data(), pages: [], findings: []),
                                           insights: [], analyzed: false, title: "Basis")
        let workspace = SimpleWorkspace()
        workspace.document = OpenPDF(name: "Basis.pdf", data: pdfData, pages: [page], findings: [])
        let validArchive = try workspace.archive(readingPage: 1)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(validArchive)) as? [String: Any])
        object["insights"] = [["title": "Punt", "summary": "Samenvatting", "relevance": "", "question": "",
                                "quote": page, "page": 1,
                                "otherSources": [["page": 2, "quote": "Niet in dit document"]]]]
        let archive = try JSONDecoder().decode(WorkspaceArchive.self,
                                               from: JSONSerialization.data(withJSONObject: object))

        XCTAssertThrowsError(try archive.validate(), "Legacy extra-source citations are rendered in PDF exports and must refer to an archived page.")
    }

    private func makeReview(passage: PassageEngine.Passage, purpose: MeetingPurpose, model: String,
                            rating: CommitteeAssessmentService.Rating) -> CommitteeAssessmentService.Review {
        let entry = CommitteeAssessmentService.Assessment(passageID: passage.id, sources: passage.sources,
            rating: rating, reason: "Voor het gekozen doel beoordeeld.", evidenceQuote: passage.text, model: model)
        return CommitteeAssessmentService.Review(purpose: purpose, model: model, inputKey: "historical-\(model)",
                                                 entries: [entry], issues: [], complete: true)
    }

    private func makePNG() throws -> Data {
        #if os(macOS)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
                                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                    isPlanar: false, colorSpaceName: .deviceRGB,
                                                    bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.setColor(.white, atX: 0, y: 0)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        #else
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        #endif
    }
}
