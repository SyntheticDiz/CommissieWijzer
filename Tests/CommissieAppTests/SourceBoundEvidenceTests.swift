import XCTest
@testable import CommissieWijzer

final class SourceBoundEvidenceTests: XCTestCase {
    func testWholePassageAcrossPagesRequiresEveryLiteralSource() {
        let sources = [Insight.Source(page: 2, quote: "Het bedrag is € 250, mits"), .init(page: 3, quote: "de aanvraag vóór 1 juli wordt ingediend.")]
        var item = SourceHighlights.Item(kind: .amounts, page: 2, quote: sources.map(\.quote).joined(separator: "\n"))
        item.passageSources = sources
        item.passageID = "parent"
        let pages = ["Vorige", sources[0].quote, sources[1].quote, "Volgende"]
        XCTAssertEqual(SourceBoundEvidence.validate(item: item, pages: pages)?.quote, item.quote)
        XCTAssertEqual(SourceBoundEvidence.context(item: item, pages: pages)?.pages.map(\.text), pages)
        var changed = pages
        changed[2] = "de aanvraag vóór 1 augustus wordt ingediend."
        XCTAssertNil(SourceBoundEvidence.validate(item: item, pages: changed))
        item = .init(kind: item.kind, page: item.page, quote: sources[0].quote, passageSources: item.passageSources, passageID: item.passageID)
        XCTAssertNil(SourceBoundEvidence.validate(item: item, pages: pages), "Do not validate a quote that drops the condition")
    }

    func testMalformedPassageSourcesFailClosedAndLegacyStillWorks() {
        var item = SourceHighlights.Item(kind: .amounts, page: 1, quote: "€ 250")
        XCTAssertNotNil(SourceBoundEvidence.validate(item: item, pages: ["€ 250"]))
        item.passageSources = []
        XCTAssertNil(SourceBoundEvidence.validate(item: item, pages: ["€ 250"]))
        item.passageSources = [.init(page: 2, quote: "€ 250")]
        XCTAssertNil(SourceBoundEvidence.validate(item: item, pages: ["€ 250"]))
    }

    func testParagraphHighlightArchiveRoundTripAndValidation() throws {
        var item = SourceHighlights.Item(kind: .dates, page: 1, quote: "De regeling geldt mits\nde aanvraag op tijd is ontvangen.")
        item.passageID = "parent"
        item.passageSources = [.init(page: 1, quote: "De regeling geldt mits"), .init(page: 2, quote: "de aanvraag op tijd is ontvangen.")]
        item.assessmentNotice = "Niet automatisch beoordeeld"
        let decoded = try JSONDecoder().decode(SourceHighlights.Item.self, from: JSONEncoder().encode(item))
        XCTAssertTrue(WorkspaceArchive.validHighlight(decoded, pageCount: 2))
        XCTAssertEqual(decoded.quote, item.quote)
        XCTAssertEqual(decoded.passageSources?.map(\.quote), item.passageSources?.map(\.quote))
        XCTAssertEqual(decoded.assessmentNotice, item.assessmentNotice)
        XCTAssertFalse(WorkspaceArchive.validHighlight(decoded, pageCount: 1))
        item = .init(kind: item.kind, page: item.page, quote: "De regeling geldt mits", passageSources: item.passageSources, passageID: item.passageID)
        XCTAssertFalse(WorkspaceArchive.validHighlight(item, pageCount: 2))
    }

    private func item(page: Int = 2, quote: String = "  € 250,00\n per maand  ") -> SourceHighlights.Item {
        .init(kind: .amounts, page: page, quote: quote, title: "AI-titel", decisionStatus: "Voorgesteld")
    }

