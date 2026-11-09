import SwiftUI
import CommissieCore

struct AnalysisFocus {
    let topics: String
    var keywords: String = ""
    var exclusive: Bool = false
    var terms: [String] { [] }
    var prompt: String { topics.trimmingCharacters(in: .whitespacesAndNewlines) }
    var themes: [Theme] { [] }
}

struct FocusEditor: View {
    @AppStorage("uiLanguage") private var uiLanguage = "nl"
    @Environment(\.dismiss) private var dismiss
    @AppStorage("savedProgramFocus") private var savedFocus = ""
    @State private var topics = ""
    @State private var saveForLater = false
    var initial: String
    let apply: (AnalysisFocus) -> Void
    var body: some View {
        editorContent
            .padding(24).platformSheetSize(width: 570)
            .background(AppTheme.background)
            .onAppear { topics = initial }
            .buttonStyle(FocusSecondaryButtonStyle())
    }

    @ViewBuilder private var editorContent: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            Text(UIStrings.text("Eigen aandachtspunten")).font(.title2.bold())
            Text(UIStrings.text("Het opgeslagen partijprogramma blijft altijd het beoordelingskader. Je kunt hier aanvullende onderwerpen of onderzoeksvragen meegeven.")).foregroundStyle(.secondary)
            TextEditor(text: $topics).font(.body).frame(height: 160).padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(UIStrings.text("Aanvullende aandachtspunten"))
            Toggle(UIStrings.text("Bewaar voor volgende documenten en appstarts"), isOn: $saveForLater)
            Text("\(topics.utf8.count) / 1.000 bytes").font(.caption)
            HStack {
                Button(UIStrings.text("Wis bewaarde aandachtspunten"), role: .destructive) { savedFocus = ""; topics = "" }
                Spacer()
                Button(UIStrings.text("Annuleer")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(UIStrings.text("Toepassen")) {
                    if saveForLater { savedFocus = topics }
                    apply(.init(topics: topics)); dismiss()
                }.disabled(topics.utf8.count > 1000).buttonStyle(FocusPrimaryButtonStyle())
            }
        }
        #else
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(UIStrings.text("Eigen aandachtspunten")).font(.title2.bold())
                    Text(UIStrings.text("Het opgeslagen partijprogramma blijft altijd het beoordelingskader. Je kunt hier aanvullende onderwerpen of onderzoeksvragen meegeven.")).foregroundStyle(.secondary)
                    TextEditor(text: $topics).font(.body).frame(height: 160).padding(8)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel(UIStrings.text("Aanvullende aandachtspunten"))
                    Toggle(UIStrings.text("Bewaar voor volgende documenten en appstarts"), isOn: $saveForLater)
                    Text("\(topics.utf8.count) / 1.000 bytes").font(.caption)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Button(UIStrings.text("Wis bewaarde aandachtspunten"), role: .destructive) { savedFocus = ""; topics = "" }
                    Spacer()
                    Button(UIStrings.text("Annuleer")) { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(UIStrings.text("Toepassen")) {
                        if saveForLater { savedFocus = topics }
                        apply(.init(topics: topics)); dismiss()
                    }.disabled(topics.utf8.count > 1000).buttonStyle(FocusPrimaryButtonStyle())
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button(UIStrings.text("Wis bewaarde aandachtspunten"), role: .destructive) { savedFocus = ""; topics = "" }
                    HStack {
                        Button(UIStrings.text("Annuleer")) { dismiss() }.keyboardShortcut(.cancelAction)
                        Spacer()
                        Button(UIStrings.text("Toepassen")) {
                            if saveForLater { savedFocus = topics }
                            apply(.init(topics: topics)); dismiss()
                        }.disabled(topics.utf8.count > 1000).buttonStyle(FocusPrimaryButtonStyle())
                    }
                }
            }
        }
        #endif
    }
}
