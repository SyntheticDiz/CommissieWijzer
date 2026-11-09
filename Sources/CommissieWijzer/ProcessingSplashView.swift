import SwiftUI

struct ProcessingSplashView: View {
    @ObservedObject var workspace: SimpleWorkspace
    var onReturnToImport: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var completed: Bool { !workspace.busy && workspace.processingMessage == nil }
    private var presentation: ProcessingPresentation {
        ProcessingPresentation(
            status: workspace.status,
            busy: workspace.busy,
            completed: completed,
            documentReady: workspace.processingDocumentReady || !workspace.busy,
            documentPresent: workspace.document != nil,
            documentIssue: workspace.status.hasPrefix("Pdf inladen mislukt") ||
                (workspace.processingMessage != nil && workspace.document == nil),
            pointsReady: workspace.analyzed && workspace.analysisState != .running,
            pointsIssue: [.needsProgram, .incomplete, .failed, .cancelled].contains(workspace.analysisState) || !workspace.citationWarning.isEmpty,
            summaryReady: workspace.documentSummary != nil,
            summaryIssue: workspace.summaryError != nil,
            highlightsReady: workspace.keyPointsReady,
            highlightsIssue: !workspace.keyPointIssues.isEmpty,
            committeeIncluded: workspace.meetingPurpose != .raad,
            committeeActive: workspace.importCommitteeReviewActive,
            committeeReady: workspace.committeeReviews[workspace.meetingPurpose.rawValue]?.complete == true,
            committeeIssue: workspace.committeeReviewError != nil ||
                (workspace.processingDocumentReady && !workspace.committeeReviewBusy && workspace.meetingPurpose != .raad &&
                 workspace.committeeReviews[workspace.meetingPurpose.rawValue]?.complete != true))
    }

