import XCTest
@testable import CommissieWijzer

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func read() -> Value {
        lock.lock(); defer { lock.unlock() }
        return value
    }
    func update(_ body: (inout Value) -> Void) {
        lock.lock(); defer { lock.unlock() }
        body(&value)
    }
}

final class PassageEngineTests: XCTestCase {
    private func answer(_ input: String, relevance: String = "main", sourceIDs: [String]? = nil,
                        contextIDs: [String] = [], point: Bool = true) -> String {
        let id = input.range(of: #"\[(D[^,]+), p\. \d+\]"#, options: .regularExpression).map { String(input[$0].dropFirst().split(separator: ",").first ?? "D1-1") } ?? "D1-1"
        let data: [String: Any]
        if point {
            data = ["points": [["title": "Aandachtspunt", "summary": "Brongebonden tekst.", "documentID": id,
                                "sourceIDs": sourceIDs ?? [id], "relevanceClass": relevance,
                                "relevanceReason": "De bron noemt een concreet gevolg.", "contextIDs": contextIDs]]]
        } else { data = ["points": []] }
        let encoded = try! JSONSerialization.data(withJSONObject: data)
        return String(decoding: encoded, as: UTF8.self)
    }

    func testPageContinuationOnlyJoinsAnUnfinishedSentenceAndKeepsPhysicalSources() {
        let paragraphs = DocumentParagraphs.extract([
            "Het college stelt voor om de regeling voort te zetten tenzij",
            "de raad vóór 1 juni anders besluit.\n\nEen zelfstandige alinea volgt."
        ])
        XCTAssertEqual(paragraphs.count, 2)
        XCTAssertEqual(paragraphs[0].sources.map(\.page), [1, 2])
        XCTAssertTrue(paragraphs[0].text.contains("tenzij"))
        XCTAssertTrue(paragraphs[0].text.contains("vóór 1 juni"))
        XCTAssertEqual(paragraphs[1].sources.first?.page, 2)
    }

    func testCompletedPageSentenceDoesNotJoinLowercaseNextPageAndTrailingHeadingIsRetained() {
        let paragraphs = DocumentParagraphs.extract(["De raad heeft dit besluit vastgesteld.", "daarnaast vraagt het college aandacht.", "Financiële gevolgen"])
        XCTAssertEqual(paragraphs.count, 3)
        XCTAssertEqual(paragraphs.map(\.sources.first!.page), [1, 2, 3])
        XCTAssertEqual(paragraphs.last?.text, "Financiële gevolgen")
    }

    func testCrossPagePassageKeepsEverySourceCharacterInItsMappedSlice() {
        let first = "Het college stelt voor de regeling voort te zetten tenzij"
        let second = "De raad vóór 1 juni anders besluit."
        let paragraph = DocumentParagraphs.extract([first, second]).first!
        XCTAssertEqual(paragraph.sources.map(\.quote), [first, second])
        let passage = PassageEngine.passages([first, second]).first!
        let parts = PassageEngine.parts(passage, coreLimit: 900)
        XCTAssertEqual(parts.map(\.core).joined(), first + "\n" + second)
        XCTAssertEqual(parts.flatMap(\.sources).map(\.quote), [first, second])
        XCTAssertTrue(parts.flatMap(\.sources).allSatisfy { [first, second].contains($0.quote) })
    }

    func testLongPassagePartsCoverAllCoreTextAndKeepActualPageSubstrings() {
        let first = String(repeating: "De gemeente reserveert 250.000 euro voor onderhoud. ", count: 90)
        let second = String(repeating: "De raad ontvangt ieder kwartaal een voortgangsrapportage. ", count: 80)
        let passage = PassageEngine.passages([first, second]).first!
        let parts = PassageEngine.parts(passage, coreLimit: 900)
        XCTAssertGreaterThan(parts.count, 4)
        XCTAssertEqual(parts.map(\.core).joined(), passage.text)
        XCTAssertEqual(Set(parts.map(\.passageID)), [passage.id])
        for part in parts {
            XCTAssertFalse(part.sources.isEmpty)
            for source in part.sources {
                XCTAssertGreaterThan(source.page, 0)
                XCTAssertTrue([first, second][source.page - 1].contains(source.quote))
            }
        }
    }

    func testContextSourcesAreAttributedButCannotBeUsedAsPointSources() async throws {
        let passage = PassageEngine.passages(["De gemeente evalueert de regeling.", "Daarom wordt de subsidie in 2028 beëindigd."])[1]
        let part = PassageEngine.parts(passage, coreLimit: 900)[0]
        XCTAssertFalse(part.contextSources.isEmpty)
        let result = try await PassageEngine.extract(part, model: "fixture", focus: "", program: nil, candidate: nil,
            request: { body in
                let input = body["input"] as! String
                let contextID = input.range(of: #"\[(C[^,]+), p\. \d+\]"#, options: .regularExpression).map { String(input[$0].dropFirst().split(separator: ",").first ?? "C1-1") } ?? "C1-1"
                return self.answer(input, contextIDs: [contextID])
            }, useCache: false)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.contextSources?.count, 1)
        XCTAssertTrue(result.first?.quote.contains("subsidie") == true)

        do {
            _ = try await PassageEngine.extract(part, model: "fixture", focus: "", program: nil, candidate: nil,
                request: { body in self.answer(body["input"] as! String, contextIDs: ["C99"]) }, useCache: false)
            XCTFail("Unknown context IDs must be rejected")
        } catch let failure as AppleFailure {
            XCTAssertEqual(failure, .invalid)
        }
    }

    func testNeutralEmptyPassageRemainsAccessibleAsBackground() async throws {
        let passage = PassageEngine.passages(["De tekst noemt uitsluitend algemene toelichting."])[0]
        let part = PassageEngine.parts(passage)[0]
        let result = try await PassageEngine.extract(part, model: "fixture", focus: "", program: nil, candidate: nil,
            request: { _ in self.answer("", point: false) }, useCache: false)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.relevanceClass, "background")
        XCTAssertEqual(result.first?.passageSources?.first?.quote, passage.text)
    }

