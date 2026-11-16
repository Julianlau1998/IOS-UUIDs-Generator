//
//  ToolsView.swift
//  UUIDs Generator
//

import SwiftData
import SwiftUI

enum ToolRoute: Hashable {
    case inspector(String)
    case nameBased
    case ulid
    case nanoID
}

/// Inspector, name-based UUIDs and other identifier formats.
struct ToolsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var path: [ToolRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: ToolRoute.inspector("")) {
                        ToolRow(title: "Inspect & Validate", subtitle: "Version, variant, timestamp and all notations", systemImage: "magnifyingglass", color: .teal)
                    }
                }

                AdSection(slot: 3)

                Section("Generators") {
                    proTool(.nameBased, feature: .nameBased, title: "Name-Based UUID", subtitle: "Versions 3 and 5 – same name, same UUID", systemImage: "number", color: .indigo)
                    proTool(.ulid, feature: .ulid, title: "ULID", subtitle: "Sortable 26-character IDs", systemImage: "arrow.up.arrow.down", color: .blue)
                    proTool(.nanoID, feature: .nanoID, title: "NanoID", subtitle: "Short, URL-safe random IDs", systemImage: "textformat.abc", color: .pink)
                }

                Section {
                    CopyableValueRow(value: UUIDFactory.nilUUID.uuidString.lowercased(), caption: String(localized: "Nil UUID – all bits zero"))
                    CopyableValueRow(value: UUIDFactory.maxUUID.uuidString.lowercased(), caption: String(localized: "Max UUID – all bits one"))
                } header: {
                    Text("Special Values")
                }
            }
            .themedBackground(.tools)
            .navigationTitle("Tools")
            .toolbar { SettingsToolbarItem() }
            .navigationDestination(for: ToolRoute.self) { route in
                switch route {
                case .inspector(let input): InspectorView(initialText: input)
                case .nameBased: NameBasedView().onAppear { store.consume(.nameBased) }
                case .ulid: OtherIDView(kind: .ulid).onAppear { store.consume(.ulid) }
                case .nanoID: OtherIDView(kind: .nanoID).onAppear { store.consume(.nanoID) }
                }
            }
            .onChange(of: router.inspectorInput, initial: true) { _, input in
                guard let input else { return }
                path = [.inspector(input)]
                router.inspectorInput = nil
            }
        }
    }

    @ViewBuilder
    private func proTool(_ route: ToolRoute, feature: ProFeature, title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String, color: Color) -> some View {
        if store.canUse(feature) {
            NavigationLink(value: route) {
                ToolRow(title: title, subtitle: subtitle, systemImage: systemImage, color: color)
            }
        } else {
            ProLockedRow(title: title, subtitle: subtitle, systemImage: systemImage, color: color, feature: feature)
        }
    }
}

private struct ToolRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: systemImage, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Inspector

struct InspectorView: View {
    @State private var text: String

