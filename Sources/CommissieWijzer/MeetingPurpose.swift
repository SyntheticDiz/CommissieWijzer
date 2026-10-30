import Foundation

enum MeetingPurpose: String, Codable, CaseIterable, Sendable {
    case raad
    case bestuur
    case leefomgeving
    case sociaalDomein

    var title: String {
        switch self {
        case .raad: return "Raad"
        case .bestuur: return "Bestuur"
        case .leefomgeving: return "Leefomgeving"
        case .sociaalDomein: return "Sociaal Domein"
        }
    }

    var topics: [String] {
        switch self {
        case .raad:
            return []
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
        switch self {
        case .raad:
            return ""
        case .bestuur:
            return "Een sectoraal bedrag zonder financieel beheer, personeel of bestuurlijke sturing is niet automatisch Bestuur."
        case .leefomgeving:
            return "Algemene politie- of crisiszorg is geen Leefomgeving zonder direct verband met ruimte, verkeer of milieu."
        case .sociaalDomein:
            return "Sport, vastgoed, veiligheid of algemeen maatschappelijk nut is niet automatisch Sociaal Domein; een direct sociaal onderwerp uit de lijst is nodig."
        }
    }
}
