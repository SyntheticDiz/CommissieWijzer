import SwiftUI

/// Controls used by both the workbench and its isolated tutorial example.
struct ProcessingModePicker: View {
    @Binding var compareProgram: Bool
    var disabled = false

    var body: some View {
        Menu {
            Picker(UIStrings.text("Analysemethode"), selection: $compareProgram) {
                Text(UIStrings.text("Neutrale samenvatting")).tag(false)
                Text(UIStrings.text("Vergelijk met partijprogramma")).tag(true)
            }
        } label: {
            Text(UIStrings.text(compareProgram ? "Vergelijk met partijprogramma" : "Neutrale samenvatting"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .focusToolbarMenu()
        .disabled(disabled)
        .accessibilityLabel(UIStrings.text("Analysemethode"))
        .tutorialTarget("mode")
    }
}

struct AnalysisControlRow: View {
    @ObservedObject var workspace: SimpleWorkspace
    let disabled: Bool
    var stopTitle = "Stop analyse"
    var showsCompletionSummary = true
    let action: () -> Void
    var demoRemaining: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                Label(UIStrings.text(workspace.busy ? stopTitle : workspace.canResume ? "Hervat ontbrekende onderdelen" : workspace.analyzed ? "Vernieuw analyse" : "Start analyse"),
                      systemImage: workspace.busy ? "stop.fill" : "play.fill")
            }
            .modifier(GlassActionStyle(prominent: workspace.busy || workspace.canResume || !workspace.analyzed,
                                       size: workspace.busy ? .large : .regular))
            .disabled(disabled)
            .tutorialTarget("start")
            if workspace.canCancelExport {
                Button { workspace.cancelExport() } label: {
                    Label(UIStrings.text("Stop exporteren"), systemImage: "stop.fill")
                }
                .buttonStyle(FocusSecondaryButtonStyle())
                .accessibilityIdentifier("cancel-export")
            }
            if showsCompletionSummary || workspace.busy {
            VStack(alignment: .leading, spacing: 4) {
                Text(UIStrings.text(workspace.completionTitle)).font(.callout.weight(.medium)).lineLimit(2)
                if workspace.busy {
                    ProgressView(value: workspace.progress.fraction).frame(maxWidth: 360)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("≈ \(workspace.progress.percent)% · " + (demoRemaining ?? workspace.progress.remaining(now: context.date)))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                if !workspace.busy && workspace.analyzed {
                    Text("\(workspace.insights.count) " + UIStrings.text("aandachtspunten") + " · \(workspace.keyPoints.count) " + UIStrings.text("kernpunten"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            }
        }
    }
}

struct PDFSelectionActionButton: View {
    let disabled: Bool
    let waitingForAnalysis: Bool
    let action: () -> Void
    var addChosen: (() -> Void)? = nil
    var addDisabled = true
    var alreadyAdded = false
    var draftQuestion: (() -> Void)? = nil
    var draftDisabled = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                summarizeButton
                if let addChosen { chosenButton(addChosen) }
                if let draftQuestion { draftButton(draftQuestion) }
            }.accessibilityIdentifier("selection-actions-inline")
            if addChosen != nil || draftQuestion != nil {
                Menu {
                    summarizeButton
                    if let addChosen { chosenButton(addChosen) }
                    if let draftQuestion { draftButton(draftQuestion) }
                } label: {
                    Label(UIStrings.text(alreadyAdded ? "Opgenomen in Mijn selectie" : "Selectieacties"),
                          systemImage: alreadyAdded ? "checkmark" : "text.quote").foregroundStyle(Color.primary)
                }.focusMenu().accessibilityIdentifier("selection-actions-menu")
            } else {
                summarizeButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("selection-actions-container")
    }

    private var summarizeButton: some View {
        Button(UIStrings.text("Vat selectie samen"), systemImage: "text.alignleft", action: action)
            .buttonStyle(FocusPrimaryButtonStyle())
            .disabled(disabled)
            .help(UIStrings.text(waitingForAnalysis ? "Wacht tot de analyse klaar is of stop deze eerst." : "Vat alleen de geselecteerde tekst samen"))
            .tutorialTarget("selection")
    }

    private func draftButton(_ action: @escaping () -> Void) -> some View {
        Button(UIStrings.text("Vraag opstellen"), systemImage: "questionmark.bubble", action: action)
            .buttonStyle(FocusSecondaryButtonStyle())
            .disabled(draftDisabled)
    }

    private func chosenButton(_ action: @escaping () -> Void) -> some View {
        Button(UIStrings.text(alreadyAdded ? "Opgenomen in Mijn selectie" : "Opnemen in samenvatting"),
               systemImage: alreadyAdded ? "checkmark" : "plus", action: action)
            .buttonStyle(FocusSecondaryButtonStyle())
            .disabled(addDisabled || alreadyAdded)
            .help(UIStrings.text(alreadyAdded ? "Passage staat in Mijn selectie" : "Bewaar deze tekst letterlijk in Mijn selectie"))
            .accessibilityLabel(UIStrings.text(alreadyAdded ? "Opgenomen in Mijn selectie" : "Opnemen in samenvatting"))
    }
}
