//
//  BulkView.swift
//  UUIDs Generator
//

import SwiftUI

/// Generates many UUIDs at once, to copy or export.
struct BulkView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(StoreManager.self) private var store
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router

    @State private var results: [UUID] = []
    @State private var isGenerating = false
    @State private var didCopyAll = false
    @State private var isOfferingAd = false
    /// Bumped after each generation to scroll the new list into view.
    @State private var resultsRevision = 0
    @FocusState private var isCountFocused: Bool

    /// Rows shown in the list; longer lists are only available as a file or via "Copy All".
    private static let previewLimit = 100

    private var presets: [Int] {
        store.isPro ? [100, 1_000, 10_000, 100_000] : [10, 100, 500, 1_000]
    }

    private var exceedsLimit: Bool { settings.bulkCount > store.bulkLimit }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    controlsCard
                        .heroRow()
                } footer: {
                    if exceedsLimit {
                        limitFooter
                    }
                }

                Section {
                    Button(action: generate) {
                        Group {
                            if isGenerating {
                                ProgressView()
                            } else {
                                ProminentButtonLabel("Generate \(max(1, settings.bulkCount).formatted()) UUIDs",
                                                     systemImage: store.isPro || !ads.isRewardedAdReady ? "square.stack.3d.up.fill" : "play.rectangle.fill")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(isGenerating)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                AdSection(slot: 1)

                if !results.isEmpty {
                    Section {
                        resultActions
                            .id("results")
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("\(results.count.formatted()) UUIDs")
                    }
                    .listSectionSpacing(10)

                    Section {
                        // Only a preview is listed; the file and "Copy All" contain everything.
                        ForEach(results.indices.prefix(Self.previewLimit), id: \.self) { index in
                            BulkRow(index: index, value: settings.style.format(results[index]))
                        }
                    } footer: {
                        if results.count > Self.previewLimit {
                            Label("Showing the first \(Self.previewLimit) of \(results.count.formatted()) UUIDs. Save or share the file to get the complete list.",
                                  systemImage: "doc.text")
                                .padding(.top, 6)
                        }
                    }
                }
            }
            .onChange(of: resultsRevision) {
                // The list starts below the fold; jump to it so it's obvious where it went.
                withAnimation(.smooth) {
                    // Slightly below the top, so the header isn't hidden under the navigation bar.
                    proxy.scrollTo("results", anchor: UnitPoint(x: 0.5, y: 0.22))
                }
            }
            }
            .themedBackground(.bulk)
            .navigationTitle("Bulk")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                SettingsToolbarItem()
                if !results.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear", systemImage: "trash", role: .destructive) {
                            withAnimation { results = [] }
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isCountFocused = false }
                }
            }
            .alert("Generate List", isPresented: $isOfferingAd) {
                Button("Watch Ad") {
                    ads.showRewardedAd {
                        startGeneration(showsInterstitial: false)
                    }
                }
                Button("Get Pro") {
                    router.showPaywall()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Watch a short ad to create this list – or get Pro for lists of up to \(StoreManager.proBulkLimit.formatted()) without ads.")
            }
            .sensoryFeedback(.success, trigger: resultsRevision)
            .sensoryFeedback(.success, trigger: didCopyAll) { _, new in new }
            .task(id: didCopyAll) {
                guard didCopyAll else { return }
                try? await Task.sleep(for: .seconds(2))
                didCopyAll = false
            }
        }
    }

    private var controlsCard: some View {
        @Bindable var settings = settings

        return HeroCard(theme: .bulk) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    CardBadge { Text("Amount") }
                    Spacer()
                    Menu {
                        Picker("Version", selection: $settings.version) {
                            ForEach(UUIDVersion.allCases) { version in
                                Text("\(Text(version.title)) · \(Text(version.subtitle))").tag(version)
                            }
                        }
                    } label: {
                        CardBadge {
                            HStack(spacing: 4) {
                                Text(verbatim: "v\(settings.version.number)")
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                        }
                    }
                    .accessibilityLabel("Version")
                }

                TextField("Amount", value: $settings.bulkCount, format: .number)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .focused($isCountFocused)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)

                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            settings.bulkCount = preset
                            isCountFocused = false
                        } label: {
                            Text(preset.formatted())
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .tint(settings.bulkCount == preset ? .white : nil)
                    }
                }

                Text(store.isPro
                     ? "Up to \(StoreManager.proBulkLimit.formatted()) at once"
                     : "Up to \(StoreManager.freeBulkLimit.formatted()) per list with a short ad · Pro: \(StoreManager.proBulkLimit.formatted()) without ads")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    private var limitFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("The maximum is \(store.bulkLimit.formatted()) at once.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            if !store.isPro {
                Button("Generate up to \(StoreManager.proBulkLimit.formatted()) with Pro") {
                    router.showPaywall()
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.top, 8)
    }

    /// Pro generates right away; free lists need a rewarded ad. If no rewarded ad is
    /// available (no fill, no consent), the list is created anyway so the feature never
    /// dead-ends, and the usual interstitial rules apply.
    private func generate() {
        isCountFocused = false
        if exceedsLimit {
            router.showPaywall()
            return
        }
        if store.isPro || !ads.isRewardedAdReady {
            startGeneration(showsInterstitial: !store.isPro)
        } else {
            isOfferingAd = true
        }
    }

    private func startGeneration(showsInterstitial: Bool) {
        let count = min(max(1, settings.bulkCount), store.bulkLimit)
        settings.bulkCount = count
        let version = settings.version
        isGenerating = true
        Task {
            let uuids = await Task.detached(priority: .userInitiated) {
                UUIDFactory.make(version, count: count)
            }.value
            results = uuids
            isGenerating = false
            resultsRevision += 1
            if showsInterstitial {
                ads.registerCompletedAction(isPro: store.isPro)
            }
        }
    }

    /// Save, share and copy for the whole list, right above it.
    private var resultActions: some View {
        HStack(spacing: 10) {
            ExportMenu(action: .save, title: String(localized: "\(results.count) UUIDs"), values: { results.map(settings.style.format) }) {
                ActionTileLabel(title: "Save", systemImage: "folder")
            }
            ExportMenu(action: .share, title: String(localized: "\(results.count) UUIDs"), values: { results.map(settings.style.format) }) {
                ActionTileLabel(title: "Share", systemImage: "square.and.arrow.up")
            }
            Button(action: copyAll) {
                ActionTileLabel(title: didCopyAll ? "Copied" : "Copy All", systemImage: didCopyAll ? "checkmark" : "doc.on.doc")
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
    }

    private func copyAll() {
        Clipboard.copy(results.map(settings.style.format).joined(separator: "\n"))
        didCopyAll = true
    }
}

private struct BulkRow: View {
    let index: Int
    let value: String

    @State private var didCopy = false

    var body: some View {
        Button {
            Clipboard.copy(value)
            didCopy = true
        } label: {
            HStack(spacing: 10) {
                Text(index + 1, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, alignment: .trailing)
                Text(verbatim: value)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.footnote)
                    .foregroundStyle(didCopy ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(value) }
            ShareLink(item: value)
        }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}

/// Icon above a short title; the explicit fonts keep menus and buttons identical.
private struct ActionTileLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .frame(height: 24)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
