import Foundation
import XCTest
@testable import CommissieWijzer

@MainActor
final class AnalysisCompletionLifecycleTests: XCTestCase {
    func testNotificationFollowsAllAnalysisPhasesExactlyOnce() async throws {
        let events = LifecycleEvents()
        let workspace = makeWorkspace(events: events)

        workspace.analyze(model: "fixture-model", context: "", compareProgram: true)
        try await waitUntil { !workspace.busy }
        try await waitUntil { events.posts.count == 1 }

        XCTAssertEqual(events.prepares, 1)
        XCTAssertEqual(events.events, ["prepare", "points", "summary", "highlights", "post"])
        XCTAssertEqual(events.posts.map { $0.1 }, [.completed])
    }

    func testCancellationInvalidatesInFlightCompletion() async throws {
        let events = LifecycleEvents()
        let workspace = makeWorkspace(events: events)
        workspace.collectHighlights = { _, _, _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return KeyPointService.Report(points: [], issues: [])
        }

        workspace.analyze(model: "fixture-model", context: "", compareProgram: true)
        try await waitUntil { workspace.analysisPhase == .highlights }
        workspace.cancelAnalysis()
        try await waitUntil { !workspace.busy }
        await Task.yield()

        XCTAssertEqual(events.prepares, 1)
        XCTAssertTrue(events.posts.isEmpty)
        XCTAssertEqual(events.cancellations.count, 1)
    }

    func testReplacingDocumentCancelsCompletionWaitingForAuthorization() async throws {
        let events = LifecycleEvents()
        var finishPost: CheckedContinuation<Void, Never>?
        let workspace = makeWorkspace(events: events, postCompletion: { id, outcome in
            events.events.append("post-start")
            await withCheckedContinuation { finishPost = $0 }
            guard !events.cancellations.contains(id) else { return }
            events.posts.append((id, outcome))
        })

        workspace.analyze(model: "fixture-model", context: "", compareProgram: true)
        try await waitUntil { events.events.contains("post-start") }
        workspace.documentID = UUID()
        finishPost?.resume()
        await Task.yield()

        XCTAssertTrue(events.posts.isEmpty)
        XCTAssertEqual(events.cancellations.count, 1)
    }

    func testImportOnlyAndNoWorkResumeDoNotPrepareOrPost() async throws {
        let events = LifecycleEvents()
        let workspace = makeWorkspace(events: events)
        workspace.resumeMissing()
        await Task.yield()
        XCTAssertTrue(events.events.isEmpty)

        // Loading without a model performs PDF import only and must not request
        // notification permission or announce an analysis completion.
        let pdf = try BriefingPDF.data(document: workspace.document!, insights: [], analyzed: false, title: "Fixture")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.write(to: url)
        let importOnly = makeWorkspace(events: events)
        let task = try XCTUnwrap(importOnly.load([url], model: nil))
        await task.value

        XCTAssertTrue(events.events.isEmpty)
        XCTAssertTrue(events.posts.isEmpty)
    }

    private func makeWorkspace(events: LifecycleEvents,
                               postCompletion: SimpleWorkspace.AnalysisNotificationPost? = nil) -> SimpleWorkspace {
        let workspace = SimpleWorkspace(
            prepareAnalysisNotification: { events.events.append("prepare"); events.prepares += 1 },
            postAnalysisNotification: postCompletion ?? { id, outcome in
                events.events.append("post")
                events.posts.append((id, outcome))
            },
            cancelAnalysisNotification: { id in events.cancellations.append(id) })
        workspace.document = OpenPDF(name: "Fixture.pdf", data: Data(), pages: ["Een voorstel over woningen."], findings: [])
        workspace.loadProgram = { PartyProgram(name: "Programma", pages: ["Woningen"], pdf: Data()) }
        workspace.compareDocument = { pages, _, _, _, update, _, progress in
            await progress(1, 1)
            await update([Insight(title: "Woningen", summary: "Voorstel", relevance: "", question: "",
                                  quote: pages[0], page: 1)])
            await MainActor.run { events.events.append("points") }
            return [Insight(title: "Woningen", summary: "Voorstel", relevance: "", question: "",
                            quote: pages[0], page: 1)]
        }
        workspace.summarizeDocument = { _, _ , _ in
            await MainActor.run { events.events.append("summary") }
            return DocumentSummary(digest: .init(overview: "Samenvatting", bullets: []), sections: [])
        }
        workspace.collectHighlights = { _, _, _ in
            await MainActor.run { events.events.append("highlights") }
            return KeyPointService.Report(points: [], issues: [])
        }
        return workspace
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<2_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for the analysis lifecycle.")
    }
}

@MainActor
private final class LifecycleEvents {
    var events: [String] = []
    var prepares = 0
    var posts: [(UUID, AnalysisCompletionOutcome)] = []
    var cancellations: [UUID] = []
}
