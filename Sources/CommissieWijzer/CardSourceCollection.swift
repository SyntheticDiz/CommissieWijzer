import Foundation

/// A source shown in the card reader, retaining its source role and only a page
/// that is explicitly known for that text.
struct CardSourceEntry: Equatable, Sendable {
    let text: String
    let page: Int?
    var roles: [String]
}

/// Collects source text from card fields in display order. Only byte-for-byte
/// identical text with the same page is merged; distinct quotations remain
/// distinct even when they point to the same page.
struct CardSourceCollection: Equatable, Sendable {
    private(set) var entries: [CardSourceEntry] = []

    mutating func append(_ text: String, page: Int?, role: String) {
        guard !text.isEmpty else { return }
        if let index = entries.firstIndex(where: { $0.text.utf8.elementsEqual(text.utf8) && $0.page == page }) {
            if !entries[index].roles.contains(role) { entries[index].roles.append(role) }
        } else {
            entries.append(CardSourceEntry(text: text, page: page, roles: [role]))
        }
    }

    mutating func append(_ sources: [Insight.Source], role: String) {
        for source in sources { append(source.quote, page: source.page, role: role) }
    }

    static func forCard(_ point: Insight, committeeContextSources: [Insight.Source] = [],
                        committeeEvidence: String? = nil) -> CardSourceCollection {
        var collection = CardSourceCollection()
        if !point.quote.isEmpty { collection.append(point.quote, page: point.page, role: "Geselecteerde passage") }
        collection.append(point.otherSources ?? [], role: "Andere bronpassages")
        collection.append(point.passageSources ?? [], role: "Volledige alinea")
        collection.append(point.contextSources ?? [], role: "Contextbronnen")
        collection.append(committeeContextSources, role: "Commissiecontext")
        if let evidence = committeeEvidence, !evidence.isEmpty {
            collection.append(evidence, page: nil, role: "Onderbouwend citaat")
        }
        if let program = point.programSource, !program.isEmpty {
            collection.append(program, page: nil, role: "Bron in partijprogramma")
        }
        return collection
    }
}
