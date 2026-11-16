//
//  DesignSystem.swift
//  UUIDs Generator
//

import SwiftUI

/// Color worlds for the hero cards and background glows of each tab.
enum CardTheme {
    case generator, bulk, history, tools

    var tint: Color {
        switch self {
        case .generator: .indigo
        case .bulk: .blue
        case .history: .purple
        case .tools: .teal
        }
    }

    /// 3×3 mesh colors. All have at least 5:1 contrast to white text.
    var meshColors: [Color] {
        switch self {
        case .generator:
            [
                Color(red: 0.20, green: 0.18, blue: 0.62), Color(red: 0.28, green: 0.22, blue: 0.70), Color(red: 0.40, green: 0.20, blue: 0.62),
                Color(red: 0.14, green: 0.20, blue: 0.56), Color(red: 0.26, green: 0.30, blue: 0.74), Color(red: 0.36, green: 0.18, blue: 0.56),
                Color(red: 0.10, green: 0.16, blue: 0.44), Color(red: 0.16, green: 0.20, blue: 0.52), Color(red: 0.26, green: 0.14, blue: 0.46)
            ]
        case .bulk:
            [
                Color(red: 0.02, green: 0.30, blue: 0.62), Color(red: 0.04, green: 0.36, blue: 0.70), Color(red: 0.02, green: 0.40, blue: 0.58),
                Color(red: 0.03, green: 0.24, blue: 0.54), Color(red: 0.06, green: 0.38, blue: 0.72), Color(red: 0.02, green: 0.36, blue: 0.50),
                Color(red: 0.02, green: 0.18, blue: 0.42), Color(red: 0.03, green: 0.24, blue: 0.50), Color(red: 0.02, green: 0.28, blue: 0.42)
            ]
        case .history:
            [
                Color(red: 0.40, green: 0.16, blue: 0.62), Color(red: 0.50, green: 0.20, blue: 0.66), Color(red: 0.62, green: 0.18, blue: 0.52),
                Color(red: 0.34, green: 0.14, blue: 0.56), Color(red: 0.52, green: 0.26, blue: 0.72), Color(red: 0.58, green: 0.16, blue: 0.46),
                Color(red: 0.26, green: 0.10, blue: 0.44), Color(red: 0.36, green: 0.14, blue: 0.52), Color(red: 0.46, green: 0.12, blue: 0.40)
            ]
        case .tools:
            [
                Color(red: 0.02, green: 0.42, blue: 0.40), Color(red: 0.04, green: 0.46, blue: 0.48), Color(red: 0.05, green: 0.36, blue: 0.52),
                Color(red: 0.03, green: 0.36, blue: 0.36), Color(red: 0.06, green: 0.46, blue: 0.46), Color(red: 0.04, green: 0.32, blue: 0.50),
                Color(red: 0.02, green: 0.28, blue: 0.30), Color(red: 0.03, green: 0.32, blue: 0.38), Color(red: 0.04, green: 0.24, blue: 0.42)
            ]
        }
    }
}

/// Mesh gradient background for hero cards.
struct ThemeMesh: View {
    let theme: CardTheme

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.55, 0], [1, 0],
                    [0, 0.45], [0.6, 0.4], [1, 0.55],
                    [0, 1], [0.45, 1], [1, 1]
                ],
                colors: theme.meshColors
            )
            // Soft highlight in the top-left corner for depth.
            RadialGradient(colors: [.white.opacity(0.12), .clear], center: .topLeading, startRadius: 0, endRadius: 320)
        }
    }
}

/// Wallet-style card with a mesh gradient, used for the headline result of each tab.
struct HeroCard<Content: View>: View {
    let theme: CardTheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { ThemeMesh(theme: theme) }
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}

/// Grouped background with a subtle tint glow behind the large title.
private struct ThemedBackground: ViewModifier {
    let theme: CardTheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                ZStack(alignment: .top) {
                    Color(.systemGroupedBackground)
                    LinearGradient(
                        colors: [theme.tint.opacity(0.22), theme.tint.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.45)
                    )
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Places a hero card edge-to-edge inside a list section.
    func heroRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }

    func themedBackground(_ theme: CardTheme) -> some View {
        modifier(ThemedBackground(theme: theme))
    }
}

/// White symbol on a colored rounded square, as used in the Settings app.
struct IconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 29

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
    }
}

/// iOS Settings-style label with a white symbol on a colored rounded square.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color

    init(_ title: LocalizedStringKey, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            IconTile(systemImage: systemImage, color: color)
        }
    }
}

/// Capsule on hero cards, e.g. "Version 4 · Random".
struct CardBadge<Label: View>: View {
    @ViewBuilder let label: Label

    var body: some View {
        label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.18), in: .capsule)
    }
}

/// The app icon, used on the welcome, Pro and settings screens.
struct AppIconView: View {
    var size: CGFloat = 52

    var body: some View {
        Image("AppIconImage")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: .indigo.opacity(0.3), radius: size * 0.15, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

/// A monospaced identifier that copies itself on tap and confirms with a checkmark.
struct CopyableValueRow: View {
    let value: String
    var caption: String?

    @State private var didCopy = false

    var body: some View {
        Button {
            Clipboard.copy(value)
            didCopy = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    IdentifierText(value: value)
                        .font(.callout.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if let caption {
                        Text(verbatim: caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(didCopy ? Color.green : Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .sensoryFeedback(.success, trigger: didCopy) { _, new in new }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
        .accessibilityHint("Copies to the clipboard")
    }
}

/// Icon and title for prominent glass buttons. Both are drawn in white explicitly:
/// the default label renders the icon in the tint color, which vanishes on the tinted
/// background and makes the title look off-center.
struct ProminentButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .fontWeight(.semibold)
            Text(title)
        }
        .foregroundStyle(.white)
    }
}

/// An identifier that wraps only at a hyphen: one line if it fits, otherwise split at the
/// hyphen nearest the middle. Explicit lines are needed because Chinese and Japanese line
/// breaking ignores word joiners and would split hex blocks.
struct IdentifierText: View {
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(verbatim: value)
                .lineLimit(1)
            Text(verbatim: Self.splitAtMiddleHyphen(value))
            Text(verbatim: value.lineBreakingAtHyphens)
        }
    }

    static func splitAtMiddleHyphen(_ value: String) -> String {
        let characters = Array(value)
        let hyphens = characters.indices.filter { characters[$0] == "-" && $0 < characters.count - 1 }
        guard let split = hyphens.min(by: { abs($0 - characters.count / 2) < abs($1 - characters.count / 2) }) else {
            return value.lineBreakingAtHyphens
        }
        return String(characters[...split]) + "\n" + String(characters[(split + 1)...])
    }
}