    var body: some View {
        VStack(spacing: 24) {
            ProcessingStageIllustration(
                illustration: ProcessingPresentation.Illustration.select(
                    activeStage: presentation.activeStage,
                    status: workspace.status,
                    busy: workspace.busy,
                    comparingPartyProgram: workspace.comparingPartyProgram
                ),
                scanning: workspace.busy,
                completed: completed,
                reduceMotion: reduceMotion
            )
                .frame(width: 190, height: 236)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(workspace.processingName).font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center).lineLimit(3)
                statusDisplay
            }
            stageRow
            if workspace.processingMessage == nil {
                VStack(spacing: 10) {
                    ProgressView(value: workspace.busy ? workspace.progress.fraction : 1)
                        .tint(.secondary)
                        .accessibilityLabel(UIStrings.text("Voortgang") + ": " + UIStrings.text(presentation.primaryStatus))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: workspace.progress.fraction)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: completed)
                    HStack {
                        Text("\(workspace.busy ? workspace.progress.percent : 100)%").monospacedDigit()
                        Spacer()
                        if workspace.busy { Text(UIStrings.text(workspace.progress.remaining())) }
                    }.font(.callout).foregroundStyle(.secondary)
                }
            }
            if workspace.busy {
                if let count = progressCount {
                    Text(UIStrings.text(count)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                busyActions
            } else if completed {
                // Reserve the action's space so completion does not move the illustration.
                busyActions.hidden().accessibilityHidden(true)
            } else if let message = workspace.processingMessage {
                ScrollView {
                    Text(message.components(separatedBy: "\n").map { UIStrings.text($0) }.joined(separator: "\n")).font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(maxHeight: 140)
                errorActions
            }
            details
        }
        .frame(maxWidth: 460)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private var stageRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { ForEach(presentation.stages, id: \.self) { stage in stageItem(stage).fixedSize(horizontal: true, vertical: false) } }
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    stageItem(.document)
                    if workspace.meetingPurpose != .raad { stageItem(.committee) }
                    stageItem(.points)
                }
                HStack(spacing: 10) { stageItem(.summary); stageItem(.highlights) }
            }
        }
        .font(.caption2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var statusDisplay: some View {
        #if os(macOS)
        statusText.frame(height: 44)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: presentation.primaryStatus)
        #else
        statusText.frame(minHeight: 44)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: presentation.primaryStatus)
        #endif
    }

    private var statusText: some View {
        ZStack {
            Text(UIStrings.text(presentation.primaryStatus) + (presentation.activeStage == .committee ? " · " + UIStrings.text(workspace.meetingPurpose.title) : "")).id(presentation.primaryStatus)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).transition(.opacity)
        }
    }

    private var busyActions: some View {
        let openResults: (() -> Void)? = workspace.processingDocumentReady ? { workspace.showInterimResults() } : nil
        let switchModel: (() -> Void)? = workspace.canSwitchChatGPTModel ? { workspace.presentChatGPTModelSwitch() } : nil
        return ProcessingActions(
            returnTitle: workspace.processingDocumentReady ? "Stop en terug naar importeren" : "Annuleer import",
            onReturnToImport: onReturnToImport,
            onOpenResults: openResults,
            onSwitchModel: switchModel
        )
    }

    private var errorActions: some View {
        let canOpenResults = !workspace.showsWelcome && workspace.document != nil
        let openResults: (() -> Void)? = canOpenResults ? { workspace.showProcessedResults() } : nil
        return ProcessingActions(
            returnTitle: "Terug naar importeren",
            onReturnToImport: onReturnToImport,
            onOpenResults: openResults
        )
    }

    private func stageItem(_ stage: ProcessingPresentation.Stage) -> some View {
        let state = presentation.stageStates[stage] ?? .pending
        let symbol: String
        let label: String
        switch state {
        case .ready: symbol = "checkmark.circle.fill"; label = "Gereed"
        case .active: symbol = "circle.dashed"; label = "Bezig"
        case .issue: symbol = "exclamationmark.circle.fill"; label = "Aandacht"
        case .pending: symbol = "circle"; label = "Wacht"
        }
        return VStack(spacing: 2) {
            Label(UIStrings.text(stage.rawValue), systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .foregroundStyle(state == .issue ? Color.orange : state == .active ? Color.primary : Color.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(UIStrings.text(label)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(UIStrings.text(stage.rawValue) + ": " + UIStrings.text(label))
    }

    private var progressCount: String? {
        guard workspace.progress.phaseTotal > 0 else { return nil }
        let unit = workspace.progress.isMergingSummary ? "samenvoegingen" : "stappen"
        return "\(workspace.progress.phaseCompleted) van \(workspace.progress.phaseTotal) \(unit) gereed"
    }

    private var details: some View {
        DisclosureGroup(UIStrings.text("Details")) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 5) {
                    if !workspace.activeModel.isEmpty {
                        Text(UIStrings.text(AIConfiguration.label(workspace.activeModel)))
                    }
                    if workspace.importCommitteeReviewActive {
                        Text(UIStrings.text("Commissievoorbereiding") + " · " + UIStrings.text(workspace.meetingPurpose.title))
                    }
                    if let phase = workspace.analysisPhase {
                        Text(UIStrings.text("Huidige AI-fase: \(phase.title)"))
                    }
                    Text(UIStrings.text("Verstreken \(elapsed(now: context.date)) · \(requestStatus)"))
                    Text(UIStrings.text(workspace.status)).textSelection(.enabled)
                }
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.caption)
    }

    private func elapsed(now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(workspace.progress.started)))
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private var requestStatus: String {
        let progress = workspace.progress
        guard workspace.busy else { return completed ? "Verwerking afgerond" : "Verwerking vraagt aandacht" }
        return progress.phaseTotal > 0 && progress.phaseCompleted >= progress.phaseTotal
            ? "Aanvraagfase afronden" : "Wachten op of verwerken van aanvraag"
    }
}

