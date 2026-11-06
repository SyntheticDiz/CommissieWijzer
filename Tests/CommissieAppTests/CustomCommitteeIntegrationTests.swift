import Foundation
import XCTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import CommissieWijzer

@MainActor
final class CustomCommitteeIntegrationTests: XCTestCase {
    func testAssessmentAndCategorizationPromptsUseCustomTopicsAndAttentionAndKeysChange() async throws {
        let text = "De gemeente reserveert geld voor betaalbare woningen."
        let purpose = MeetingPurpose(committee: CommitteeDefinition(
            id: "integration-wonen", revision: "r1", name: "Wonen",
            topics: ["betaalbare woningen"], attention: "Controleer de dekking en planning."))
        let recorder = RequestRecorder()
        let categoryID = try XCTUnwrap(purpose.categories.first?.id)
        let request: AIService.Request = { body in
            recorder.append(body)
            let result: [String: Any] = [
                "rating": "important", "reason": "Er is een concreet voorstel.",
                "evidenceQuote": text, "categoryID": categoryID,
                "secondaryCategoryIDs": [String]()
            ]
            let data = try JSONSerialization.data(withJSONObject: result)
            return String(decoding: data, as: UTF8.self)
        }

        let review = try await CommitteeAssessmentService.generateForTesting(
            pages: [text], purpose: purpose, model: "fixture-model", request: request)
        XCTAssertTrue(review.complete)
        let assessmentPrompt = try XCTUnwrap(recorder.bodies.first?[
            "instructions"] as? String)
        XCTAssertTrue(assessmentPrompt.contains("betaalbare woningen"))
        XCTAssertTrue(assessmentPrompt.contains("Controleer de dekking en planning."))
        XCTAssertEqual(CommitteeAssessmentService.inputKey(pages: [text], purpose: purpose,
                                                            model: "fixture-model"), review.inputKey)

        let changedPurpose = MeetingPurpose(committee: CommitteeDefinition(
            id: "integration-wonen", revision: "r1", name: "Wonen",
            topics: ["betaalbare woningen"], attention: "Controleer uitsluitend de bouwtermijn."))
        XCTAssertNotEqual(CommitteeAssessmentService.inputKey(pages: [text], purpose: purpose,
                                                              model: "fixture-model"),
                          CommitteeAssessmentService.inputKey(pages: [text], purpose: changedPurpose,
                                                             model: "fixture-model"))

        let categorizationRequest: AIService.Request = { body in
            recorder.append(body)
            let result: [String: Any] = ["categoryID": categoryID, "secondaryCategoryIDs": [String]()]
            return String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        }
        _ = try await CommitteeCategorizationService.categorizeForTesting(
            review: review, pages: [text], model: "fixture-model", request: categorizationRequest,
            reclassify: true)
        let categorizationPrompt = try XCTUnwrap(recorder.bodies.last?["instructions"] as? String)
        XCTAssertTrue(categorizationPrompt.contains("betaalbare woningen"))
        XCTAssertTrue(categorizationPrompt.contains("Controleer de dekking en planning."))
        XCTAssertTrue(categorizationPrompt.contains(categoryID))
    }

    func testUpdatedAndRemovedProfilesKeepHistoricalReviewAndExportInWorkdocument() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = CommitteeLibrary(defaults: defaults, storageKey: "active-library")
        let oldPurpose = try XCTUnwrap(library.committees.first { $0 == .bestuur })
        let page = "De gemeente reserveert geld voor betaalbare woningen."
        let pdf = try BriefingPDF.data(
            document: OpenPDF(name: "Voorstel.pdf", data: Data(), pages: [], findings: []),
            insights: [], analyzed: false, title: "Voorstel")
        let workspace = SimpleWorkspace(committeeLibrary: library)
        workspace.document = OpenPDF(name: "Voorstel.pdf", data: pdf, pages: [page], findings: [])
        workspace.captureCurrentCommitteeLibrary()
        workspace.meetingPurpose = oldPurpose
        workspace.starred = ["saved-point"]
        workspace.annotations = ["saved-point": PointAnnotation(note: "Deze notitie blijft bewaard.")]

        let customDefinition = CommitteeDefinition(id: "custom-reviewed", revision: "r1",
            name: "Wonen", topics: ["betaalbare woningen"], attention: "Controleer de planning.")
        try library.save(customDefinition)
        let customPurpose = MeetingPurpose(committee: customDefinition)
        workspace.captureCurrentCommitteeLibrary()

        let definition = CommitteeDefinition(id: oldPurpose.profileID,
            revision: oldPurpose.editableDefinition.revision, name: "Bestuur en financiën",
            topics: ["begroting", "financieel beheer"], attention: "Controleer de dekking.")
        try library.save(definition)
        let updatedPurpose = try XCTUnwrap(library.committees.first { $0.profileID == oldPurpose.profileID })
        workspace.captureCurrentCommitteeLibrary()
        library.remove(updatedPurpose)

