import XCTest
@testable import CommissieWijzer

final class ForkIdentityTests: XCTestCase {
    func testPersistentWorkUsesNeutralApplicationSupportNamespace() {
        XCTAssertEqual(SavedSelection.directory.lastPathComponent, "selecties")
        XCTAssertEqual(SavedSelection.directory.deletingLastPathComponent().lastPathComponent, "CommissieWijzer")
        XCTAssertEqual(SavedWork.directory.lastPathComponent, "werk")
        XCTAssertEqual(SavedWork.directory.deletingLastPathComponent().lastPathComponent, "CommissieWijzer")
        XCTAssertEqual(PersonalGlossary.url.deletingLastPathComponent().lastPathComponent, "CommissieWijzer")
    }

    @MainActor
    func testRecentWorkspaceKeepsSPDFWorkExtension() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommissieWijzer-ForkIdentityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let suiteName = "CommissieWijzer-ForkIdentityTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let recent = RecentWorkspaceDocuments(defaults: defaults)
        let accepted = root.appendingPathComponent("notes.spdfwork")
        let unsupported = root.appendingPathComponent("notes.txt")
        try Data().write(to: accepted)
        try Data().write(to: unsupported)

        try recent.record(accepted)
        XCTAssertEqual(recent.entries.map(\.displayName), ["notes.spdfwork"])
        XCTAssertThrowsError(try recent.record(unsupported))
    }
}