struct ProcessingActions: View {
    let returnTitle: String
    let onReturnToImport: () -> Void
    let onOpenResults: (() -> Void)?
    let onSwitchModel: (() -> Void)?
    private let spacing: CGFloat = 12

    init(returnTitle: String, onReturnToImport: @escaping () -> Void,
         onOpenResults: (() -> Void)? = nil, onSwitchModel: (() -> Void)? = nil) {
        self.returnTitle = returnTitle
        self.onReturnToImport = onReturnToImport
        self.onOpenResults = onOpenResults
        self.onSwitchModel = onSwitchModel
    }

    var body: some View {
        VStack(spacing: spacing) {
            if let onOpenResults {
                Button(action: onOpenResults) {
                    actionLabel("Open document en resultaten")
                }
                .buttonStyle(FocusPrimaryButtonStyle())
            }
            if let onSwitchModel {
                ViewThatFits(in: .horizontal) {
                    EqualWidthActionRow(spacing: spacing) {
                        secondaryActions(onSwitchModel: onSwitchModel)
                    }
                    VStack(spacing: spacing) {
                        secondaryActions(onSwitchModel: onSwitchModel)
                    }
                }
            } else {
                returnButton
            }
        }
        .controlSize(.large)
    }

    @ViewBuilder private func secondaryActions(onSwitchModel: @escaping () -> Void) -> some View {
        returnButton
        Button(action: onSwitchModel) {
            actionLabel("Wissel AI-model…")
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private var returnButton: some View {
        Button(action: onReturnToImport) {
            actionLabel(returnTitle)
        }
        .buttonStyle(FocusSecondaryButtonStyle())
    }

    private func actionLabel(_ title: String) -> some View {
        Text(UIStrings.text(title))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

private struct EqualWidthActionRow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Both buttons need enough room for the longer label before they can share a row.
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let idealWidth = 2 * (sizes.map(\.width).max() ?? 0) + spacing
        let offeredWidth = proposal.width ?? idealWidth
        return CGSize(width: offeredWidth.isFinite ? max(offeredWidth, idealWidth) : idealWidth,
                      height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = (bounds.width - spacing) / 2
        for (index, subview) in subviews.enumerated() {
            let x = bounds.minX + CGFloat(index) * (width + spacing)
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
        }
    }
}

struct ProcessingStageIllustration: View {
    let illustration: ProcessingPresentation.Illustration
    let scanning: Bool
    let completed: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ProcessingDocumentIllustration(scanning: scanning && illustration == .document,
                                           completed: completed, reduceMotion: reduceMotion)
                .opacity(illustration == .document ? 1 : 0)
            ProcessingPhaseIllustration(illustration: illustration, active: scanning, reduceMotion: reduceMotion)
                .id(illustration)
                .transition(.opacity)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.secondary.opacity(0.12), lineWidth: 1))
                .opacity(illustration == .document ? 0 : 1)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: illustration)
    }
}

