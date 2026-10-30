import XCTest
import PDFKit
@testable import CommissieWijzer

final class ScopedExportTests: XCTestCase {
    private func assessment(_ passage: PassageEngine.Passage,
                           rating: CommitteeAssessmentService.Rating) -> CommitteeAssessmentService.Assessment {
        CommitteeAssessmentService.Assessment(
            passageID: passage.id, sources: passage.sources, rating: rating,
            reason: "De bron noemt deze passage.", evidenceQuote: rating == .unassessed ? "" : passage.text,
            model: "review-model")
    }

    private func insight(_ title: String, passage: PassageEngine.Passage) throws -> Insight {
        let source = try XCTUnwrap(passage.sources.first)
        return Insight(title: title, summary: "Puntsamenvatting.", relevance: "", question: "",
                       quote: passage.text, page: source.page,
                       passageID: passage.id, passageSources: passage.sources)
    }

    private func json(_ insight: Insight) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(insight)
    }

    private func makeContent(configuration: ExportConfiguration, pages: [String],
                             insights: [Insight], review: CommitteeAssessmentService.Review?,
                             chosen: [ChosenPassage] = [], summary: DocumentSummary? = nil,
                             tables: [DocumentTable] = []) -> ScopedExportContent {
        ScopedExportContent.make(configuration: configuration, pages: pages, insights: insights,
                                 review: review, summary: summary, summaryScope: "Hele document",
                                 tables: tables, chosenPassages: chosen, glossary: [], notice: "Oorspronkelijke waarschuwing",
                                 context: "Bestaande context", neutralAnalysis: true)
    }

    func testFullDocumentReturnsInputsUnchangedWhenScopeIsNil() {
        let pages = ["Volledige documenttekst."]
        let point = Insight(title: "Punt", summary: "Samenvatting", relevance: "", question: "",
                            quote: "Bron", page: 1)
        let chosen = ChosenPassage(text: "Letterlijke keuze", pages: [1])
        let content = makeContent(configuration: ExportConfiguration(), pages: pages,
                                  insights: [point], review: nil, chosen: [chosen])

        XCTAssertEqual(content.insights.map(\.title), [point.title])
        XCTAssertEqual(content.insights.map(\.summary), [point.summary])
        XCTAssertEqual(content.chosenPassages, [chosen])
        XCTAssertNil(content.summary)
        XCTAssertEqual(content.summaryScope, "Hele document")
        XCTAssertEqual(content.notice, "Oorspronkelijke waarschuwing")
        XCTAssertEqual(content.context, "Bestaande context")
        XCTAssertTrue(content.neutralAnalysis)
    }

    func testCustomMySelectionKeepsAllPointsForIndependentQuestionFiltering() throws {
        let pages = ["Bron één.", "Bron twee."]
        let points = try PassageEngine.passages(pages).enumerated().map { index, passage in
            let source = try XCTUnwrap(passage.sources.first)
            return Insight(title: "Punt \(index + 1)", summary: "Samenvatting \(index + 1)", relevance: "",
                           question: "Vraag \(index + 1)", quote: passage.text, page: source.page,
                           passageID: passage.id, passageSources: passage.sources)
        }
        var configuration = ExportConfiguration()
        configuration.selectedPoints = true
        configuration.selectedQuestions = false
        let content = makeContent(configuration: configuration, pages: pages,
                                  insights: points, review: nil)

        XCTAssertEqual(content.insights.count, points.count)
        for (original, exported) in zip(points, content.insights) {
            XCTAssertEqual(try json(exported), try json(original))
        }
        XCTAssertTrue(configuration.selectedPoints)
        XCTAssertFalse(configuration.selectedQuestions)
        XCTAssertTrue(content.insights.allSatisfy { !$0.question.isEmpty },
                      "The PDF renderer needs the full point input so selectedPoints and selectedQuestions can filter independently")
    }

    func testCommitteeScopeKeepsNonOtherRatingsAndLiteralSourceOnlyPassages() throws {
        let pages = ["Gekoppeld punt over openbare ruimte.\n\nAlleen een commissiebron zonder eerder punt.\n\nNiet relevant voor deze commissie.\n\nNog niet beoordeelde passage."]
        let passages = PassageEngine.passages(pages)
        let mappedPassage = try XCTUnwrap(passages.first)
        let uncertainPassage = try XCTUnwrap(passages.dropFirst().first)
        let otherPassage = try XCTUnwrap(passages.dropFirst(2).first)
        let unassessedPassage = try XCTUnwrap(passages.dropFirst(3).first)
        let mappedPoint = try insight("Gekoppeld aandachtspunt", passage: mappedPassage)
        let unmatched = Insight(title: "Niet gekoppeld punt", summary: "Bewaar als onzeker.", relevance: "",
                                question: "", quote: "Onbekende bron", page: 1,
                                passageID: "stale-passage-id",
                                passageSources: [.init(page: 1, quote: "Onbekende bron")])
        let entries = [
            assessment(mappedPassage, rating: .important),
            assessment(uncertainPassage, rating: .uncertain),
            assessment(otherPassage, rating: .other),
            assessment(unassessedPassage, rating: .unassessed)
        ]
        let review = CommitteeAssessmentService.Review(purpose: .bestuur, model: "review-model",
                                                       inputKey: "historical-key", entries: entries,
                                                       issues: [], complete: false)
        var configuration = ExportConfiguration()
        configuration.committeePurpose = .bestuur
        configuration.summary = false
        configuration.tables = false
        configuration.glossary = false
        configuration.chosenPassages = true
        let content = makeContent(configuration: configuration, pages: pages,
                                  insights: [mappedPoint, unmatched], review: review)

        let mappedKey = SimpleWorkspace.selectionKey(mappedPoint)
        let unmatchedKey = SimpleWorkspace.selectionKey(unmatched)
        let annotations = [mappedKey: PointAnnotation(note: "Eigen notitie", checkedSignature: PointAnnotation.signature(mappedPoint))]
        let selection = SavedSelectionMetadata(order: [mappedKey, unmatchedKey], statuses: [mappedKey: .done, unmatchedKey: .askQuestion])

        XCTAssertEqual(content.insights.count, 2)
        let exportedMapped = try XCTUnwrap(content.insights.first)
        let exportedUnmatched = try XCTUnwrap(content.insights.dropFirst().first)
        XCTAssertEqual(try json(exportedMapped), try json(mappedPoint))
        XCTAssertEqual(try json(exportedUnmatched), try json(unmatched))
        XCTAssertEqual(SimpleWorkspace.selectionKey(exportedMapped), SimpleWorkspace.selectionKey(mappedPoint))
        XCTAssertEqual(SimpleWorkspace.selectionKey(exportedUnmatched), SimpleWorkspace.selectionKey(unmatched))
        XCTAssertEqual(annotations[SimpleWorkspace.selectionKey(exportedMapped)]?.note, "Eigen notitie")
        let outputAnnotation = try XCTUnwrap(annotations[SimpleWorkspace.selectionKey(exportedMapped)])
        XCTAssertTrue(outputAnnotation.isChecked(exportedMapped))
        XCTAssertEqual(selection.order, [SimpleWorkspace.selectionKey(exportedMapped), SimpleWorkspace.selectionKey(exportedUnmatched)])
        XCTAssertEqual(selection.statuses[SimpleWorkspace.selectionKey(exportedMapped)], .done)
        XCTAssertEqual(selection.statuses[SimpleWorkspace.selectionKey(exportedUnmatched)], .askQuestion)
        XCTAssertEqual(content.chosenPassages.count, 2, "Only qualifying source-only passages should become literal passage records")
        XCTAssertTrue(content.chosenPassages.contains { $0.title.contains("onzeker") })
        XCTAssertTrue(content.chosenPassages.contains { $0.title.contains("nog niet beoordeeld") })
        XCTAssertTrue(content.chosenPassages.contains { Data($0.text.utf8).elementsEqual(Data(uncertainPassage.text.utf8)) })
        XCTAssertTrue(content.chosenPassages.contains { Data($0.text.utf8).elementsEqual(Data(unassessedPassage.text.utf8)) })
        let generatedSourceQuotes = content.chosenPassages.flatMap(\.sources).map(\.quote)
        for source in uncertainPassage.sources + unassessedPassage.sources {
            XCTAssertTrue(generatedSourceQuotes.contains { Data($0.utf8).elementsEqual(Data(source.quote.utf8)) })
        }
        XCTAssertEqual(content.chosenPassages.first(where: { Data($0.text.utf8).elementsEqual(Data(uncertainPassage.text.utf8)) })?.note,
                       "De bron noemt deze passage.")
        XCTAssertTrue(content.context.contains("Commissiebereik: Bestuur"))
        XCTAssertTrue(content.context.contains("onzeker"))
        XCTAssertTrue(content.context.contains("nog niet beoordeeld"))
        XCTAssertTrue(content.context.contains("1 punt kon niet veilig"))
        XCTAssertFalse(content.context.contains("AI-reden:"))
        XCTAssertEqual(content.committeeLabels[mappedKey], "Commissiebeoordeling: belangrijk")
        XCTAssertEqual(content.committeeLabels[unmatchedKey], "Niet veilig gekoppeld aan commissiepassage · controleer bron")
        XCTAssertEqual(content.notice, "Oorspronkelijke waarschuwing")
    }

    func testCommitteeScopeLabelsExplicitGeneralComponentsAsDocumentWide() throws {
        let pages = ["Een commissiepassage."]
        let passage = try XCTUnwrap(PassageEngine.passages(pages).first)
        let review = CommitteeAssessmentService.Review(purpose: .leefomgeving, model: "model",
                                                       inputKey: "key", entries: [assessment(passage, rating: .relevant)],
                                                       issues: [], complete: true)
        let summary = DocumentSummary(digest: DocumentDigest(overview: "Algemeen", bullets: []), sections: [])
        var configuration = ExportConfiguration()
        configuration.committeePurpose = .leefomgeving
        configuration.summary = true
        let content = makeContent(configuration: configuration, pages: pages, insights: [],
                                  review: review, summary: summary)

        XCTAssertEqual(content.summary?.digest.overview, "Algemeen")
        XCTAssertTrue(content.summaryScope.contains("Hele document"))
        XCTAssertTrue(content.context.contains("Documentbrede onderdelen (niet beperkt tot deze commissie)"))
        XCTAssertTrue(content.context.contains("documentsamenvatting"))
        XCTAssertFalse(content.context.contains("AI-reden:"))
    }

    func testBriefingPDFPrintsCommitteeLabelWithoutChangingPointIdentityOrAnnotation() throws {
        let point = Insight(title: "Oorspronkelijke titel", summary: "Korte puntsamenvatting.", relevance: "",
                            question: "", quote: "Letterlijk citaat.", page: 1,
                            passageID: "committee-source-passage",
                            passageSources: [.init(page: 1, quote: "De volledige oorspronkelijke alinea.")])
        let selectionKey = SimpleWorkspace.selectionKey(point)
        let annotation = PointAnnotation(note: "Eigen notitie blijft behouden.", checkedSignature: PointAnnotation.signature(point))
        var configuration = ExportConfiguration()
        configuration.summary = false
        configuration.selectedPoints = true
        configuration.selectedQuestions = false
        configuration.pagePoints = true
        configuration.politics = false
        configuration.questions = false
        configuration.notes = true
        configuration.tables = false
        configuration.glossary = false
        configuration.sources = false
        let document = OpenPDF(name: "Commissietest.pdf", data: Data(), pages: [], findings: [])
        let pdfData = try BriefingPDF.data(
            document: document, insights: [point], analyzed: true, neutral: true,
            configuration: configuration, selectedIDs: [selectionKey], selectedOrder: [selectionKey],
            selectionStatuses: [selectionKey: .done], annotations: [selectionKey: annotation],
            committeeLabels: [selectionKey: "Commissiebeoordeling: onzeker · controleer bron"])
        let pdf = try XCTUnwrap(PDFDocument(data: pdfData))
        let renderedText = try XCTUnwrap(pdf.string)

        XCTAssertTrue(renderedText.contains("Commissiebeoordeling: onzeker"))
        XCTAssertTrue(renderedText.contains("Eigen notitie blijft behouden."))
        XCTAssertTrue(renderedText.contains("Afgehandeld"))
        XCTAssertEqual(SimpleWorkspace.selectionKey(point), selectionKey)
        XCTAssertTrue(annotation.isChecked(point))
    }

    func testOlderExportConfigurationWithoutCommitteeScopeDecodesAsFullDocument() throws {
        let oldJSON = #"{"summary":true,"pagePoints":true,"politics":true,"questions":true,"glossary":true,"includeTables":true,"includeNotes":true,"includeChosenPassages":true,"sources":true,"selectedPoints":false,"selectedQuestions":false}"#
        let configuration = try JSONDecoder().decode(ExportConfiguration.self, from: Data(oldJSON.utf8))
        XCTAssertNil(configuration.committeePurpose)
        XCTAssertEqual(ExportPreset.matching(configuration)?.rawValue, ExportPreset.fullDossier.rawValue)
    }
}
