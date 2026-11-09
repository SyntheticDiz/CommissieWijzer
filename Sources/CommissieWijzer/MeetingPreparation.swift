import Foundation
import PDFKit

enum MeetingQuestionStatus: String, Codable, CaseIterable, Sendable {
    case toAsk
    case answered
    case followUp

    var title: String {
        switch self {
        case .toAsk: "Nog stellen"
        case .answered: "Beantwoord"
        case .followUp: "Opvolgen"
        }
    }
}

/// A snapshot of the PDF source at the time of approval. It survives
/// changing the analysis or removing the original item from Mijn selectie.
struct MeetingQuestionSource: Codable, Sendable, Equatable {
    let title: String
    let excerpt: String
    let pages: [ChosenPassage.Source]

    init(title: String, excerpt: String, pageNumbers: [Int], citations: [ChosenPassage.Source]) {
        self.title = title
        self.excerpt = excerpt
        var seen = Set<Int>()
        let uniquePages = pageNumbers.filter { seen.insert($0).inserted }
        self.pages = uniquePages.map { page in
            citations.first { $0.page == page && !$0.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                ?? .init(page: page, quote: uniquePages.count == 1 ? excerpt : "")
        }
    }

    init(selection: SelectedPDFText) {
        self.init(title: "Gekozen passage", excerpt: selection.text, pageNumbers: selection.pages, citations: selection.sources)
    }

    init(passage: ChosenPassage) {
        let title = passage.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(title: title.isEmpty ? "Gekozen passage" : title,
                  excerpt: passage.text, pageNumbers: passage.pages, citations: passage.sources)
    }

    init(point: Insight) {
        let full = (point.passageSources ?? []).map { ChosenPassage.Source(page: $0.page, quote: $0.quote) }
        let other = (point.otherSources ?? []).map { ChosenPassage.Source(page: $0.page, quote: $0.quote) }
        let primary = ChosenPassage.Source(page: point.page, quote: point.quote)
        // Keep the primary point quote available even when a longer passage is known.
        let citations = [primary] + full + other
        let title = point.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let excerpt = full.isEmpty ? ([point.quote] + other.map(\.quote)).filter { !$0.isEmpty }.joined(separator: "\n")
                                   : full.map(\.quote).joined(separator: "\n")
        self.init(title: title.isEmpty ? "Gekozen passage" : title,
                  excerpt: excerpt, pageNumbers: citations.map(\.page), citations: citations)
    }

    /// Use the suggestion's quote only when it resolves to one of the
    /// already selected PDF sources. Otherwise retain the full source.
    func forSuggestion(quote: String) -> Self {
        let matches = pages.filter { Self.hasUniqueMatch(for: quote, in: $0.quote) }
        guard matches.count == 1, let match = matches.first else { return self }
        return Self(title: title, excerpt: quote, pageNumbers: [match.page],
                    citations: [.init(page: match.page, quote: quote)])
    }

    /// Older snapshots and PDFs with a changed text extraction may have only
    /// a usable page reference. Preserve the user's words, but do not highlight
    /// or label a quote as verified unless it matches the stored source page.
    func verifiedQuote(on page: Int, in documentPages: [String]) -> String? {
        guard page > 0, page <= documentPages.count,
              let citation = pages.first(where: { $0.page == page }),
              Self.hasUniqueMatch(for: citation.quote, in: documentPages[page - 1]) else { return nil }
        return citation.quote
    }

    func excerptIsVerified(in documentPages: [String]) -> Bool {
        guard !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if pages.contains(where: { page in
            page.page > 0 && page.page <= documentPages.count &&
                Self.hasUniqueMatch(for: excerpt, in: documentPages[page.page - 1])
        }) { return true }
        let verified = pages.compactMap { verifiedQuote(on: $0.page, in: documentPages) }
        guard !pages.isEmpty, verified.count == pages.count else { return false }
        func words(_ text: String) -> [Substring] { text.split(whereSeparator: \.isWhitespace) }
        return words(excerpt) == words(verified.joined(separator: "\n"))
    }

    func verify(inPDF pdf: Data) -> (quotesForHighlight: [Int: String], excerptIsVerified: Bool) {
        let document = PDFDocument(data: pdf)
        let citedPages = Set(pages.map(\.page))
        let pdfPages = (0..<(document?.pageCount ?? 0)).map { index in
            citedPages.contains(index + 1) ? document?.page(at: index)?.string ?? "" : ""
        }
        let quotes: [Int: String] = Dictionary(uniqueKeysWithValues: citedPages.compactMap { page in
            quoteForHighlight(on: page, in: pdfPages).map { (page, $0) }
        })
        return (quotes, quotes.count == pages.count && excerptIsVerified(in: pdfPages))
    }

    /// The general PDF highlighter takes the first case-insensitive match.
    /// Supply a target only when that match must be the verified occurrence.
    func quoteForHighlight(on page: Int, in pdfPages: [String]) -> String? {
        guard let quote = verifiedQuote(on: page, in: pdfPages),
              Self.hasUniqueMatch(for: quote, in: pdfPages[page - 1], forHighlight: true) else { return nil }
        return quote
    }

    private static func hasUniqueMatch(for quote: String, in page: String, forHighlight: Bool = false) -> Bool {
        let words = quote.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first, let last = words.last?.last else { return false }
        // Preserve word and number boundaries while tolerating PDF line wraps.
        let start = first.isNumber ? #"(?<![\p{L}\p{N}.,])"# : first.isLetter ? #"(?<![\p{L}\p{N}])"# : ""
        let end = last.isNumber ? #"(?![\p{L}\p{N}]|[.,]\d)"# : last.isLetter ? #"(?![\p{L}\p{N}])"# : ""
        let text = words.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: #"\s+"#)
        let pattern = forHighlight ? text : start + text + end
        let options: NSRegularExpression.Options = forHighlight ? [.caseInsensitive] : []
        // The lookahead counts overlapping matches as ambiguous as well.
        guard let regex = try? NSRegularExpression(pattern: "(?=\(pattern))", options: options) else { return false }
        return regex.numberOfMatches(in: page, range: NSRange(page.startIndex..., in: page)) == 1
    }

    func isValid(pageCount: Int) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !pages.isEmpty &&
            Set(pages.map(\.page)).count == pages.count &&
            pages.allSatisfy { $0.page > 0 && $0.page <= pageCount }
    }
}

/// Only questions explicitly approved by the user enter the meeting list.
/// Generated suggestions remain separate and never carry an approved status.
struct MeetingQuestion: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    var question: String
    var answer: String
    var status: MeetingQuestionStatus
    let source: MeetingQuestionSource

    init(id: UUID = UUID(), question: String = "", answer: String = "",
         status: MeetingQuestionStatus = .toAsk, source: MeetingQuestionSource) {
        self.id = id
        self.question = question
        self.answer = answer
        self.status = status
        self.source = source
    }

    static func areValid(_ questions: [MeetingQuestion], pageCount: Int) -> Bool {
        Set(questions.map(\.id)).count == questions.count && questions.allSatisfy {
            !$0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.source.isValid(pageCount: pageCount)
        }
    }
}