private struct ProcessingPhaseIllustration: View {
    let illustration: ProcessingPresentation.Illustration
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) { timeline in
            Canvas { context, size in
                let phase = active && !reduceMotion
                    ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
                    : 0.5
                draw(illustration, phase: phase, in: &context, size: size)
            }
        }
    }

    private func draw(_ kind: ProcessingPresentation.Illustration, phase: Double,
                      in context: inout GraphicsContext, size: CGSize) {
        let color = Color.secondary
        func rounded(_ rect: CGRect, radius: CGFloat = 3, opacity: Double = 0.28) {
            context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color.opacity(opacity)))
        }
        func stroke(_ rect: CGRect, radius: CGFloat = 8, opacity: Double = 0.27) {
            context.stroke(Path(roundedRect: rect, cornerRadius: radius), with: .color(color.opacity(opacity)), lineWidth: 1.3)
        }
        func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ opacity: Double = 0.25) {
            rounded(CGRect(x: x, y: y, width: w, height: 4), radius: 2, opacity: opacity)
        }
        func beat(_ index: Int, count: Int, offset: Double = 0) -> Double {
            let local = (phase * Double(count) - Double(index) + offset).truncatingRemainder(dividingBy: Double(count))
            return 0.18 + 0.55 * (0.5 + 0.5 * cos(2 * .pi * local / Double(count)))
        }
        func ease(_ value: Double) -> Double { value * value * (3 - 2 * value) }

        switch kind {
        case .committee:
            let centers = [CGPoint(x: 56, y: 75), CGPoint(x: 134, y: 75), CGPoint(x: 95, y: 156)]
            let boxes = centers.map { CGRect(x: $0.x - 20, y: $0.y - 14.5, width: 40, height: 29) }
            var links = Path()
            for (a, b) in [(0, 1), (0, 2), (1, 2)] {
                links.move(to: centers[a]); links.addLine(to: centers[b])
            }
            context.stroke(links, with: .color(color.opacity(0.22)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            boxes.enumerated().forEach { index, rect in
                let emphasis = 0.22 + (0.5 - 0.5 * cos(2 * .pi * (phase - Double(index) * 0.18))) * 0.25
                stroke(rect, radius: 6, opacity: emphasis)
                bar(rect.minX + 9, rect.minY + 7, 22, 0.22 + emphasis * 0.26)
                bar(rect.minX + 9, rect.minY + 18, 15, 0.20)
            }
            let travel = phase * 3
            let leg = Int(travel) % centers.count
            let t = travel - floor(travel)
            let eased = ease(t)
            let a = centers[leg]
            let b = centers[(leg + 1) % centers.count]
            let dot = CGPoint(x: a.x + (b.x - a.x) * eased, y: a.y + (b.y - a.y) * eased)
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 1.5, y: dot.y - 1.5, width: 3, height: 3)), with: .color(color.opacity(0.48 * sin(.pi * t))))
        case .points:
            for row in 0..<5 {
                let y = 56 + CGFloat(row) * 28
                let opacity = active && !reduceMotion ? 0.20 + 0.25 * (0.5 - 0.5 * cos(2 * .pi * (phase - Double(row) * 0.12))) : 0.30
                context.fill(Path(ellipseIn: CGRect(x: 33, y: y + 2, width: 4, height: 4)), with: .color(color.opacity(opacity)))
                bar(44, y, 94, 0.18 + opacity * 0.7)
                bar(44, y + 9, 63, 0.15 + opacity * 0.5)
            }
        case .summary:
            let blend: Double = active && !reduceMotion ? ease(0.5 - 0.5 * cos(2 * .pi * phase)) : 1
            for row in 0..<7 {
                let sourceY = 48 + CGFloat(row) * 17
                let targetY = 75 + CGFloat(row / 3) * 24
                let y = sourceY + (targetY - sourceY) * blend
                let opacity = 0.28 * (1 - blend)
                bar(33, y, row % 3 == 2 ? 108 : 124, opacity)
            }
            for row in 0..<3 {
                let y = 75 + CGFloat(row) * 24
                bar(39, y, 112 - CGFloat(row) * 14, 0.48 * blend)
                bar(39, y + 8, 72 - CGFloat(row) * 9, 0.35 * blend)
            }
        case .highlights:
            for row in 0..<5 {
                let y = 46 + CGFloat(row) * 28
                let chosen = row == 1 || row == 3
                let emphasis = active && !reduceMotion ? 0.5 - 0.5 * cos(2 * .pi * (phase - Double(row) * 0.12)) : 0.5
                if chosen {
                    let band = CGRect(x: 24, y: y - 5, width: 142, height: 19)
                    context.fill(Path(roundedRect: band, cornerRadius: 4), with: .color(color.opacity(0.035 + 0.045 * emphasis)))
                }
                bar(34, y, chosen ? 95 : 110, chosen ? 0.30 + 0.17 * emphasis : 0.20)
                bar(34, y + 8, chosen ? 66 : 78, 0.18)
            }
        case .partyComparison:
            let left = CGRect(x: 22, y: 67, width: 63, height: 94)
            let right = CGRect(x: 105, y: 67, width: 63, height: 94)
            stroke(left, radius: 8); stroke(right, radius: 8)
            for row in 0..<4 {
                let match = row == 1 || row == 3
                let pulse = active && !reduceMotion ? 0.5 + 0.5 * sin(phase * 2 * .pi) : 0.5
                let op = match ? 0.30 + 0.18 * (row == 1 ? pulse : 1 - pulse) : 0.20
                bar(31, 84 + CGFloat(row) * 16, row == 2 ? 36 : 44, op)
                bar(114, 84 + CGFloat(row) * 16, row == 1 ? 36 : 44, op)
                let y = 88 + CGFloat(row) * 16
                var connector = Path(); connector.move(to: CGPoint(x: 80, y: y)); connector.addLine(to: CGPoint(x: 110, y: y))
                context.stroke(connector, with: .color(color.opacity(op * 0.65)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        case .document:
            break
        }
    }
}

