import Foundation
import XCTest
@testable import CommissieWijzer

@MainActor
final class CommitteeLibraryTests: XCTestCase {
    func testDefaultLibraryPreservesLegacyBuiltinPurposes() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let library = CommitteeLibrary(defaults: defaults, storageKey: "library")
        XCTAssertEqual(library.committees, [.bestuur, .leefomgeving, .sociaalDomein])
        XCTAssertTrue(library.committees.allSatisfy { $0.committee == nil })
        XCTAssertFalse(library.committees.contains(.raad))
    }

    func testEditingBuiltinCreatesImmutableNewSnapshotAndNoOpSaveKeepsIt() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = CommitteeLibrary(defaults: defaults, storageKey: "library")
        let original = try XCTUnwrap(library.committees.first { $0 == .bestuur })
        let oldRawValue = original.rawValue
        let edited = CommitteeDefinition(id: original.profileID,
                                         revision: original.editableDefinition.revision,
                                         name: "Bestuur en financiën",
                                         topics: ["begroting", "organisatie"],
                                         attention: "Controleer de dekking.")

        try library.save(edited)
        let saved = try XCTUnwrap(library.committees.first { $0.profileID == "bestuur" })
        XCTAssertNotEqual(saved, .bestuur)
        XCTAssertNotEqual(saved.rawValue, oldRawValue)
        XCTAssertEqual(saved.committee?.name, "Bestuur en financiën")
        XCTAssertNotEqual(saved.committee?.revision, edited.revision)
        XCTAssertEqual(saved.categories.map(\.id), ["topic-1", "topic-2"])
        XCTAssertEqual(saved.categories.map(\.title), edited.topics)

        let savedRawValue = saved.rawValue
        try library.save(try XCTUnwrap(saved.committee))
        XCTAssertEqual(library.committees.first { $0.profileID == "bestuur" }?.rawValue, savedRawValue)
    }

    func testEditingCustomProfileAdvancesRevisionWhenCallerReusesRevision() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = CommitteeLibrary(defaults: defaults, storageKey: "library")
        let first = CommitteeDefinition(id: "custom-1", revision: "r1", name: "Wonen",
                                        topics: ["betaalbaarheid"], attention: "")
        try library.save(first)
        let before = try XCTUnwrap(library.committees.first { $0.profileID == first.id })
        let next = CommitteeDefinition(id: first.id, revision: first.revision, name: "Wonen en ruimte",
                                       topics: ["betaalbaarheid", "planning"], attention: "Check de kaartbijlage.")

        try library.save(next)
        let after = try XCTUnwrap(library.committees.first { $0.profileID == first.id })
        XCTAssertNotEqual(before.rawValue, after.rawValue)
        XCTAssertNotEqual(before.committee?.revision, after.committee?.revision)
        XCTAssertEqual(after.committee?.name, next.name)
    }

    func testSavingAndRemovingProfilesPersistsAcrossLibraryInstances() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "library"
        let firstLibrary = CommitteeLibrary(defaults: defaults, storageKey: key)
        let added = CommitteeDefinition(id: "my-committee", revision: "rev-1", name: "Mijn commissie",
                                        topics: ["onderwerp"], attention: "Eigen aanwijzing.")
        try firstLibrary.save(added)
        let loaded = CommitteeLibrary(defaults: defaults, storageKey: key)
        XCTAssertNotNil(loaded.committees.first { $0.profileID == added.id })

        loaded.remove(MeetingPurpose(committee: added))
        let reloaded = CommitteeLibrary(defaults: defaults, storageKey: key)
        XCTAssertNil(reloaded.committees.first { $0.profileID == added.id })
        XCTAssertEqual(reloaded.committees, [.bestuur, .leefomgeving, .sociaalDomein])
    }

    func testIntentionallyEmptyLibraryRemainsEmptyAfterRestart() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "library"
        let library = CommitteeLibrary(defaults: defaults, storageKey: key)
        for purpose in library.committees { library.remove(purpose) }
        XCTAssertTrue(library.committees.isEmpty)
        XCTAssertTrue(CommitteeLibrary(defaults: defaults, storageKey: key).committees.isEmpty)
    }

    func testCorruptPersistenceIsVisibleAndNeverOverwritten() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "library"
        let corrupt = Data("{not a committee list}".utf8)
        defaults.set(corrupt, forKey: key)

        let library = CommitteeLibrary(defaults: defaults, storageKey: key)
        XCTAssertFalse(library.canEdit)
        XCTAssertNotNil(library.loadErrorMessage)
        XCTAssertThrowsError(try library.save(CommitteeDefinition(id: "new", name: "Nieuw", topics: ["x"], attention: "")))
        library.remove(.bestuur)
        XCTAssertEqual(defaults.data(forKey: key), corrupt)
    }

    func testValidationRejectsBlankAndOverLimitDefinitions() {
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "   ", topics: ["topic"], attention: "").validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "Naam", topics: [], attention: "").validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "Naam", topics: ["  "], attention: "").validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "Naam", topics: ["A", " a "], attention: "").validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "Naam", topics: Array(repeating: "x", count: 31), attention: "").validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "Naam", topics: [String(repeating: "x", count: 121)], attention: "").validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "x", name: "Naam", topics: ["x"], attention: String(repeating: "x", count: 1001)).validate())
        XCTAssertThrowsError(try CommitteeDefinition(id: "bad:id", name: "Naam", topics: ["x"], attention: "").validate())
    }

    func testLegacyBuiltinStringAndCustomSnapshotCodableCompatibility() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        XCTAssertEqual(String(decoding: try encoder.encode(MeetingPurpose.bestuur), as: UTF8.self), "\"bestuur\"")
        XCTAssertEqual(try decoder.decode(MeetingPurpose.self, from: Data("\"bestuur\"".utf8)), .bestuur)

        let definition = CommitteeDefinition(id: "new-committee", revision: "rev-2", name: "Nieuwe commissie",
                                             topics: ["wonen", "verkeer"], attention: "Controleer de bron.")
        let purpose = MeetingPurpose(committee: definition)
        let encoded = try encoder.encode(purpose)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["id"] as? String, definition.id)
        XCTAssertEqual(try decoder.decode(MeetingPurpose.self, from: encoded), purpose)
        XCTAssertTrue(purpose.analysisCacheComponents.contains(definition.name))
        XCTAssertTrue(purpose.analysisCacheComponents.contains(definition.attention))
        XCTAssertTrue(definition.topics.allSatisfy { purpose.analysisCacheComponents.contains($0) })
    }

    func testCustomRawValueAndCacheComponentsIncludeSnapshotIdentityAndContent() {
        let first = MeetingPurpose(committee: CommitteeDefinition(id: "a:b", revision: "c", name: "AB",
                                                                  topics: ["one"], attention: "note"))
        let second = MeetingPurpose(committee: CommitteeDefinition(id: "a", revision: "b:c", name: "AB",
                                                                   topics: ["one"], attention: "note"))
        XCTAssertNotEqual(first.rawValue, second.rawValue)
        XCTAssertNotEqual(first.analysisCacheComponents, second.analysisCacheComponents)

        let changed = MeetingPurpose(committee: CommitteeDefinition(id: "a:b", revision: "d", name: "AB",
                                                                    topics: ["one"], attention: "note"))
        XCTAssertNotEqual(first.rawValue, changed.rawValue)
        XCTAssertEqual(first.categories.map(\.id), changed.categories.map(\.id))
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "CommitteeLibraryTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }
}