    init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }

    private var uuid: UUID? { UUIDInspection.parse(text) }

    var body: some View {
        List {
            Section {
                TextField("Paste or type a UUID", text: $text, axis: .vertical)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .lineLimit(1...3)
                HStack {
                    PasteButton(payloadType: String.self) { strings in
                        text = strings.first ?? ""
                    }
                    .buttonBorderShape(.capsule)
                    .labelStyle(.titleAndIcon)
                    Spacer()
                    Button("Example") {
                        text = UUIDFactory.v7().uuidString.lowercased()
                    }
                    .buttonStyle(.glass)
                }
            } footer: {
                Text("Accepts the usual notations: with or without hyphens, in braces or with a URN prefix.")
            }

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let uuid {
                    result(UUIDInspection(uuid: uuid))
                } else {
                    Section {
                        Label("Not a valid UUID", systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                            .font(.headline)
                    } footer: {
                        Text("A UUID has 32 hexadecimal digits, usually grouped as 8-4-4-4-12.")
                    }
                }
            }
        }
        .themedBackground(.tools)
        .navigationTitle("Inspect")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: uuid) { old, new in old == nil && new != nil }
    }

    @ViewBuilder
    private func result(_ info: UUIDInspection) -> some View {
        Section {
            HeroCard(theme: .tools) {
                VStack(alignment: .leading, spacing: 10) {
                    CardBadge {
                        Label("Valid UUID", systemImage: "checkmark.seal.fill")
                    }
                    Text(info.versionDescription)
                        .font(.title3.bold())
                    if let date = info.date {
                        Text("Created \(date.formatted(date: .abbreviated, time: .standard))")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .heroRow()
        }

        Section("Details") {
            LabeledContent("Version") {
                Text(info.version, format: .number)
            }
            LabeledContent("Variant") {
                Text(info.variant.title)
            }
            if let date = info.date {
                LabeledContent("Timestamp") {
                    Text(date, format: .dateTime.year().month().day().hour().minute().second().secondFraction(.fractional(3)))
                }
                LabeledContent("Age") {
                    Text(date, format: .relative(presentation: .named))
                }
            }
        }

        Section("Notations") {
            // Some notations can be identical (e.g. for digits only), so index by position.
            ForEach(Array(info.representations.enumerated()), id: \.offset) { _, representation in
                CopyableValueRow(value: representation.value, caption: String(localized: representation.title))
            }
        }
    }
}

// MARK: - Name-based

struct NameBasedView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var version: NameBasedVersion = .v5
    @State private var namespace: UUIDNamespace = .dns
    @State private var customNamespace = ""
    @State private var name = ""
    @State private var didCopy = false

    private var namespaceUUID: UUID? {
        namespace == .custom ? UUIDInspection.parse(customNamespace) : namespace.uuid
    }

    private var result: String? {
        guard let namespaceUUID, !name.isEmpty else { return nil }
        return settings.style.format(UUIDFactory.nameBased(version, namespace: namespaceUUID, name: name))
    }

    var body: some View {
        List {
            Section {
                HeroCard(theme: .tools) {
                    VStack(alignment: .leading, spacing: 16) {
                        CardBadge { Text(version.title) }
                        IdentifierText(value: result ?? "–")
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: result)
                        HStack(spacing: 10) {
                            Button(action: copy) {
                                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            if let result {
                                ShareLink(item: result) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .disabled(result == nil)
                    }
                }
                .heroRow()
            }

            Section {
                Picker("Version", selection: $version) {
                    ForEach(NameBasedVersion.allCases) { version in
                        Text(version.title).tag(version)
                    }
                }
                Picker("Namespace", selection: $namespace) {
                    ForEach(UUIDNamespace.allCases) { namespace in
                        Text(namespace.title).tag(namespace)
                    }
                }
                if namespace == .custom {
                    TextField("Namespace UUID", text: $customNamespace)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                TextField(namePrompt, text: $name)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Input")
            } footer: {
                if namespace == .custom, !customNamespace.isEmpty, namespaceUUID == nil {
                    Text("The custom namespace must be a valid UUID.")
                        .foregroundStyle(.red)
                } else {
                    Text("Name-based UUIDs are deterministic: the same namespace and name always give the same UUID. Version 5 is recommended.")
                }
            }
        }
        .themedBackground(.tools)
        .navigationTitle("Name-Based UUID")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: didCopy) { _, new in new }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }

    private var namePrompt: LocalizedStringKey {
        switch namespace {
        case .dns: "Name, e.g. example.com"
        case .url: "Name, e.g. https://example.com"
        case .oid: "Name, e.g. 1.3.6.1"
        case .x500: "Name, e.g. cn=John Doe"
        case .custom: "Name"
        }
    }

    private func copy() {
        guard let result else { return }
        Clipboard.copy(result)
        didCopy = true
        if settings.savesHistory {
            HistoryStore.add(result, kind: version.historyKind, isPro: store.isPro, context: modelContext)
        }
    }
}

// MARK: - ULID & NanoID

struct OtherIDView: View {
    enum Kind {
        case ulid, nanoID

        var title: LocalizedStringKey {
            switch self {
            case .ulid: "ULID"
            case .nanoID: "NanoID"
            }
        }

        var historyKind: String {
            switch self {
            case .ulid: "ULID"
            case .nanoID: "NanoID"
            }
        }
    }

    let kind: Kind

    @Environment(AppSettings.self) private var settings
    @Environment(StoreManager.self) private var store
    @Environment(AdsManager.self) private var ads
    @Environment(\.modelContext) private var modelContext

    @AppStorage("nanoID.length") private var length = 21
    @AppStorage("nanoID.alphabet") private var alphabet: NanoIDAlphabet = .urlSafe

    @State private var value = ""
    @State private var didCopy = false

    var body: some View {
        List {
            Section {
                HeroCard(theme: .tools) {
                    VStack(alignment: .leading, spacing: 16) {
                        CardBadge { Text(kind.title) }
                        Text(verbatim: value.lineBreakingAtHyphens)
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.4)
                            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                            .contentTransition(.numericText())
                        HStack(spacing: 10) {
                            Button(action: copy) {
                                Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            ShareLink(item: value) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                }
                .heroRow()
            }

            Section {
                Button(action: generate) {
                    ProminentButtonLabel("Generate", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            switch kind {
            case .ulid:
                Section {
                    if let date = ulidDate {
                        LabeledContent("Timestamp") {
                            Text(date, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                        }
                    }
                } footer: {
                    Text("ULIDs start with a 48-bit millisecond timestamp followed by 80 random bits, written in Crockford's Base32. They sort by creation time.")
                }
            case .nanoID:
                Section {
                    Stepper(value: $length, in: 4...64) {
                        LabeledContent("Length") {
                            Text(length, format: .number)
                                .monospacedDigit()
                        }
                    }
                    Picker("Characters", selection: $alphabet) {
                        ForEach(NanoIDAlphabet.allCases) { alphabet in
                            Text(alphabet.title).tag(alphabet)
                        }
                    }
                } header: {
                    Text("Options")
                } footer: {
                    Text("The default 21 URL-safe characters give about the same collision resistance as a UUID v4.")
                }
            }
        }
        .themedBackground(.tools)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: value)
        .sensoryFeedback(.success, trigger: didCopy) { _, new in new }
        .onAppear {
            if value.isEmpty { value = makeValue() }
        }
        .onChange(of: length) { value = makeValue() }
        .onChange(of: alphabet) { value = makeValue() }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }

    /// Time encoded in the first 10 characters of a ULID.
    private var ulidDate: Date? {
        guard kind == .ulid, value.count == 26 else { return nil }
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        var milliseconds: UInt64 = 0
        for character in value.prefix(10) {
            guard let digit = alphabet.firstIndex(of: character) else { return nil }
            milliseconds = milliseconds << 5 | UInt64(digit)
        }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    private func makeValue() -> String {
        switch kind {
        case .ulid: UUIDFactory.ulid()
        case .nanoID: UUIDFactory.nanoID(length: length, alphabet: alphabet)
        }
    }

    private func generate() {
        withAnimation(.snappy) { value = makeValue() }
        didCopy = false
        if settings.copiesAutomatically { copy() }
        ads.registerGeneration(isPro: store.isPro)
    }

    private func copy() {
        Clipboard.copy(value)
        didCopy = true
        if settings.savesHistory {
            HistoryStore.add(value, kind: kind.historyKind, isPro: store.isPro, context: modelContext)
        }
    }
}
