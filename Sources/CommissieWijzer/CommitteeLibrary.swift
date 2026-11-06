import Combine
import Foundation

@MainActor
final class CommitteeLibrary: ObservableObject {
    static let shared = CommitteeLibrary()

    nonisolated static let defaultStorageKey = "customCommittees"

    @Published private(set) var committees: [MeetingPurpose]
    @Published private(set) var loadErrorMessage: String?

    var canEdit: Bool { loadErrorMessage == nil }

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = CommitteeLibrary.defaultStorageKey) {
        self.defaults = defaults
        self.storageKey = storageKey

        guard defaults.object(forKey: storageKey) != nil else {
            committees = Self.defaultPurposes
            loadErrorMessage = nil
            return
        }

        do {
            guard let data = defaults.data(forKey: storageKey) else { throw LibraryError.invalidStoredData }
            let purposes = try JSONDecoder().decode([MeetingPurpose].self, from: data)
            try Self.validateStoredPurposes(purposes)
            committees = purposes
            loadErrorMessage = nil
        } catch {
            // Keep the original persisted value untouched and refuse edits until
            // the caller can surface the corrupt state to the user.
            committees = Self.defaultPurposes
            loadErrorMessage = error.localizedDescription
        }
    }

    func save(_ definition: CommitteeDefinition) throws {
        guard canEdit else { throw LibraryError.invalidStoredData }
        try definition.validate()
        guard definition.id != BuiltinMeetingPurpose.raad.rawValue else {
            throw LibraryError.reservedCouncilProfile
        }

        var purposes = committees
        if let index = purposes.firstIndex(where: { $0.profileID == definition.id }) {
            let existing = purposes[index].editableDefinition
            // An unchanged example remains its legacy builtin value; saving it
            // does not create a new snapshot or alter previously saved reviews.
            guard !Self.sameContent(existing, definition) else { return }

            let savedDefinition: CommitteeDefinition
            if definition.revision == existing.revision {
                savedDefinition = CommitteeDefinition(id: definition.id,
                                                      revision: Self.freshRevision(excluding: existing.revision),
                                                      name: definition.name,
                                                      topics: definition.topics,
                                                      attention: definition.attention)
            } else {
                savedDefinition = definition
            }
            purposes[index] = MeetingPurpose(committee: savedDefinition)
        } else {
            purposes.append(MeetingPurpose(committee: definition))
        }
        try persist(purposes)
    }

    func remove(_ purpose: MeetingPurpose) {
        guard canEdit else { return }
        let remaining = committees.filter { $0.profileID != purpose.profileID }
        guard remaining.count != committees.count else { return }
        do {
            try persist(remaining)
        } catch {
            loadErrorMessage = error.localizedDescription
        }
    }

    private func persist(_ purposes: [MeetingPurpose]) throws {
        try Self.validateStoredPurposes(purposes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(purposes)
        defaults.set(data, forKey: storageKey)
        committees = purposes
        loadErrorMessage = nil
    }

    private static func sameContent(_ lhs: CommitteeDefinition, _ rhs: CommitteeDefinition) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.topics == rhs.topics && lhs.attention == rhs.attention
    }

    private static func freshRevision(excluding oldRevision: String) -> String {
        var revision = UUID().uuidString
        while revision == oldRevision { revision = UUID().uuidString }
        return revision
    }

    private static func validateStoredPurposes(_ purposes: [MeetingPurpose]) throws {
        var seen = Set<String>()
        for purpose in purposes {
            guard purpose != .raad else { throw LibraryError.reservedCouncilProfile }
            guard seen.insert(purpose.profileID).inserted else {
                throw LibraryError.duplicateProfileID(purpose.profileID)
            }
            if let definition = purpose.committee {
                try definition.validate()
                guard definition.id != BuiltinMeetingPurpose.raad.rawValue else {
                    throw LibraryError.reservedCouncilProfile
                }
            }
        }
    }

    private static let defaultPurposes: [MeetingPurpose] = [
        .bestuur, .leefomgeving, .sociaalDomein
    ]

    private enum LibraryError: LocalizedError {
        case invalidStoredData
        case duplicateProfileID(String)
        case reservedCouncilProfile

        var errorDescription: String? {
            switch self {
            case .invalidStoredData:
                "De opgeslagen commissielijst kan niet veilig worden gelezen. De bestaande gegevens zijn behouden."
            case .duplicateProfileID(let id):
                "De commissielijst bevat het dubbele profiel-ID ‘\(id)’ en kan niet worden opgeslagen."
            case .reservedCouncilProfile:
                "‘Raad’ is altijd beschikbaar als algemeen vergaderdoel en kan geen aangepaste commissie worden."
            }
        }
    }
}
