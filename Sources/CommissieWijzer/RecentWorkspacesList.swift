import SwiftUI

struct RecentWorkspacesList: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool
    let entries: [RecentWorkspaceDocuments.Entry]
    let disabled: Bool
    let open: (RecentWorkspaceDocuments.Entry) -> Void
    let removeFromList: ((RecentWorkspaceDocuments.Entry) -> Void)?
    let relocate: ((RecentWorkspaceDocuments.Entry) -> Void)?
    let statusMessage: ((RecentWorkspaceDocuments.Entry) -> String?)?

    init(entries: [RecentWorkspaceDocuments.Entry], disabled: Bool = false,
         open: @escaping (RecentWorkspaceDocuments.Entry) -> Void,
         removeFromList: ((RecentWorkspaceDocuments.Entry) -> Void)? = nil,
         relocate: ((RecentWorkspaceDocuments.Entry) -> Void)? = nil,
         statusMessage: ((RecentWorkspaceDocuments.Entry) -> String?)? = nil,
         isInitiallyExpanded: Bool = false) {
        self.entries = entries
        self.disabled = disabled
        self.open = open
        self.removeFromList = removeFromList
        self.relocate = relocate
        self.statusMessage = statusMessage
        _isExpanded = State(initialValue: isInitiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                ForEach(entries) { entry in
                    entryButton(entry)
                }
                Text(UIStrings.text("Opent de bewaarde resultaten zonder nieuwe AI-analyse."))
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
        } label: {
            HStack(spacing: 8) {
                Text(UIStrings.text("Recente werkdocumenten"))
                    .font(.callout.weight(.semibold))
                Text(entries.count, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .disclosureGroupStyle(FullRowDisclosureGroupStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .readingSurface()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isExpanded)
        .accessibilityIdentifier("welcome-recent-workspaces")
    }

    private func entryButton(_ entry: RecentWorkspaceDocuments.Entry) -> some View {
        let entryStatus = status(for: entry)
        return Button { open(entry) } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.callout)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if let folder = distinguishingFolder(for: entry) {
                        Text(folder).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    if let entryStatus {
                        Text(entryStatus).font(.caption).foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .platformTouchTarget()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.path)
        .accessibilityLabel(UIStrings.text("Werkdocument openen") + ": " + entry.displayName)
        .accessibilityValue([entryStatus, entry.path].compactMap { $0 }.joined(separator: ", "))
        .accessibilityActions { entryActions(entry) }
        .contextMenu { entryActions(entry) }
        .disabled(disabled)
    }

    private func distinguishingFolder(for entry: RecentWorkspaceDocuments.Entry) -> String? {
        let matching = entries.filter {
            $0.id != entry.id && $0.displayName.localizedCaseInsensitiveCompare(entry.displayName) == .orderedSame
        }
        guard !matching.isEmpty else { return nil }
        let folder = URL(fileURLWithPath: entry.path).deletingLastPathComponent()
        let components = folder.pathComponents.dropFirst()
        let otherFolders = matching.map { URL(fileURLWithPath: $0.path).deletingLastPathComponent().pathComponents.dropFirst() }
        for count in 1..<max(2, components.count) {
            let suffix = components.suffix(count)
            if !otherFolders.contains(where: { $0.suffix(count).elementsEqual(suffix) }) {
                return suffix.isEmpty ? folder.path : suffix.joined(separator: "/")
            }
        }
        return folder.path
    }

    @ViewBuilder private func entryActions(_ entry: RecentWorkspaceDocuments.Entry) -> some View {
        if let relocate {
            Button(UIStrings.text("Verplaats of herstel…"), systemImage: "folder") { relocate(entry) }
                .disabled(disabled)
        }
        if let removeFromList {
            Button(UIStrings.text("Verwijder uit lijst"), systemImage: "minus.circle", role: .destructive) { removeFromList(entry) }
                .disabled(disabled)
        }
    }

    private func status(for entry: RecentWorkspaceDocuments.Entry) -> String? {
        if let statusMessage { return statusMessage(entry) }
        return RecentWorkspaceDocuments.shared.statusMessage(for: entry)
    }
}
