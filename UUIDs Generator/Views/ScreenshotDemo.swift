//
//  ScreenshotDemo.swift
//  UUIDs Generator
//

#if DEBUG
import Foundation
import SwiftData

/// App Store screenshot runs (debug builds only):
/// `-screenshotMode YES -screenshotTab start|qr|bulk|history|inspector|paywall`
/// Seeds sample history, opens the screen and skips the welcome sheet, consent and ads.
/// Combine with `-debug.simulatePro YES` (everything but the paywall) and `-generator.version v7`.
enum ScreenshotDemo {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "screenshotMode") }
    static var screen: String { UserDefaults.standard.string(forKey: "screenshotTab") ?? "start" }

    /// A time-ordered UUID that reads well in screenshots.
    static let uuid = UUID(uuidString: "019a8f3c-7b2e-7d41-9c6a-5e3f1b8d2a47")!

    @MainActor
    static func open(router: AppRouter, context: ModelContext) {
        seedHistory(context: context)
        switch screen {
        case "bulk": router.selectedTab = .bulk
        case "history": router.selectedTab = .history
        case "inspector": router.inspect(uuid.uuidString.lowercased())
        case "paywall": router.showPaywall()
        default: router.selectedTab = .generator
        }
    }

    @MainActor
    private static func seedHistory(context: ModelContext) {
        try? context.delete(model: HistoryItem.self)
        let notes = Self.notes
        let items: [(String, String, TimeInterval, Bool, String)] = [
            (uuid.uuidString.lowercased(), "v7", 60, false, ""),
            ("3f9a7c1e-0b5d-4826-a64b-c47a19ef1b06", "v4", 600, true, notes[0]),
            ("01KA8Z3M7Q2X9V4N6B1T5R8W0Y", "ULID", 3_600, false, ""),
            ("e0b84c17-5d82-4640-b1a9-3f2e61d3a8c5", "v4", 7_200, true, notes[1]),
            ("886313e1-3b8a-5372-9b90-0c9aee199e5d", "v5", 86_400, false, notes[2]),
            ("V1StGXR8_Z5jdHi6B-myT", "NanoID", 172_800, false, ""),
            ("019a8e11-24c9-7f03-8d5e-6b7a0c4f9e21", "v7", 259_200, false, ""),
            ("c232ab00-9414-11ec-b3c8-9f6bdeced846", "v1", 432_000, false, "")
        ]
        for (value, kind, age, favorite, note) in items {
            let item = HistoryItem(value: value, kind: kind, createdAt: .now.addingTimeInterval(-age))
            item.isFavorite = favorite
            item.note = note
            context.insert(item)
        }
        try? context.save()
    }

    private static var notes: [String] {
        switch Locale.preferredLanguages.first?.prefix(2) ?? "en" {
        case "de": ["Nutzertabelle", "Testdaten", "python.org (DNS)"]
        case "fr": ["Table utilisateurs", "Données de test", "python.org (DNS)"]
        case "es": ["Tabla de usuarios", "Datos de prueba", "python.org (DNS)"]
        case "ja": ["ユーザーテーブル", "テストデータ", "python.org (DNS)"]
        case "zh": ["用户表", "测试数据", "python.org (DNS)"]
        default: ["User table", "Test fixture", "python.org (DNS)"]
        }
    }
}
#endif
