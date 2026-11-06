import Foundation

enum BuiltinMeetingPurpose: String, CaseIterable, Sendable {
    case raad
    case bestuur
    case leefomgeving
    case sociaalDomein
}

struct CommitteeDefinition: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let revision: String
    let name: String
    let topics: [String]
    let attention: String

    init(id: String = UUID().uuidString,
         revision: String = UUID().uuidString,
         name: String,
         topics: [String],
         attention: String) {
        self.id = id
        self.revision = revision
        self.name = name
        self.topics = topics
        self.attention = attention
    }

    enum ValidationError: Error, LocalizedError, Equatable {
        case invalidID
        case invalidRevision
        case invalidName
        case invalidTopicCount
        case invalidTopic(Int)
        case duplicateTopic(Int)
        case attentionTooLong

        var errorDescription: String? {
            switch self {
            case .invalidID: "De vaste profiel-ID ontbreekt of is te lang."
            case .invalidRevision: "De profielversie ontbreekt of is te lang."
            case .invalidName: "Geef de commissie een naam van maximaal 80 tekens."
            case .invalidTopicCount: "Voeg 1 tot 30 onderwerpen toe."
            case .invalidTopic(let index): "Onderwerp \(index + 1) moet tekst bevatten en mag maximaal 120 tekens lang zijn."
            case .duplicateTopic(let index): "Onderwerp \(index + 1) staat al in de lijst."
            case .attentionTooLong: "De extra aanwijzing mag maximaal 1000 tekens lang zijn."
            }
        }
    }

    func validate() throws {
        guard Self.isStableIdentifier(id) else {
            throw ValidationError.invalidID
        }
        guard Self.isStableIdentifier(revision) else {
            throw ValidationError.invalidRevision
        }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, name.count <= 80 else { throw ValidationError.invalidName }
        guard (1...30).contains(topics.count) else { throw ValidationError.invalidTopicCount }
        var seen = Set<String>()
        for (index, topic) in topics.enumerated() {
            let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTopic.isEmpty, topic.count <= 120 else { throw ValidationError.invalidTopic(index) }
            guard seen.insert(cleanTopic.lowercased()).inserted else { throw ValidationError.duplicateTopic(index) }
        }
        guard attention.utf8.count <= 1000 else { throw ValidationError.attentionTooLong }
    }

    private static func isStableIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 100 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private enum CodingKeys: String, CodingKey { case id, revision, name, topics, attention }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(String.self, forKey: .id),
                  revision: try values.decode(String.self, forKey: .revision),
                  name: try values.decode(String.self, forKey: .name),
                  topics: try values.decode([String].self, forKey: .topics),
                  attention: try values.decode(String.self, forKey: .attention))
        try validate()
    }
}

struct MeetingPurpose: Codable, Hashable, CaseIterable, Sendable, Identifiable {
    private let builtin: BuiltinMeetingPurpose?
    let committee: CommitteeDefinition?

    private init(builtin: BuiltinMeetingPurpose) {
        self.builtin = builtin
        committee = nil
    }

    init(committee: CommitteeDefinition) {
        builtin = nil
        self.committee = committee
    }

    static let raad = MeetingPurpose(builtin: .raad)
    static let bestuur = MeetingPurpose(builtin: .bestuur)
    static let leefomgeving = MeetingPurpose(builtin: .leefomgeving)
    static let sociaalDomein = MeetingPurpose(builtin: .sociaalDomein)
    static let allCases: [MeetingPurpose] = BuiltinMeetingPurpose.allCases.map(MeetingPurpose.init(builtin:))

    /// Preserves the original raw-string initializer for legacy builtin IDs.
    init?(rawValue: String) {
        guard let builtin = BuiltinMeetingPurpose(rawValue: rawValue) else { return nil }
        self.init(builtin: builtin)
    }

    var builtinCase: BuiltinMeetingPurpose? { builtin }

    var rawValue: String {
        if let builtin { return builtin.rawValue }
        guard let committee else { return BuiltinMeetingPurpose.raad.rawValue }
        return "custom:\(committee.id.utf8.count):\(committee.id):\(committee.revision.utf8.count):\(committee.revision)"
    }

