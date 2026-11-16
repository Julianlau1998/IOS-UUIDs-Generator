//
//  HistoryItem.swift
//  UUIDs Generator
//

import Foundation
import SwiftData

/// A generated identifier the user may want to find again.
@Model
final class HistoryItem {
    var value: String = ""
    /// Short type label, e.g. "v4", "v5", "ULID", "NanoID".
    var kind: String = ""
    var createdAt: Date = Date.now
    var isFavorite: Bool = false
    var note: String = ""

    init(value: String, kind: String, createdAt: Date = .now) {
        self.value = value
        self.kind = kind
        self.createdAt = createdAt
    }
}

enum HistoryStore {
    /// Entries kept without Pro (favorites are never removed).
    static let freeLimit = 50
    /// Upper bound with Pro, to keep the list fast.
    static let proLimit = 10_000

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: HistoryItem.self)
        } catch {
            // A broken store must not keep the app from launching.
            print("History store failed to load: \(error.localizedDescription)")
            return try! ModelContainer(for: HistoryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }

    /// Saves a value and trims the oldest non-favorites beyond the limit.
    @MainActor
    static func add(_ value: String, kind: String, isPro: Bool, context: ModelContext) {
        context.insert(HistoryItem(value: value, kind: kind))
        trim(isPro: isPro, context: context)
    }

    @MainActor
    static func trim(isPro: Bool, context: ModelContext) {
        let limit = isPro ? proLimit : freeLimit
        // Fetch offsets ignore unsaved inserts, so the newest entry would be trimmed otherwise.
        try? context.save()
        var descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { !$0.isFavorite },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchOffset = limit
        guard let overflow = try? context.fetch(descriptor) else { return }
        overflow.forEach(context.delete)
    }
}
