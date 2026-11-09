import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, ai, preparation, storage, help

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "Algemeen"
        case .ai: "AI en verwerking"
        case .preparation: "Voorbereiding"
        case .storage: "Opslag en export"
        case .help: "Over en hulp"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .ai: "sparkles"
        case .preparation: "checklist"
        case .storage: "externaldrive"
        case .help: "questionmark.circle"
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        GroupBox(content: content) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .groupBoxStyle(SettingsGroupBoxStyle())
    }
}

struct SettingsGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .readingSurface()
    }
}

/// Settings fields can wrap their label and place the choice below it when space is tight.
struct SettingsMenuPicker<Value: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Value
    let selectedTitle: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, selection: Binding<Value>, selectedTitle: String,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self._selection = selection
        self.selectedTitle = selectedTitle
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                fieldLabel.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                menu.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel
                menu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldLabel: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    private var menu: some View {
        Menu {
            Picker(title, selection: $selection, content: content).pickerStyle(.menu)
        } label: {
            #if os(iOS)
            HStack(spacing: 8) {
                Text(selectedTitle)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.callout)
            .foregroundStyle(.primary)
            #else
            Text(selectedTitle)
                .font(.callout)
                .foregroundStyle(.primary)
            #endif
        }
        #if os(iOS)
        .menuIndicator(.hidden)
        #endif
        .focusMenu()
        .accessibilityLabel(title)
        .accessibilityValue(selectedTitle)
    }
}

struct SettingsNavigationRowStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        configuration.label
            .font(.callout.weight(isSelected ? .semibold : .medium))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(shape)
            .background(isSelected ? AppTheme.selection : isHovered || configuration.isPressed ? AppTheme.buttonHover : .clear, in: shape)
            .overlay {
                if isFocused || (isSelected && contrast == .increased) {
                    shape.strokeBorder(isFocused ? AppTheme.focusRing : Color.primary.opacity(0.7), lineWidth: 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onHover { isHovered = $0 }
    }
}
