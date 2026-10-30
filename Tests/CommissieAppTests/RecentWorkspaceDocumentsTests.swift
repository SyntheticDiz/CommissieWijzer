import XCTest
@testable import CommissieWijzer

@MainActor
final class RecentWorkspaceDocumentsTests: XCTestCase {
    private func makeStore() throws -> (RecentWorkspaceDocuments, UserDefaults, URL, String) {
        let suite = "RecentWorkspaceDocumentsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (RecentWorkspaceDocuments(defaults: defaults), defaults, root, suite)
    }

    private func createDocument(_ name: String, in root: URL) throws -> URL {
        let url = root.appendingPathComponent(name).appendingPathExtension("spdfwork")
        try Data("fixture-\(name)".utf8).write(to: url)
        return url
    }

    func testRecordDeduplicatesCanonicalURLAndKeepsFiveNewest() throws {
        let (store, defaults, root, suite) = try makeStore()
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        var documents: [URL] = []
        for index in 1...6 {
            let document = try createDocument("document-\(index)", in: root)
            documents.append(document)
            try store.record(document)
        }
        try store.record(documents[5])

        XCTAssertEqual(store.entries.count, RecentWorkspaceDocuments.maximumEntries)
        XCTAssertEqual(store.entries.first?.path, documents[5].resolvingSymlinksInPath().path)
        XCTAssertEqual(Set(store.entries.map(\.path)).count, store.entries.count)
        XCTAssertEqual(store.entries.map(\.displayName), [
            "document-6.spdfwork", "document-5.spdfwork", "document-4.spdfwork", "document-3.spdfwork", "document-2.spdfwork"
        ])
        XCTAssertEqual(store.read(), store.entries)
    }

    func testRecordDeduplicatesSymlinkAndResolvedBookmarkOpensOriginal() throws {
        let (store, defaults, root, suite) = try makeStore()
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        let original = try createDocument("source", in: root)
        let link = root.appendingPathComponent("alias.spdfwork")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)

        try store.record(original)
        try store.record(link)

        XCTAssertEqual(store.entries.count, 1)
        let resolved = try store.resolve(try XCTUnwrap(store.entries.first))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
        XCTAssertEqual(resolved.resolvingSymlinksInPath().path, original.resolvingSymlinksInPath().path)
        XCTAssertEqual(store.availability(of: try XCTUnwrap(store.entries.first)), .available)
    }

    func testMissingRecentDocumentRemainsListedWithHelpfulStatus() throws {
        let (store, defaults, root, suite) = try makeStore()
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        let document = try createDocument("moved", in: root)
        try store.record(document)
        let entry = try XCTUnwrap(store.entries.first)
        try FileManager.default.removeItem(at: document)

        XCTAssertEqual(store.availability(of: entry), .missing)
        XCTAssertTrue(try XCTUnwrap(store.statusMessage(for: entry)).contains("staat niet meer op deze locatie"))
        XCTAssertEqual(store.read(), [entry], "Reading the list must not silently delete missing records.")
    }

    func testRecordRejectsNonWorkdocumentAndDoesNotChangeRecents() throws {
        let (store, defaults, root, suite) = try makeStore()
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        let document = try createDocument("valid", in: root)
        try store.record(document)
        let other = root.appendingPathComponent("other.pdf")
        try Data("pdf".utf8).write(to: other)

        XCTAssertThrowsError(try store.record(other))
        XCTAssertEqual(store.entries.map(\.path), [document.resolvingSymlinksInPath().path])
    }

    func testReplaceRelocatedEntryValidatesThenDeduplicatesAndKeepsLimit() throws {
        let (store, defaults, root, suite) = try makeStore()
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        let original = try createDocument("original", in: root)
        let existingDestination = try createDocument("destination", in: root)
        let other = try createDocument("other", in: root)
        try store.record(original)
        try store.record(existingDestination)
        try store.record(other)
        let oldEntry = try XCTUnwrap(store.entries.first { $0.displayName == "original.spdfwork" })
        let before = store.entries

        let invalid = root.appendingPathComponent("not-a-workdocument.pdf")
        try Data("invalid".utf8).write(to: invalid)
        XCTAssertThrowsError(try store.replace(oldEntry, with: invalid))
        XCTAssertEqual(store.entries, before, "A failed relocation must preserve the old list entry.")

        try store.replace(oldEntry, with: existingDestination)
        XCTAssertEqual(store.entries.first?.displayName, "destination.spdfwork")
        XCTAssertEqual(store.entries.filter { $0.displayName == "destination.spdfwork" }.count, 1)
        XCTAssertFalse(store.entries.contains { $0.id == oldEntry.id })
        XCTAssertLessThanOrEqual(store.entries.count, RecentWorkspaceDocuments.maximumEntries)
    }
}
