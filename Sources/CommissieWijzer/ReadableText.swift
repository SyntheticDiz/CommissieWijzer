import SwiftUI

/// Readable, selectable presentation for ordinary prose. The display chunks
/// concatenate to the original value; the stored text and its callers are untouched.
struct ReadableText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(SummaryDisplayText.chunks(text).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
