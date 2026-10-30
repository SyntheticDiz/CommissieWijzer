import XCTest
@testable import CommissieWijzer

final class UnifiedSearchTests: XCTestCase {
    func testSearchesAllExistingContentWithSourceActions() throws {
        let pages = ["Het COA ontvangt de aanvraag.\n\nDe raad bespreekt de kosten van 300 euro.", "Een tweede pagina over begeleiding."]
        let source = UnifiedSearch.documentRecords(pages: pages, documentKey: UUID().uuidString)
        let summary = DocumentSummary(digest: .init(overview: "Het voorstel regelt opvang.", bullets: []),
                                      sections: [.init(page: 1, digest: .init(overview: "De raad bespreekt opvang.", bullets: []))])
        let point = Insight(title: "Budget", summary: "Het budget is 300 euro.", relevance: "", question: "Welke dekking is er?", quote: "De raad bespreekt de kosten van 300 euro.", page: 1)
        let table = DocumentTable(id: "t1", title: "Jaarcijfers", pages: [2], headers: ["Jaar", "Bedrag"], rows: [["2026", "450"]], notes: [], reliable: true)
        let records = UnifiedSearch.analysisRecords(summary: summary, points: [point], tables: [table]) + source
        XCTAssertEqual(UnifiedSearch.matches("opvang", records: records).filter { $0.record.kind == .summary }.count, 2)
        XCTAssertEqual(UnifiedSearch.matches("dekking", records: records).first?.record.kind, .point)
        let pointHit = try XCTUnwrap(UnifiedSearch.matches("dekking", records: records).first)
        if case .point(let id, let page, let quote) = pointHit.record.action {
            XCTAssertEqual(id, point.id)
            XCTAssertEqual(page, 1)
            XCTAssertEqual(quote, point.quote)
        } else { XCTFail("Puntaction mist puntidentiteit of bronpassage") }
        XCTAssertEqual(UnifiedSearch.matches("450", records: records).first?.record.kind, .table)
        XCTAssertEqual(UnifiedSearch.matches("COA", records: records).filter { $0.record.kind == .glossary }.count, 1)
        let pdf = try XCTUnwrap(UnifiedSearch.matches("begeleiding", records: records).first { $0.record.kind == .pdf })
        if case .page(let page, _) = pdf.record.action { XCTAssertEqual(page, 2) } else { XCTFail("PDF-resultaat zonder bronpagina") }
        XCTAssertTrue(pdf.excerpt.contains("begeleiding"))
    }

    func testSearchIndexesChosenPassageTitleTextNoteAndPointAnnotationLocally() throws {
        let point = Insight(title: "Raadsplein", summary: "Aanpassing van de speelruimte.", relevance: "", question: "", quote: "De raad bespreekt het plein.", page: 2)
        let annotation = PointAnnotation(note: "Controleer fietsnietje")
        let passage = ChosenPassage(id: UUID(), title: "Fietsroute uitbreiding", note: "Mijn route-aantekening", text: "De nieuwe fietstunnel komt bij de singel.", pages: [3])
        let records = UnifiedSearch.analysisRecords(summary: nil, points: [point], tables: [],
                                                     chosenPassages: [passage],
                                                     annotations: [SimpleWorkspace.selectionKey(point): annotation])

        let titleHit = try XCTUnwrap(UnifiedSearch.matches("fietsroute", records: records).first)
        XCTAssertEqual(titleHit.record.kind, .chosenPassage)
        XCTAssertEqual(titleHit.record.title, passage.title)
        guard case .chosenPassage(let titleID) = titleHit.record.action else { return XCTFail("Gekozen passage mist UUID-route") }
        XCTAssertEqual(titleID, passage.id)

        let textHit = try XCTUnwrap(UnifiedSearch.matches("fietstunnel", records: records).first)
        guard case .chosenPassage(let textID) = textHit.record.action else { return XCTFail("Passagetekst mist UUID-route") }
        XCTAssertEqual(textID, passage.id)
        XCTAssertEqual(UnifiedSearch.matches("route-aantekening", records: records).first?.record.kind, .chosenPassage)

        let noteHit = try XCTUnwrap(UnifiedSearch.matches("fietsnietje", records: records).first)
        XCTAssertEqual(noteHit.record.kind, .annotation)
        guard case .point(let pointID, let page, _) = noteHit.record.action else { return XCTFail("Puntnotitie mist puntactie") }
        XCTAssertEqual(pointID, point.id)
        XCTAssertEqual(page, point.page)
    }

