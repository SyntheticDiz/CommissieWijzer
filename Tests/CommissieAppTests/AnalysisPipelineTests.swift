import XCTest
@testable import CommissieWijzer

final class AnalysisPipelineTests: XCTestCase {
    func testChunksPreserveAllTextAndPages() {
        let source = String(repeating: "Een volledige zin met € 100.\n\nEen andere alinea. ", count: 150) + "LAATSTE BESLUIT"
        let chunks = AnalysisPipeline.chunks(["", source])
        XCTAssertTrue(chunks.allSatisfy { $0.page == 1 && $0.text.utf8.count <= 1800 })
        XCTAssertEqual(chunks.map(\.text).joined(), source)
        XCTAssertTrue(chunks.last!.text.hasSuffix("LAATSTE BESLUIT"))
    }
    func testSelectionNeedsConcreteContent() {
        XCTAssertFalse(AnalysisPipeline.isCandidate("Wonen is belangrijk voor iedereen.", focus: "", hasProgram: false))
        XCTAssertTrue(AnalysisPipeline.isCandidate("De eigen bijdrage wordt verhoogd met € 10.", focus: "", hasProgram: false))
        XCTAssertFalse(AnalysisPipeline.isCandidate("De bibliotheek krijgt subsidie.", focus: "Verkeersveiligheid", hasProgram: false))
    }
    func testMergeKeepsPageReferencesAndDifferentQuotes() {
        func point(_ page: Int, _ quote: String) -> Insight { .init(title: "Kosten", summary: "Kosten", relevance: "Duiding", question: "Wie betaalt?", quote: quote, page: page) }
        let result = AnalysisPipeline.merge([point(1, "De bijdrage stijgt."), point(2, "De bijdrage stijgt."), point(3, "De bijdrage daalt.")])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].otherSources?.first?.page, 2)
    }
    func testCacheKeysSeparateFocusModelsAndContent() {
        let base = ["model", "focus", "programma", "tekst"]
        for index in base.indices {
            var modified = base; modified[index] += " gewijzigd"
            XCTAssertNotEqual(LocalCache.key(base), LocalCache.key(modified))
        }
        XCTAssertNotEqual(LocalCache.key(["a|b", "c"]), LocalCache.key(["a", "b|c"]))
    }
}
