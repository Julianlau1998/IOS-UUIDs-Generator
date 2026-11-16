//
//  GeneratorView.swift
//  UUIDs Generator
//

import SwiftData
import SwiftUI

/// The main screen: one UUID, big and ready to copy.
struct GeneratorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StoreManager.self) private var store
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query private var recent: [HistoryItem]

    @State private var uuid: UUID?
    @State private var didCopy = false
    @State private var isShowingQRCode = false
    /// The last value written to the history, so copying twice doesn't add duplicates.
    @State private var recordedValue: String?
    @State private var pendingIntentResult: AppRouter.IntentResult?

    init() {
        var descriptor = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 3
        _recent = Query(descriptor)
    }

    private var formatted: String {
        uuid.map(settings.style.format) ?? ""
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                Section {
                    resultCard
                        .heroRow()
                }

                Section {
                    Button(action: generate) {
                        ProminentButtonLabel("New UUID", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Version", selection: $settings.version) {
                        ForEach(UUIDVersion.allCases) { version in
                            Text(verbatim: "v\(version.number)").tag(version)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                } header: {
                    Text("Version")
                } footer: {
                    Text(settings.version.explanation)
                }

                Section("Format") {
                    Toggle(isOn: $settings.isUppercase) {
                        SettingsLabel("Uppercase", systemImage: "textformat.size.larger", color: .blue)
                    }
                    Toggle(isOn: $settings.hasHyphens) {
                        SettingsLabel("Hyphens", systemImage: "minus", color: .indigo)
                    }
                    Toggle(isOn: $settings.hasBraces) {
                        SettingsLabel("Braces { }", systemImage: "curlybraces", color: .purple)
                    }
                    Toggle(isOn: $settings.hasURNPrefix) {
                        SettingsLabel("URN Prefix", systemImage: "link", color: .teal)
                    }
                }

                AdSection(slot: 0)

                if !recent.isEmpty {
                    Section {
                        ForEach(recent) { item in
                            CopyableValueRow(value: item.value, caption: item.createdAt.formatted(.relative(presentation: .named)))
                        }
                        Button("Show History") {
                            router.selectedTab = .history
                        }
                    } header: {
                        Text("Recently Copied")
                    }
                }
            }
            .themedBackground(.generator)
            .navigationTitle("UUID Generator")
            .toolbar { SettingsToolbarItem() }
            .sheet(isPresented: $isShowingQRCode) {
                QRCodeSheet(value: formatted)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: uuid)
            .sensoryFeedback(.success, trigger: didCopy) { _, new in new }
            .onChange(of: settings.version) {
                if let pending = pendingIntentResult {
                    pendingIntentResult = nil
                    applyIntentResult(pending)
                } else {
                    generate()
                }
            }
            .onChange(of: settings.style) {
                didCopy = false
            }
            .task(id: didCopy) {
                guard didCopy else { return }
                try? await Task.sleep(for: .seconds(2))
                didCopy = false
            }
            .onChange(of: router.intentResult, initial: true) { _, result in
                guard let result else { return }
                router.intentResult = nil
                showIntentResult(result)
            }
            .task {
                // Building the first Core Image context takes a moment; do it before the QR button is tapped.
                await QRCode.prepare()
            }
            .onAppear {
                #if DEBUG
                if ScreenshotDemo.isActive {
                    uuid = ScreenshotDemo.uuid
                    if ScreenshotDemo.screen == "qr" {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            isShowingQRCode = true
                        }
                    }
                }
                #endif
                if uuid == nil {
                    uuid = UUIDFactory.make(settings.version)
                }
            }
        }
    }

    private var resultCard: some View {
        HeroCard(theme: .generator) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    CardBadge {
                        Text("\(Text(settings.version.title)) · \(Text(settings.version.subtitle))")
                    }
                    Spacer()
                    if didCopy {
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                IdentifierText(value: formatted)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                    .accessibilityLabel(Text(verbatim: formatted))
                    .accessibilityHint("Double-tap to copy")

                HStack(spacing: 10) {
                    Button(action: copy) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    // Share and QR stay icon-only so "Copy" always fits, also in German.
                    ShareLink(item: formatted) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .simultaneousGesture(TapGesture().onEnded(record))
                    Button {
                        record()
                        isShowingQRCode = true
                    } label: {
                        Label("QR Code", systemImage: "qrcode")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("QR Code")
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .animation(.snappy, value: didCopy)
        }
        .contentShape(.rect)
        .onTapGesture(perform: copy)
    }

    /// Shows a UUID from Siri/Shortcuts and treats it like a regular generation.
    private func showIntentResult(_ result: AppRouter.IntentResult) {
        if settings.version != result.version {
            // Changing the version regenerates; the onChange handler shows this UUID instead.
            pendingIntentResult = result
            settings.version = result.version
        } else {
            applyIntentResult(result)
        }
    }

    private func applyIntentResult(_ result: AppRouter.IntentResult) {
        withAnimation(.snappy) { uuid = result.uuid }
        record()
        ads.registerGeneration(isPro: store.isPro)
    }

    private func generate() {
        withAnimation(.snappy) {
            uuid = UUIDFactory.make(settings.version)
        }
        didCopy = false
        if settings.copiesAutomatically {
            copy()
        }
        ads.registerGeneration(isPro: store.isPro)
    }

    private func copy() {
        Clipboard.copy(formatted)
        didCopy = true
        record()
    }

    /// Copied, shared or shown UUIDs go to the history.
    private func record() {
        guard settings.savesHistory, recordedValue != formatted, !formatted.isEmpty else { return }
        HistoryStore.add(formatted, kind: settings.version.historyKind, isPro: store.isPro, context: modelContext)
        recordedValue = formatted
    }
}
