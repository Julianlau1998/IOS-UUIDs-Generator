//
//  HistoryView.swift
//  UUIDs Generator
//

import SwiftData
import SwiftUI

/// Every identifier the user copied or shared, with favorites, notes and search.
struct HistoryView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var items: [HistoryItem]

    @State private var searchText = ""
    @State private var showsFavoritesOnly = false
    @State private var editingItem: HistoryItem?
    @State private var noteDraft = ""
    @State private var isConfirmingClear = false
    @State private var qrValue: QRValue?

    private var filteredItems: [HistoryItem] {
        items.filter { item in
            (!showsFavoritesOnly || item.isFavorite)
                && (searchText.isEmpty
                    || item.value.localizedStandardContains(searchText)
                    || item.note.localizedStandardContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !items.isEmpty {
                    AdSection(slot: 2)
                }

                if !filteredItems.isEmpty {
                    Section {
                        ForEach(filteredItems) { item in
                            row(for: item)
                        }
                        .onDelete { offsets in
                            let visible = filteredItems
                            offsets.map { visible[$0] }.forEach(modelContext.delete)
                        }
                    } footer: {
                        footer
                    }
                }
            }
            .themedBackground(.history)
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search IDs and notes")
            .overlay {
                emptyState
            }
            .toolbar {
                SettingsToolbarItem()
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle(isOn: $showsFavoritesOnly.animation()) {
                            Label("Favorites Only", systemImage: "star")
                        }
                        Section {
                            Button("Clear History…", systemImage: "trash", role: .destructive) {
                                isConfirmingClear = true
                            }
                            .disabled(items.isEmpty)
                        }
                    } label: {
                        Label("Filter", systemImage: showsFavoritesOnly
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
                if !filteredItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ExportMenu(.share, title: String(localized: "UUID History")) {
                            filteredItems.map(\.value)
                        }
                    }
                }
            }
            .confirmationDialog("Clear History", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Delete All Except Favorites", role: .destructive) {
                    items.filter { !$0.isFavorite }.forEach(modelContext.delete)
                }
                Button("Delete Everything", role: .destructive) {
                    items.forEach(modelContext.delete)
                }
            } message: {
                Text("This can't be undone.")
            }
            .alert("Note", isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            )) {
                TextField("e.g. User table, test fixture", text: $noteDraft)
                Button("Save") {
                    editingItem?.note = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    editingItem = nil
                }
                Button("Cancel", role: .cancel) {
                    editingItem = nil
                }
            }
            .sheet(item: $qrValue) { value in
                QRCodeSheet(value: value.text)
            }
        }
    }

    private func row(for item: HistoryItem) -> some View {
        HistoryRow(item: item)
            .swipeActions(edge: .leading) {
                Button {
                    withAnimation { item.isFavorite.toggle() }
                } label: {
                    Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star.fill")
                }
                .tint(.yellow)
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    modelContext.delete(item)
                }
                Button("Note", systemImage: "note.text") {
                    noteDraft = item.note
                    editingItem = item
                }
                .tint(.indigo)
            }
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") {
                    Clipboard.copy(item.value)
                }
                ShareLink(item: item.value)
                Button(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star") {
                    item.isFavorite.toggle()
                }
                Button("Edit Note", systemImage: "note.text") {
                    noteDraft = item.note
                    editingItem = item
                }
                Button("QR Code", systemImage: "qrcode") {
                    qrValue = QRValue(text: item.value)
                }
                if UUIDInspection.parse(item.value) != nil {
                    Button("Inspect", systemImage: "magnifyingglass") {
                        router.inspect(item.value)
                    }
                }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    modelContext.delete(item)
                }
            }
    }

    @ViewBuilder
    private var footer: some View {
        if !store.isPro {
            VStack(alignment: .leading, spacing: 6) {
                Text("The last \(HistoryStore.freeLimit) entries are kept. Favorites are never removed.")
                Button("Unlimited history with Pro") {
                    router.showPaywall()
                }
                .font(.footnote.weight(.semibold))
            }
        } else if !settings.savesHistory {
            Text("Saving to the history is turned off in Settings.")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label("No History Yet", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            } description: {
                Text(settings.savesHistory
                     ? "UUIDs you copy or share appear here."
                     : "Saving to the history is turned off in Settings.")
            }
        } else if filteredItems.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star", description: Text("Swipe right on an entry to mark it as a favorite."))
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

private struct QRValue: Identifiable {
    let text: String
    var id: String { text }
}

private struct HistoryRow: View {
    let item: HistoryItem

    @State private var didCopy = false

    var body: some View {
        Button {
            Clipboard.copy(item.value)
            didCopy = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: item.value)
                        .font(.callout.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 6) {
                        KindBadge(kind: item.kind)
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Favorite")
                        }
                        Text(item.createdAt, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !item.note.isEmpty {
                        Label(item.note, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(didCopy ? Color.green : Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 2)
        }
        .sensoryFeedback(.success, trigger: didCopy) { _, new in new }
        .task(id: didCopy) {
            guard didCopy else { return }
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}
