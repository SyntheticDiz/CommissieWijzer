import Foundation

/// Immutable export snapshot content for whole-document, selection, and
/// committee scopes. Whole-document inputs are returned byte-for-byte as given.
struct ScopedExportContent: Sendable {
    let insights: [Insight]
    let chosenPassages: [ChosenPassage]
    let summary: DocumentSummary?
    let summaryScope: String
    let tables: [DocumentTable]
    let glossary: [ExportGlossaryItem]
    let notice: String
    let context: String
    let neutralAnalysis: Bool
    let committeeLabels: [String: String]

    init(insights: [Insight], chosenPassages: [ChosenPassage], summary: DocumentSummary?,
         summaryScope: String, tables: [DocumentTable], glossary: [ExportGlossaryItem],
         notice: String, context: String, neutralAnalysis: Bool,
         committeeLabels: [String: String] = [:]) {
        self.insights = insights
        self.chosenPassages = chosenPassages
        self.summary = summary
        self.summaryScope = summaryScope
        self.tables = tables
        self.glossary = glossary
        self.notice = notice
        self.context = context
        self.neutralAnalysis = neutralAnalysis
        self.committeeLabels = committeeLabels
    }

    static func make(configuration: ExportConfiguration, pages: [String], insights: [Insight],
                     review: CommitteeAssessmentService.Review?, summary: DocumentSummary?,
                     summaryScope: String, tables: [DocumentTable], chosenPassages: [ChosenPassage],
                     glossary: [ExportGlossaryItem], notice: String, context: String,
                     neutralAnalysis: Bool) -> ScopedExportContent {
        guard let purpose = configuration.committeePurpose else {
            return ScopedExportContent(insights: insights, chosenPassages: chosenPassages,
                                       summary: summary, summaryScope: summaryScope, tables: tables,
                                       glossary: glossary, notice: notice, context: context,
                                       neutralAnalysis: neutralAnalysis)
        }

        guard let review, review.purpose == purpose,
              CommitteeAssessmentService.validateSources(review, pages: pages) else {
            return ScopedExportContent(insights: [], chosenPassages: configuration.chosenPassages ? chosenPassages : [],
                                       summary: configuration.summary ? summary : nil,
                                       summaryScope: "Hele document", tables: configuration.tables ? tables : [],
                                       glossary: configuration.glossary ? glossary : [], notice: notice,
                                       context: committeeContext(purpose: purpose, original: context,
                                                                 generalComponents: generalComponents(configuration: configuration,
                                                                                                      summary: summary,
                                                                                                      tables: tables,
                                                                                                      glossary: glossary)),
                                       neutralAnalysis: neutralAnalysis)
        }

        let presentation = CommitteePointPresentation(review: review, points: insights)
        let passages = Dictionary(uniqueKeysWithValues: PassageEngine.passages(pages).map { ($0.id, $0) })
        var scopedInsights: [Insight] = []
        var committeeLabels = [String: String]()
        var generatedSourceOnly = [ChosenPassage]()
        for row in presentation.rows where row.assessment.rating != .other {
            if row.points.isEmpty {
                guard let sourcePassage = passages[row.assessment.passageID] else { continue }
                let text = sourcePassage.text
                generatedSourceOnly.append(ChosenPassage(
                    id: stablePassageUUID(row.assessment.passageID),
                    title: "Commissiebeoordeling: \(ratingTitle(row.assessment.rating)) · volledige bronpassage",
                    note: row.assessment.reason,
                    text: text,
                    pages: sourcePassage.sources.map(\.page),
                    sources: row.assessment.sources.map { .init(page: $0.page, quote: $0.quote) }))
            } else {
                scopedInsights += row.points
                let label = ratingLabel(row.assessment.rating)
                for point in row.points { committeeLabels[SimpleWorkspace.selectionKey(point)] = label }
            }
        }
        scopedInsights += presentation.unmatchedPoints
        for point in presentation.unmatchedPoints {
            committeeLabels[SimpleWorkspace.selectionKey(point)] = "Niet veilig gekoppeld aan commissiepassage · controleer bron"
        }

        let configuredPassages = configuration.chosenPassages ? chosenPassages : []
        let allPassages = configuredPassages + generatedSourceOnly.filter { generated in
            !configuredPassages.contains(where: { sameLiteralPassage($0, generated) })
        }
        let global = generalComponents(configuration: configuration, summary: summary,
                                       tables: tables, glossary: glossary)
        let scopedSummary = configuration.summary ? summary : nil
        let hasGlobal = !global.isEmpty
        let scopeContext = "Commissiebereik: \(purpose.title). De puntenlijst bevat alleen passages met een bestaande beoordeling anders dan ‘anders’, veilig gekoppelde punten en apart herkenbare niet-gekoppelde punten."
        func count(_ rating: CommitteeAssessmentService.Rating) -> Int {
            review.entries.filter { $0.rating == rating }.count
        }
        let ratingContext = "Commissiebeoordeling per alinea (AI-oordeel; controleer aan de bron): " +
            "\(count(.important)) belangrijk, \(count(.relevant)) relevant, \(count(.uncertain)) onzeker, " +
            "\(count(.unassessed)) nog niet beoordeeld; \(count(.other)) passages met ‘anders’ niet opgenomen."
        let unmatchedContext: String? = {
            let count = presentation.unmatchedPoints.count
            guard count > 0 else { return nil }
            return count == 1
                ? "1 punt kon niet veilig aan een beoordeelde passage worden gekoppeld; de inhoud blijft ongewijzigd en is apart gelabeld."
                : "\(count) punten konden niet veilig aan een beoordeelde passage worden gekoppeld; hun inhoud blijft ongewijzigd en is apart gelabeld."
        }()
        let fullContext = [context, scopeContext, ratingContext, unmatchedContext,
                           hasGlobal ? "Documentbrede onderdelen (niet beperkt tot deze commissie): " + global.joined(separator: ", ") + "." : nil]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return ScopedExportContent(insights: scopedInsights, chosenPassages: allPassages,
                                   summary: scopedSummary,
                                   summaryScope: scopedSummary == nil ? summaryScope : "Hele document (commissiepuntselectie elders)",
                                   tables: configuration.tables ? tables : [],
                                   glossary: configuration.glossary ? glossary : [],
                                   notice: notice, context: fullContext,
                                   neutralAnalysis: neutralAnalysis, committeeLabels: committeeLabels)
    }

