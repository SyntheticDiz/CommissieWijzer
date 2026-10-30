import Foundation

public struct Theme: Identifiable, Sendable {
    public let id: String
    public let keywords: [String]
    public let question: String

    public init(id: String, keywords: [String], question: String) {
        self.id = id; self.keywords = keywords; self.question = question
    }

    public static let coreValues: [Theme] = [
        Theme(id: "Geen kind in armoede", keywords: ["kinderarmoede", "kindpakket", "schoolmaaltijden", "schoolontbijt", "leergeld", "jeugdfonds", "schoolkosten", "kinderopvang", "gezinsarmoede"], question: "Hoe voorkomt dit dat kinderen door geldgebrek niet kunnen meedoen, en welke gezinnen worden bereikt?"),
        Theme(id: "Betaalbare zorg", keywords: ["zorgkosten", "eigen bijdrage", "eigen risico", "zorgverzekering", "zorgpremie", "zorgmijding", "wmo", "jeugdhulp", "thuiszorg", "betaalbare zorg"], question: "Welke kosten komen bij inwoners terecht en blijft noodzakelijke zorg bereikbaar voor mensen met weinig inkomen?"),
        Theme(id: "Lage en lagere middeninkomens", keywords: ["minimumloon", "minimuminkomen", "lage inkomens", "middeninkomens", "lagere middeninkomens", "koopkracht", "woonlasten", "energiekosten", "gemeentelijke belastingen", "inkomensgrens", "armoedeval", "toeslagen", "kwijtschelding", "bestaanszekerheid"], question: "Wat zijn de netto gevolgen voor lage en lagere middeninkomens, ook voor huishoudens net boven de inkomensgrens van regelingen?")
    ]

    public static let defaults: [Theme] = coreValues + [
        Theme(id: "Wonen", keywords: ["huur", "huurwoning", "huurwoningen", "sociale huur", "woningbouw", "woningcorporatie", "woonlasten", "huisvesting"], question: "Welke gevolgen heeft dit voorstel voor betaalbaarheid en beschikbaarheid van sociale huurwoningen?"),
        Theme(id: "Bestaanszekerheid", keywords: ["armoede", "bijstand", "schulden", "minimuminkomen", "minima", "bestaanszekerheid", "schuldhulpverlening", "koopkracht"], question: "Wat verandert er voor inwoners met een laag inkomen en hoe wordt het bereik van ondersteuning gemeten?"),
        Theme(id: "Zorg en ondersteuning", keywords: ["wmo", "jeugdzorg", "jeugdhulp", "thuiszorg", "mantelzorg", "zorgkosten", "eigen bijdrage", "wachtlijst", "wachtlijsten"], question: "Wat betekent dit voor toegang tot zorg, wachttijden en kosten voor inwoners?"),
        Theme(id: "Werk en inkomen", keywords: ["loon", "arbeidsvoorwaarden", "werkloosheid", "arbeidsmarkt", "participatiewet", "sociale werkvoorziening", "flexwerk"], question: "Hoe worden fatsoenlijke arbeidsvoorwaarden en duurzame werkgelegenheid geborgd?"),
        Theme(id: "Publieke voorzieningen", keywords: ["privatisering", "marktwerking", "aanbesteding", "bibliotheek", "buurthuis", "openbaar vervoer", "bezuiniging", "bezuinigingen"], question: "Wat zijn de gevolgen voor toegankelijkheid, kwaliteit en publieke zeggenschap?"),
        Theme(id: "Klimaat en leefomgeving", keywords: ["energiearmoede", "isolatie", "energietransitie", "warmtenet", "verduurzaming", "luchtkwaliteit", "energiekosten"], question: "Hoe worden kosten en baten verdeeld en welke ondersteuning krijgen huishoudens met weinig financiële ruimte?"),
        Theme(id: "Zeggenschap", keywords: ["inspraak", "bewonersparticipatie", "referendum", "medezeggenschap", "burgerparticipatie", "bewonersinitiatief"], question: "Welke invloed hebben bewoners op het besluit en hoe wordt hun inbreng teruggekoppeld?")
    ]
}

public struct Finding: Identifiable, Sendable {
    public var id: String { "\(page)-\(theme)-\(excerpt)" }
    public let page: Int
    public let theme: String
    public let excerpt: String
    public let matchedKeywords: [String]
    public let question: String
}

public enum Analyzer {
    public static func analyze(pages: [String], themes: [Theme] = Theme.defaults) -> [Finding] {
        var findings: [Finding] = []
        for (index, page) in pages.enumerated() {
            // Preserve paragraphs where possible; normalize PDF line wrapping within them.
            let paragraphs = page.components(separatedBy: "\n\n")
                .map { $0.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ") }
                .filter { !$0.isEmpty }
            for paragraph in paragraphs {
                for theme in themes {
                    let matches = theme.keywords.filter { keyword in
                        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: keyword) + "(?![\\p{L}\\p{N}])"
                        return paragraph.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
                    }
                    guard !matches.isEmpty else { continue }
                    let finding = Finding(page: index + 1, theme: theme.id, excerpt: paragraph, matchedKeywords: matches, question: theme.question)
                    if !findings.contains(where: { $0.id == finding.id }) { findings.append(finding) }
                }
            }
        }
        return findings
    }
}