        let passage = try XCTUnwrap(PassageEngine.passages([page]).first)
        let review = CommitteeAssessmentService.Review(
            purpose: oldPurpose, model: "fixture-model", inputKey: "historical-review",
            entries: [.init(passageID: passage.id, sources: passage.sources, rating: .important,
                            reason: "Historische beoordeling.", evidenceQuote: page, model: "fixture-model")],
            issues: [], complete: true)
        let customReview = CommitteeAssessmentService.Review(
            purpose: customPurpose, model: "fixture-model", inputKey: "historical-custom-review",
            entries: [.init(passageID: passage.id, sources: passage.sources, rating: .important,
                            reason: "Bewaar de oude commissiebeoordeling.", evidenceQuote: page, model: "fixture-model")],
            issues: [], complete: true)
        var archive = try workspace.archive(readingPage: 1)
        archive.meetingPurpose = oldPurpose
        archive.committeeReviews = [review, customReview]

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("spdfwork")
        defer { try? FileManager.default.removeItem(at: url) }
        try archive.write(url)
        let loaded = try WorkspaceArchive.read(url)
        XCTAssertTrue(loaded.committeeCatalog?.contains(oldPurpose) == true)
        XCTAssertTrue(loaded.committeeCatalog?.contains(updatedPurpose) == true)
        XCTAssertTrue(loaded.committeeCatalog?.contains(customPurpose) == true)

        let emptyLibrary = CommitteeLibrary(defaults: defaults, storageKey: "empty-library")
        for purpose in emptyLibrary.committees { emptyLibrary.remove(purpose) }
        let restored = SimpleWorkspace(committeeLibrary: emptyLibrary)
        restored.generateCommitteeReview = { _, _, _, _ in
            XCTFail("Restoring saved work must not start an AI request.")
            throw CancellationError()
        }
        try restored.restore(loaded, persist: false)

        XCTAssertTrue(restored.availableMeetingPurposes.contains(oldPurpose))
        XCTAssertTrue(restored.availableMeetingPurposes.contains(updatedPurpose))
        XCTAssertTrue(restored.availableMeetingPurposes.contains(customPurpose))
        XCTAssertEqual(restored.annotations["saved-point"]?.note, "Deze notitie blijft bewaard.")
        XCTAssertEqual(restored.starred, ["saved-point"])
        XCTAssertEqual(restored.committeeReviews[oldPurpose.rawValue]?.entries.first?.evidenceQuote, page)

        var configuration = ExportConfiguration()
        configuration.committeePurpose = oldPurpose
        configuration.summary = false
        configuration.tables = false
        configuration.glossary = false
        configuration.chosenPassages = false
        let content = restored.exportContent(for: configuration)
        XCTAssertTrue(content.context.contains("Commissiebereik: Bestuur"))
        XCTAssertTrue(content.chosenPassages.contains { $0.text == page })

        configuration.committeePurpose = customPurpose
        let customExport = restored.exportContent(for: configuration)
        XCTAssertTrue(customExport.context.contains("Commissiebereik: Wonen"))
        XCTAssertTrue(customExport.chosenPassages.contains { $0.text == page })
    }

    func testAnIntentionallyEmptyLibraryAddsNoBuiltinPurposesToNewWorkspace() {
        let library = emptyLibrary()
        let workspace = SimpleWorkspace(committeeLibrary: library)
        XCTAssertTrue(library.committees.isEmpty)
        XCTAssertEqual(workspace.availableMeetingPurposes, [.raad])
    }

    func testLegacyWorkdocumentWithoutCommitteeCatalogStillDecodesAndRestores() throws {
        #if os(iOS)
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
        #else
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
        let url = fixtures.appendingPathComponent("mac-v1.spdfwork")
        #endif
        let archive = try WorkspaceArchive.read(url)
        XCTAssertNil(archive.committeeCatalog)
        let workspace = SimpleWorkspace(committeeLibrary: emptyLibrary())
        workspace.generateCommitteeReview = { _, _, _, _ in
            XCTFail("Opening a legacy workdocument must not start an AI request.")
            throw CancellationError()
        }
        try workspace.restore(archive, persist: false)
        XCTAssertEqual(workspace.document?.pages, archive.pages)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "CustomCommitteeIntegrationTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func emptyLibrary() -> CommitteeLibrary {
        let (defaults, suite) = makeDefaults()
        let library = CommitteeLibrary(defaults: defaults, storageKey: "empty-library")
        for purpose in library.committees { library.remove(purpose) }
        defaults.removePersistentDomain(forName: suite)
        return library
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[String: Any]] = []

    var bodies: [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func append(_ body: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        stored.append(body)
    }
}
