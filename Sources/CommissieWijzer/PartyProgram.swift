import Foundation
import SwiftUI

struct PartyProgram: Codable, Sendable {
    let name: String
    let pages: [String]
    let pdf: Data

    static var storageURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommissieWijzer/partijprogramma.json")
    }
    static func load(from url: URL = storageURL) throws -> PartyProgram? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(PartyProgram.self, from: Data(contentsOf: url))
    }
    func save(to url: URL = storageURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    /// Small, ranked source fragments keep the local Apple model within its context budget.
    func candidates(for text: String) -> [DocumentChunk] {
        Array(rankedCandidates(for: text).prefix(2))
    }

    struct SearchIndex: Sendable {
        let chunks: [DocumentChunk]
        let terms: [Set<String>]
        func rankedCandidates(for text: String) -> [DocumentChunk] {
            let target = PartyProgram.words(text)
            var ranked: [(index: Int, score: Int)] = []
            for index in chunks.indices { ranked.append((index, terms[index].intersection(target).count)) }
            ranked.sort { left, right in
                left.score == right.score ? left.index < right.index : left.score > right.score
            }
            return ranked.map { chunks[$0.index] }
        }
    }
    private static func words(_ text: String) -> Set<String> {
        let stop: Set<String> = ["worden", "hebben", "kunnen", "moeten", "willen", "gemeente", "nissewaard", "onze", "deze", "voor", "door", "naar", "niet", "zijn", "wordt", "meer", "over", "onder", "zoals", "daar", "alle", "waar", "zich", "maar", "heeft", "worden"]
        return Set(text.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { $0.count >= 4 && !stop.contains($0) }.map { String($0.prefix(7)) })
    }
    var searchIndex: SearchIndex {
        let chunks = TextChunks.chunks(pages, maxBytes: 700)
        return SearchIndex(chunks: chunks, terms: chunks.map { Self.words($0.text) })
    }
    func rankedCandidates(for text: String) -> [DocumentChunk] { searchIndex.rankedCandidates(for: text) }

}

struct PartyProgramSettings: View {
    @AppStorage("uiLanguage") private var uiLanguage = "nl"
    @State private var program: PartyProgram?
    @State private var choosing = false
    @State private var busy = false
    @State private var message = ""
    var body: some View {
        GroupBox(UIStrings.text("Eigen partijprogramma")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(UIStrings.text(program.map { "\($0.name) · \($0.pages.count) pagina’s" } ?? "Nog geen partijprogramma opgeslagen"))
                    .font(.callout).lineLimit(2)
                HStack {
                    Button(UIStrings.text(program == nil ? "Voeg PDF toe…" : "Vervang PDF…")) { choosing = true }.disabled(busy)
                    if program != nil {
                        Button(UIStrings.text("Verwijder"), role: .destructive) {
                            do { try FileManager.default.removeItem(at: PartyProgram.storageURL); program = nil; message = "Verwijderd. Analyseer je document opnieuw." }
                            catch { message = error.localizedDescription }
                        }.disabled(busy)
                    }
                    if busy { ProgressView().controlSize(.small) }
                }
                Text(UIStrings.text("Lokaal bewaard. Bij een nieuwe AI-analyse zoekt CommissieWijzer naar overeenkomsten en spanningen met dit programma. Een selectie op tekstoverlap kan indirecte verbanden missen. PDF vereist leesbare tekst.")).font(.caption).foregroundStyle(.secondary)
                if !message.isEmpty { Text(UIStrings.text(message)).font(.caption) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
        .task { do { program = try PartyProgram.load() } catch { message = "Partijprogramma kon niet worden geladen: \(error.localizedDescription)" } }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .failure(let error): if !ImportFailure.isCancellation(error) { message = error.localizedDescription }
            case .success(let url):
                busy = true; message = "Partijprogramma inladen…"
                Task { @MainActor in
                    defer { busy = false }
                    do {
                        let saved = try await Task.detached(priority: .userInitiated) {
                            let pdf = try OpenPDF.read(url)
                            let saved = PartyProgram(name: pdf.name, pages: pdf.pages, pdf: pdf.data)
                            try saved.save()
                            return saved
                        }.value
                        program = saved; message = "Opgeslagen. Start een nieuwe AI-analyse om dit programma te gebruiken."
                    } catch { message = error.localizedDescription }
                }
            }
        }
    }
}