    func testAppleContextFailureSplitsLocallyAndMarksChildrenUncertain() async throws {
        let text = String(repeating: "Deze regeling wordt voortgezet tenzij de raad anders besluit. ", count: 120)
        let passage = PassageEngine.passages([text])[0]
        let part = PassageEngine.parts(passage)[0]
        let inputs = LockedValue<[String]>([])
        let results = try await PassageEngine.extract(part, model: AppleAIService.modelID, focus: "", program: nil, candidate: nil,
            request: { body in
                let input = body["input"] as! String
                inputs.update { $0.append(input) }
                if input.utf8.count > 4_000 { throw AppleFailure.context }
                return self.answer(input)
            }, useCache: false)
        XCTAssertGreaterThan(inputs.read().count, 2)
        XCTAssertGreaterThan(results.count, 1)
        XCTAssertEqual(results.compactMap(\.passagePartIndex), Array(1...results.count))
        XCTAssertEqual(Set(results.compactMap(\.passagePartCount)), [results.count])
        XCTAssertTrue(results.allSatisfy { $0.relevanceClass == "uncertain" })
        XCTAssertTrue(results.allSatisfy { $0.passageSources?.map(\.quote).joined().contains("anders besluit") == true })
    }
    func testPreviousContextUsesNearestTailAndNextContextUsesHead() {
        let prior = String(repeating: "Oude toelichting. ", count: 80) + "Alleen na goedkeuring van de raad."
        let next = "Aanvragen sluiten op 1 juni. " + String(repeating: "Latere toelichting. ", count: 80)
        let passage = PassageEngine.passages([prior + "\n\nDeze regeling betreft de sportbijdrage.\n\n" + next])[1]
        XCTAssertEqual(passage.contextSources.count, 2)
        XCTAssertTrue(passage.contextSources[0].quote.hasSuffix("Alleen na goedkeuring van de raad."))
        XCTAssertTrue(passage.contextSources[1].quote.hasPrefix("Aanvragen sluiten op 1 juni."))
    }

    func testFailedMiddleLeafKeepsSuccessfulChildrenAndTheirPositions() async throws {
        let text = (1...18).map { "Gebied \($0) ontvangt uitsluitend na toestemming een bijdrage van \($0 * 100) euro voor onderhoud." }.joined(separator: " ")
        let passage = PassageEngine.passages([text])[0]
        let leafCalls = LockedValue(0)
        do {
            _ = try await PassageEngine.extract(PassageEngine.parts(passage)[0], model: AppleAIService.modelID,
                focus: "", program: nil, candidate: nil, request: { body in
                    let input = body["input"] as! String
                    let core = input.components(separatedBy: "CORE (enige citeerbare documentbron):\n")[1].components(separatedBy: "\nCONTEXT")[0]
                    if core.utf8.count > 500 { throw AppleFailure.context }
                    var call = 0
                    leafCalls.update { $0 += 1; call = $0 }
                    if call == 2 { throw AppleFailure.refusal }
                    return self.answer(input)
                }, useCache: false)
            XCTFail("An omitted leaf must not be reported as complete")
        } catch let error as PassageEngine.Incomplete {
            let count = leafCalls.read()
            XCTAssertGreaterThan(count, 2)
            XCTAssertEqual(error.cause as? AppleFailure, .refusal)
            XCTAssertEqual(error.points.compactMap(\.passagePartIndex), (1...count).filter { $0 != 2 })
            XCTAssertEqual(Set(error.points.compactMap(\.passagePartCount)), [count])
            XCTAssertTrue(error.points.allSatisfy { $0.passageSources?.first?.quote == text && $0.relevanceClass == "uncertain" })
        }
    }

    func testLongPassageCanRetrieveDistantOriginalCondition() {
        let core = "De sportregeling vergoedt maximaal 300 euro per kind."
        let condition = "De sportregeling geldt uitsluitend na instemming van de raad."
        let original = core + " " + String(repeating: "De uitvoering wordt nader toegelicht. ", count: 60) + condition
        let source = PassageEngine.conditionContext(core: core, sources: [.init(page: 4, quote: original)])
        XCTAssertEqual(source?.page, 4)
        XCTAssertTrue(source?.quote.contains(condition) == true)
        XCTAssertTrue(original.contains(source?.quote ?? "missing"))
    }

}
