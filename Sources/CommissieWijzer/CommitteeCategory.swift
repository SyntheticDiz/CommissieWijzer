import Foundation

/// Stable purpose-specific topic groups used by committee review and display.
struct CommitteeCategory: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let topics: [String]

    static let unassignedID = "unassigned"
    static let unassignedTitle = "Nog in te delen"

    static func categories(for purpose: MeetingPurpose) -> [CommitteeCategory] {
        switch purpose {
        case .raad:
            return []
        case .bestuur:
            return [
                .init(id: "bestuur-organisatie", title: "Organisatie en dienstverlening",
                      topics: ["organisatie en bestuur", "communicatie", "dienstverlening", "personeel"]),
                .init(id: "bestuur-digitalisering", title: "Automatisering en ICT",
                      topics: ["automatisering en ICT"]),
                .init(id: "bestuur-accommodaties", title: "Accommodaties en voorzieningen",
                      topics: ["accommodaties"]),
                .init(id: "bestuur-economie", title: "Economie en evenementen",
                      topics: ["economische zaken", "evenementen", "overheidsbedrijven"]),
                .init(id: "bestuur-financien", title: "Financiën en belastingen",
                      topics: ["financiën en belastingen"]),
                .init(id: "bestuur-veiligheid", title: "Openbare orde en veiligheid",
                      topics: ["openbare orde en veiligheid", "politie", "brandweer", "crisisbeheersing"]),
                .init(id: "bestuur-vergunningen", title: "Vergunningen en handhaving",
                      topics: ["vergunningen en handhaving"]),
                .init(id: "bestuur-parkeren", title: "Parkeren",
                      topics: ["parkeren"])
            ]
        case .leefomgeving:
            return [
                .init(id: "leefomgeving-openbare-ruimte", title: "Openbare ruimte en onderhoud", topics: ["beheer openbare ruimte"]),
                .init(id: "leefomgeving-wonen", title: "Wonen en ruimtelijke ontwikkeling", topics: ["volkshuisvesting en wonen", "grondgebruik", "projecten", "ruimtelijke ontwikkeling en ordening", "overheidsbedrijven"]),
                .init(id: "leefomgeving-verkeer", title: "Verkeer en vervoer", topics: ["verkeer en vervoer"]),
                .init(id: "leefomgeving-duurzaamheid", title: "Duurzaamheid, klimaat en milieu", topics: ["duurzaamheid", "klimaat en milieu"]),
                .init(id: "leefomgeving-recreatie", title: "Sport, recreatie en toerisme", topics: ["sport", "recreatie en toerisme"]),
                .init(id: "leefomgeving-erfgoed", title: "Erfgoed, landbouw en dierenwelzijn", topics: ["cultureel erfgoed", "landbouw", "dierenwelzijn"]),
                .init(id: "leefomgeving-wijken", title: "Wijken en kernen", topics: ["wijk- en kerngerichte aanpak"])
            ]
        case .sociaalDomein:
            return [
                .init(id: "sociaal-onderwijs", title: "Educatie en onderwijs",
                      topics: ["educatie en onderwijs"]),
                .init(id: "sociaal-jeugd", title: "Jeugd",
                      topics: ["jeugd"]),
                .init(id: "sociaal-zorg", title: "Zorg en volksgezondheid",
                      topics: ["zorg", "volksgezondheid"]),
                .init(id: "sociaal-werk-inkomen", title: "Werk, inkomen en sociale zaken",
                      topics: ["werk en inkomen en sociale zaken"]),
                .init(id: "sociaal-armoede", title: "Armoedebeleid",
                      topics: ["armoedebeleid"]),
                .init(id: "sociaal-welzijn", title: "Welzijn en Thuis in Nissewaard",
                      topics: ["welzijn en Thuis in Nissewaard"]),
                .init(id: "sociaal-cultuur", title: "Cultuur en emancipatie",
                      topics: ["cultuur", "emancipatie"])
            ]
        }
    }

    static func category(id: String, for purpose: MeetingPurpose) -> CommitteeCategory? {
        categories(for: purpose).first { $0.id == id }
    }

    static func title(for id: String?, purpose: MeetingPurpose) -> String {
        guard let id, let category = category(id: id, for: purpose) else { return unassignedTitle }
        return category.title
    }

    static func validIDs(_ ids: [String], for purpose: MeetingPurpose,
                         excluding primaryID: String? = nil) -> [String]? {
        let allowed = Set(categories(for: purpose).map(\.id))
        guard ids.allSatisfy({ allowed.contains($0) }),
              Set(ids).count == ids.count,
              !ids.contains(where: { $0 == primaryID }) else { return nil }
        return ids
    }
}