private struct ProcessingDocumentIllustration: View {
    let scanning: Bool
    let completed: Bool
    let reduceMotion: Bool
    @State private var unfolded = false
    @State private var started = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || !scanning)) { timeline in
            Canvas { context, size in
                let inset: CGFloat = 26
                let elapsed = max(0, timeline.date.timeIntervalSince(started))
                let cycle = max(0, elapsed - 0.85).truncatingRemainder(dividingBy: 4.8) / 4.8
                let pass = min(1, cycle / 0.8)
                let eased = pass * pass * (3 - 2 * pass)
                let scanY = 28 + (size.height - 56) * eased
                let scanningNow = scanning && !reduceMotion && elapsed > 0.85 && cycle < 0.8
                let scanOpacity = min(1, min(pass * 10, (1 - pass) * 10))
                for row in 0..<10 {
                    let width = (row == 3 || row == 7) ? size.width * 0.48 : size.width - inset * 2
                    let y = 38 + CGFloat(row) * 16
                    let reveal = reduceMotion || completed ? 1 : min(1, max(0, (elapsed - 0.15 - Double(row) * 0.04) / 0.24))
                    let smoothReveal = reveal * reveal * (3 - 2 * reveal)
                    let emphasis = scanningNow ? max(0, 1 - abs(y - scanY) / 32) * scanOpacity : 0
                    let rect = CGRect(x: inset, y: y, width: width * smoothReveal, height: 4)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(.secondary.opacity((0.22 + emphasis * 0.3) * smoothReveal)))
                }
                if scanningNow {
                    // A small gradient gives a soft glow without a full-screen blur or redraw.
                    let glow = CGRect(x: 18, y: scanY - 12, width: size.width - 36, height: 24)
                    context.fill(Path(roundedRect: glow, cornerRadius: 8), with: .linearGradient(
                        Gradient(colors: [.clear, .secondary.opacity(0.12 * scanOpacity), .clear]),
                        startPoint: CGPoint(x: 0, y: scanY - 12), endPoint: CGPoint(x: 0, y: scanY + 12)))
                    let line = CGRect(x: 18, y: scanY, width: size.width - 36, height: 1.5)
                    context.fill(Path(roundedRect: line, cornerRadius: 0.75), with: .color(.secondary.opacity(0.55 * scanOpacity)))
                }
            }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.secondary.opacity(0.12), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .medium)).foregroundStyle(.secondary)
                .background(AppTheme.surface, in: Circle())
                .padding(14).scaleEffect(completed ? 1 : 0.85).opacity(completed ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: completed)
        }
        .rotation3DEffect(.degrees(unfolded ? 0 : -45), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.3)
        .opacity(unfolded ? 1 : 0)
        .onAppear {
            started = Date()
            withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.75, 0.25, 1, duration: 0.75)) { unfolded = true }
        }
    }
}
