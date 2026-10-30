import XCTest
@testable import CommissieWijzer

final class PartyProgramTests: XCTestCase {
    func testPersistenceAndPhysicalPageRetrieval() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("program.json")
        let program = PartyProgram(name: "Programma.pdf", pages: ["", "Wij willen betaalbare huurwoningen voor gezinnen."], pdf: Data("fixture".utf8))
        try program.save(to: url)
        let restored = try XCTUnwrap(PartyProgram.load(from: url))
        XCTAssertEqual(restored.name, program.name)
        XCTAssertEqual(restored.pdf, program.pdf)
        XCTAssertEqual(restored.candidates(for: "Er komen betaalbare huurwoningen.").first?.page, 1)
        XCTAssertFalse(restored.candidates(for: "Astronomie en sterrenstelsels.").isEmpty) // Always offer program context for cross-referencing.
    }
    func testRequiresBothDocumentAndProgramCitations() {
        let program = PartyProgram(name: "Programma.pdf", pages: ["", "Meer betaalbare huurwoningen."], pdf: Data())
        let source = "Er komen huurwoningen."
        func match(_ quote: String, _ programQuote: String, _ page: Int) -> ProgramMatcher.Match {
            .init(title: "Wonen", summary: source, relevance: "Mogelijk raakvlak", question: "Voor wie?", quote: quote, programQuote: programQuote, programPage: page)
        }
        let result = ProgramMatcher.validated([
            match(source, program.pages[1], 2),
            match("Verzonnen", program.pages[1], 2),
            match(source, "Geen huurwoningen", 2),
            match(source, program.pages[1], 1)
        ], source: source, page: 7, program: program, candidates: program.candidates(for: source))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.page, 7)
        XCTAssertTrue(result.first?.programSource?.contains("PDF-pagina 2") == true)
    }
}