    var id: String { rawValue }

    /// Stable across edits, unlike `rawValue`, which names a particular snapshot.
    var profileID: String { committee?.id ?? builtin?.rawValue ?? BuiltinMeetingPurpose.raad.rawValue }

    var title: String {
        if let committee { return committee.name }
        switch builtin ?? .raad {
        case .raad: return "Raad"
        case .bestuur: return "Bestuur"
        case .leefomgeving: return "Leefomgeving"
        case .sociaalDomein: return "Sociaal Domein"
        }
    }

    var topics: [String] {
        if let committee { return committee.topics }
        switch builtin ?? .raad {
        case .raad: return []
        case .bestuur:
            return ["accommodaties", "automatisering en ICT", "organisatie en bestuur", "communicatie", "dienstverlening",
                    "economische zaken", "evenementen", "financiën en belastingen", "openbare orde en veiligheid", "vergunningen en handhaving", "politie",
                    "brandweer", "crisisbeheersing", "overheidsbedrijven", "parkeren", "personeel"]
        case .leefomgeving:
            return ["landbouw", "beheer openbare ruimte", "cultureel erfgoed", "dierenwelzijn", "duurzaamheid", "klimaat en milieu",
                    "grondgebruik", "projecten", "recreatie en toerisme", "ruimtelijke ontwikkeling en ordening", "sport",
                    "verkeer en vervoer", "volkshuisvesting en wonen", "wijk- en kerngerichte aanpak", "overheidsbedrijven"]
        case .sociaalDomein:
            return ["armoedebeleid", "cultuur", "educatie en onderwijs", "emancipatie", "jeugd", "volksgezondheid",
                    "werk en inkomen en sociale zaken", "welzijn en Thuis in Nissewaard", "zorg"]
        }
    }

    var categories: [CommitteeCategory] { CommitteeCategory.categories(for: self) }

    var boundaries: String {
        if let committee { return committee.attention }
        switch builtin ?? .raad {
        case .raad: return ""
        case .bestuur:
            return "Een sectoraal bedrag zonder financieel beheer, personeel of bestuurlijke sturing is niet automatisch Bestuur."
        case .leefomgeving:
            return "Algemene politie- of crisiszorg is geen Leefomgeving zonder direct verband met ruimte, verkeer of milieu."
        case .sociaalDomein:
            return "Sport, vastgoed, veiligheid of algemeen maatschappelijk nut is niet automatisch Sociaal Domein; een direct sociaal onderwerp uit de lijst is nodig."
        }
    }

    /// The three editable examples use the existing builtin IDs so saving an
    /// edited example replaces its profile instead of creating a duplicate.
    var editableDefinition: CommitteeDefinition {
        if let committee { return committee }
        return CommitteeDefinition(id: profileID, revision: "1", name: title,
                                   topics: topics, attention: boundaries)
    }

    /// Full snapshots invalidate derived reviews when any committee prompt input changes.
    var analysisCacheComponents: [String] {
        guard let committee else { return [rawValue] }
        let categoryComponents = categories.flatMap { category in
            [category.id, category.title, String(category.topics.count)] + category.topics
        }
        return ["committee-definition-v1", committee.id, committee.revision, committee.name,
                String(committee.topics.count)] + committee.topics +
            [committee.attention, String(categories.count)] + categoryComponents
    }

    private enum CodingKeys: String, CodingKey { case id, revision, name, topics, attention }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let rawValue = try? single.decode(String.self) {
            guard let builtin = BuiltinMeetingPurpose(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unknown legacy meeting purpose.")
            }
            self.init(builtin: builtin)
            return
        }
        let committee = try CommitteeDefinition(from: decoder)
        self.init(committee: committee)
    }

    func encode(to encoder: Encoder) throws {
        if let builtin {
            var single = encoder.singleValueContainer()
            try single.encode(builtin.rawValue)
        } else if let committee {
            try committee.encode(to: encoder)
        } else {
            var single = encoder.singleValueContainer()
            try single.encode(BuiltinMeetingPurpose.raad.rawValue)
        }
    }
}