    @MainActor func testWorkspaceSearchRecordCacheInvalidatesForChosenPassageAndAnnotationChanges() throws {
        let workspace = SimpleWorkspace()
        let point = Insight(title: "Verkeersveiligheid", summary: "Oversteek bij school.", relevance: "", question: "", quote: "Het kruispunt wordt aangepast.", page: 1)
        workspace.insights = [point]
        XCTAssertTrue(UnifiedSearch.matches("fietstunnel", records: workspace.analysisSearchRecords).isEmpty)

        let passage = ChosenPassage(title: "Fietstunnelplanning", note: "", text: "Bespreek fietstunnel bij de singel.", pages: [2])
        workspace.chosenPassages = [passage]
        let chosenRecords = workspace.analysisSearchRecords
        let chosenHit = try XCTUnwrap(UnifiedSearch.matches("fietstunnelplanning", records: chosenRecords).first)
        guard case .chosenPassage(let chosenID) = chosenHit.record.action else { return XCTFail("Gekozen passage-index is verouderd") }
        XCTAssertEqual(chosenID, passage.id)

        workspace.chosenPassages = []
        let passageRemovedRecords = workspace.analysisSearchRecords
        XCTAssertTrue(UnifiedSearch.matches("fietstunnelplanning", records: passageRemovedRecords).isEmpty)

        workspace.annotations[SimpleWorkspace.selectionKey(point)] = PointAnnotation(note: "Bel de verkeerskundige")
        XCTAssertEqual(UnifiedSearch.matches("verkeerskundige", records: workspace.analysisSearchRecords).first?.record.kind, .annotation)
        workspace.annotations[SimpleWorkspace.selectionKey(point)] = PointAnnotation(note: "Vraag schooldirectie")
        XCTAssertTrue(UnifiedSearch.matches("verkeerskundige", records: workspace.analysisSearchRecords).isEmpty)
        XCTAssertEqual(UnifiedSearch.matches("schooldirectie", records: workspace.analysisSearchRecords).first?.record.kind, .annotation)
    }
    func testSearchIgnoresCategoryLabelsAndMatchesCaseAndAccents() {
        let record = SearchRecord(id: "1", kind: .pdf, title: "PDF-pagina 1", content: "Financiën: € 300 voor jeugd.", pageLabel: "PDF-pagina 1", action: .page(1, quote: nil))
        XCTAssertTrue(UnifiedSearch.matches("PDF", records: [record]).isEmpty)
        XCTAssertEqual(UnifiedSearch.matches("financien", records: [record]).count, 1)
        XCTAssertEqual(UnifiedSearch.matches("JEUGD", records: [record]).count, 1)
        let wrapped = SearchRecord(id: "2", kind: .pdf, title: "PDF-pagina 2", content: "De raad bespreekt\nde kosten.", pageLabel: "PDF-pagina 2", action: .page(2, quote: nil))
        XCTAssertEqual(UnifiedSearch.matches("bespreekt de kosten", records: [wrapped]).count, 1)
    }

    func testCachedFoldingPreservesAccentCaseAndWhitespaceSearch() {
        let record = SearchRecord(id: "1", kind: .pdf, title: "PDF-pagina 1",
                                  content: "De raad bespreekt\nde kosten voor Financiën.",
                                  pageLabel: "PDF-pagina 1", action: .page(1, quote: nil))
        XCTAssertEqual(UnifiedSearch.matches("  bespreekt   de   kosten ", records: [record]).count, 1)
        XCTAssertEqual(UnifiedSearch.matches("FINANCIEN", records: [record]).count, 1)
        XCTAssertTrue(UnifiedSearch.matches("PDF", records: [record]).isEmpty)
        XCTAssertEqual(record.foldedSearchable, "de raad bespreekt de kosten voor financien.")
    }

    func testCancellableMatcherStopsDuringRecordScan() {
        let records = (0..<200).map { index in
            SearchRecord(id: "\(index)", kind: .pdf, title: "Pagina \(index)",
                         content: String(repeating: "irrelevant ", count: 60), pageLabel: nil,
                         action: .page(index + 1, quote: nil))
        }
        let checks = CancellationCheckCounter(cancelAfter: 2)
        XCTAssertThrowsError(try UnifiedSearch.matchesCancellable("missing", records: records,
                                                                  cancellationCheck: { checks.shouldCancel() })) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(checks.count, 2)
    }

    func testRequestRejectsStaleQueryAndChangedRecords() {
        let original = SearchRecord(id: "1", kind: .pdf, title: "Pagina 1", content: "oude tekst",
                                    pageLabel: nil, action: .page(1, quote: nil))
        let request = UnifiedSearch.request(query: "oud", records: [original])
        XCTAssertTrue(UnifiedSearch.isCurrent(request, query: "oud", records: [original]))
        XCTAssertFalse(UnifiedSearch.isCurrent(request, query: "nieuw", records: [original]))

        let updated = SearchRecord(id: "1", kind: .pdf, title: "Pagina 1", content: "nieuwe tekst",
                                   pageLabel: nil, action: .page(1, quote: nil))
        XCTAssertFalse(UnifiedSearch.isCurrent(request, query: "oud", records: [updated]))
    }
}

private final class CancellationCheckCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var checks = 0
    private let cancelAfter: Int

    init(cancelAfter: Int) { self.cancelAfter = cancelAfter }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return checks
    }

    func shouldCancel() -> Bool {
        lock.lock(); defer { lock.unlock() }
        checks += 1
        return checks >= cancelAfter
    }
}