    private static func generalComponents(configuration: ExportConfiguration, summary: DocumentSummary?,
                                          tables: [DocumentTable], glossary: [ExportGlossaryItem]) -> [String] {
        var result = [String]()
        if configuration.summary, summary != nil { result.append("documentsamenvatting") }
        if configuration.tables, !tables.isEmpty { result.append("tabeluitleg") }
        if configuration.glossary, !glossary.isEmpty { result.append("afkortingen en definities") }
        return result
    }

    private static func committeeContext(purpose: MeetingPurpose, original: String,
                                         generalComponents: [String]) -> String {
        let prefix = "Commissiebereik: \(purpose.title). Er is geen actuele, bronvalide beoordeling beschikbaar; de commissiepuntenlijst is daarom leeg."
        let global = generalComponents.isEmpty ? nil : "Documentbrede onderdelen (niet beperkt tot deze commissie): " + generalComponents.joined(separator: ", ") + "."
        return [original, prefix, global].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private static func stablePassageUUID(_ passageID: String) -> UUID {
        let bytes = Array(LocalCache.key(["committee-export-passage", passageID]).utf8.prefix(32))
        let hex = String(bytes: bytes, encoding: .utf8) ?? "00000000000000000000000000000000"
        let chars = Array(hex)
        let raw = (0..<16).map { index -> UInt8 in
            let high = UInt8(chars[index * 2].hexDigitValue ?? 0)
            let low = UInt8(chars[index * 2 + 1].hexDigitValue ?? 0)
            return (high << 4) | low
        }
        return UUID(uuid: (raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7],
                           raw[8], raw[9], raw[10], raw[11], raw[12], raw[13], raw[14], raw[15]))
    }

    private static func sameLiteralPassage(_ lhs: ChosenPassage, _ rhs: ChosenPassage) -> Bool {
        lhs.pages == rhs.pages && Data(lhs.text.utf8).elementsEqual(Data(rhs.text.utf8)) &&
            lhs.sources.count == rhs.sources.count && zip(lhs.sources, rhs.sources).allSatisfy { a, b in
                a.page == b.page && Data(a.quote.utf8).elementsEqual(Data(b.quote.utf8))
            }
    }

    private static func ratingTitle(_ rating: CommitteeAssessmentService.Rating) -> String {
        switch rating {
        case .important: "belangrijk"
        case .relevant: "relevant"
        case .uncertain: "onzeker"
        case .unassessed: "nog niet beoordeeld"
        case .other: "anders"
        }
    }

    private static func ratingLabel(_ rating: CommitteeAssessmentService.Rating) -> String {
        switch rating {
        case .important: "Commissiebeoordeling: belangrijk"
        case .relevant: "Commissiebeoordeling: relevant"
        case .uncertain: "Commissiebeoordeling: onzeker · controleer bron"
        case .unassessed: "Commissiebeoordeling: nog niet beoordeeld · controleer bron"
        case .other: "Commissiebeoordeling: anders"
        }
    }
}