    func testValidQuoteReturnsOriginalLiteralSubstringIncludingWhitespaceAndUnicode() {
        let quote = "  € 250,00\n per maand  "
        let pages = ["Vooraf", "Begin \(quote) daarna"]

        let result = SourceBoundEvidence.validate(item: item(quote: quote), pages: pages)

        XCTAssertEqual(result?.physicalPage, 2)
        XCTAssertEqual(Array((result?.quote ?? "").utf8), Array(quote.utf8))
    }

    func testEmptyQuoteIsRejected() {
        XCTAssertNil(SourceBoundEvidence.validate(item: item(quote: ""), pages: ["", "inhoud"]))
        XCTAssertNil(SourceBoundEvidence.validate(item: item(quote: "  \n"), pages: ["", "inhoud  \n"]))
    }

    func testWhitespaceNormalizationCannotCreateAnExactMatch() {
        let quote = "De aanvraag moet uiterlijk\n1 oktober binnen zijn."
        let page = "De aanvraag moet uiterlijk 1 oktober binnen zijn."
        XCTAssertNil(SourceBoundEvidence.validate(item: item(quote: quote), pages: ["", page]))
    }

    func testCanonicallyEquivalentButDifferentlyEncodedTextIsNotAnExactMatch() {
        let composed = "café"
        let decomposed = "cafe\u{301}"
        XCTAssertEqual(composed, decomposed) // Swift String equality is canonically equivalent.
        XCTAssertNotEqual(Array(composed.utf8), Array(decomposed.utf8))
        XCTAssertNil(SourceBoundEvidence.validate(item: item(quote: composed), pages: ["", decomposed]))
    }

    func testQuoteOnDifferentPageIsRejected() {
        XCTAssertNil(SourceBoundEvidence.validate(item: item(page: 2, quote: "claim from page one"), pages: ["claim from page one", "other text"]))
    }

    func testInvalidPhysicalPageAndEmptyPageListAreRejected() {
        XCTAssertNil(SourceBoundEvidence.validate(item: item(page: 0), pages: ["text", "text"]))
        XCTAssertNil(SourceBoundEvidence.validate(item: item(page: 3), pages: ["text", "text"]))
        XCTAssertNil(SourceBoundEvidence.validate(item: item(), pages: []))
    }

    func testContextContainsWholePreviousCurrentAndNextPhysicalPages() {
        let pages = ["prev\nfull", "current\nwith table headers", "next\nfull", "outside"]
        let result = SourceBoundEvidence.context(item: item(quote: "current"), pages: pages)

        XCTAssertEqual(result?.pages.map(\.physicalPage), [1, 2, 3])
        XCTAssertEqual(result?.pages.map(\.text), Array(pages.prefix(3)))
        XCTAssertEqual(result?.verifiedQuote?.physicalPage, 2)
    }

    func testDocumentChangeRequiresRevalidationAgainstNewPageTexts() {
        let oldPages = ["", "Exact source quote here."]
        XCTAssertNotNil(SourceBoundEvidence.validate(item: item(quote: "Exact source quote here."), pages: oldPages))

        let changedPages = ["", "Updated source, quote removed."]
        XCTAssertNil(SourceBoundEvidence.validate(item: item(quote: "Exact source quote here."), pages: changedPages))
        XCTAssertNil(SourceBoundEvidence.context(item: item(quote: "Exact source quote here."), pages: changedPages)?.verifiedQuote)
    }

    func testContextAtDocumentEdgesUsesOnlyAvailablePagesAndPreservesEmptyPages() {
        let pages = ["first", "", "last"]
        let first = SourceBoundEvidence.context(item: item(page: 1, quote: "first"), pages: pages)
        let last = SourceBoundEvidence.context(item: item(page: 3, quote: "last"), pages: pages)

        XCTAssertEqual(first?.pages.map(\.physicalPage), [1, 2])
        XCTAssertEqual(first?.pages.map(\.text), ["first", ""])
        XCTAssertEqual(last?.pages.map(\.physicalPage), [2, 3])
        XCTAssertEqual(last?.pages.map(\.text), ["", "last"])
    }
}
