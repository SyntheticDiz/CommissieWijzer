import SwiftUI

struct SourceReviewChecklist {
    let unreadablePages: [Int]
    /// Nil means older/incomplete records did not record exact coverage.
    let readableOutsideConfirmedAnalysis: [Int]?
    let analysisNeedsAttention: Bool
    let uncertainTableIDs: [String]
    let unconfirmedOCRTableIDs: [String]
    let checkedPointCount: Int
    let pointCount: Int
    let firstUncheckedPoint: Insight?

    static func make(coverage: DocumentCoverage, analysisNeedsAttention: Bool, points: [Insight],
                     annotation: (Insight) -> PointAnnotation) -> Self {
        let unchecked = points.filter { !annotation($0).isChecked($0) }
        let unreadable = Set(coverage.unreadablePageNumbers)
        let readable = (0..<coverage.totalPages).map { $0 + 1 }.filter { !unreadable.contains($0) }
        return .init(unreadablePages: coverage.unreadablePageNumbers,
            readableOutsideConfirmedAnalysis: coverage.completedAnalysisPageNumbers.map { completed in
                let confirmed = Set(completed)
                return readable.filter { !confirmed.contains($0) }
            },
            analysisNeedsAttention: analysisNeedsAttention,
            uncertainTableIDs: coverage.uncertainTableIDs,
            unconfirmedOCRTableIDs: coverage.unconfirmedOCRTableIDs,
            checkedPointCount: points.count - unchecked.count, pointCount: points.count, firstUncheckedPoint: unchecked.first)
    }
}

struct SourceReviewChecklistView: View {
    @ObservedObject var workspace: SimpleWorkspace
    let showPage: (Int) -> Void
    let showTable: (String) -> Void
    let showPoint: (Insight) -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if expanded {
                ScrollView {
                    checklistContent.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 235)
            }
        } label: {
            Label(UIStrings.text("Checklist broncontrole"), systemImage: "checklist")
                .font(.callout.weight(.semibold))
        }
        .disclosureGroupStyle(FullRowDisclosureGroupStyle())
        .accessibilityIdentifier("source.reviewChecklist")
    }

    private var checklistContent: some View {
        let checklist = SourceReviewChecklist.make(coverage: workspace.documentCoverage,
            analysisNeedsAttention: workspace.baseAnalysisIncomplete, points: workspace.organizedInsights,
            annotation: { workspace.annotation(for: $0) })
        return VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.text("Vergelijk de bewering, het bedrag, de status en de voorwaarden met de oorspronkelijke PDF."))
                .font(.caption).foregroundStyle(.secondary)
            if !checklist.unreadablePages.isEmpty {
                pageTask("Pagina’s zonder leesbare tekst", pages: checklist.unreadablePages)
            }
            if let outside = checklist.readableOutsideConfirmedAnalysis {
                if !outside.isEmpty {
                    pageTask("Leesbare pagina’s buiten de bevestigde analyse", pages: outside)
                    Text(UIStrings.text("Controleer of deze pagina’s bewust buiten je selectie vallen."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                taskLabel("Exacte analyse-dekking is onbekend", symbol: "questionmark.circle")
            }
            if checklist.analysisNeedsAttention {
                taskLabel("Bekijk ontbrekende analyse bij Basisanalyse hieronder.", symbol: "exclamationmark.circle")
            }
            if !checklist.unconfirmedOCRTableIDs.isEmpty {
                tableTask("Afbeeldingstabellen nog te bevestigen", ids: checklist.unconfirmedOCRTableIDs)
            }
            if !checklist.uncertainTableIDs.isEmpty {
                tableTask("Tabellen met onzekere indeling", ids: checklist.uncertainTableIDs)
            }
            if checklist.pointCount > 0 {
                taskLabel(UIStrings.text("Eigen broncontrole bij punten") + " · \(checklist.checkedPointCount)/\(checklist.pointCount)",
                          symbol: "person.crop.circle")
                if let point = checklist.firstUncheckedPoint {
                    Button(UIStrings.text("Open eerste nog te controleren punt")) {
                        showPoint(point)
                    }.buttonStyle(FocusQuietActionStyle())
                }
                Text(UIStrings.text("Zet pas na je eigen vergelijking een vinkje bij Details van het punt."))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                taskLabel("Geen documentpunten voor eigen broncontrole.", symbol: "person.crop.circle")
            }
        }
        .padding(.bottom, 5)
    }

    private func taskLabel(_ title: String, symbol: String) -> some View {
        Label(UIStrings.text(title), systemImage: symbol)
            .font(.caption.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func pageTask(_ title: String, pages: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            taskLabel(UIStrings.text(title) + " · \(pages.count)", symbol: "doc.text")
            if pages.count == 1, let page = pages.first {
                Button(UIStrings.text("PDF-pagina \(page)")) { showPage(page) }
                    .buttonStyle(FocusQuietActionStyle())
            } else {
                Menu {
                    ForEach(pages, id: \.self) { page in
                        Button(UIStrings.text("PDF-pagina \(page)")) { showPage(page) }
                    }
                } label: {
                    Label(UIStrings.text("Open bronpagina"), systemImage: "doc.text.magnifyingglass")
                }.focusMenu()
            }
        }
    }

    private func tableTask(_ title: String, ids: [String]) -> some View {
        let tableTitles = Dictionary(workspace.tables.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 4) {
            taskLabel(UIStrings.text(title) + " · \(ids.count)", symbol: "tablecells")
            if ids.count == 1, let id = ids.first {
                Button(UIStrings.text("Controleer tabel") + " · " + (tableTitles[id] ?? "")) { showTable(id) }
                    .buttonStyle(FocusQuietActionStyle())
            } else {
                Menu {
                    ForEach(ids, id: \.self) { id in
                        Button(tableTitles[id] ?? UIStrings.text("Controleer tabel")) { showTable(id) }
                    }
                } label: {
                    Label(UIStrings.text("Controleer tabel"), systemImage: "tablecells")
                }.focusMenu()
            }
        }
    }
}
