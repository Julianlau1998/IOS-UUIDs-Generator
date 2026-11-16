//
//  AppSettings.swift
//  UUIDs Generator
//

import Foundation
import Observation
import UIKit

/// User preferences shared by all screens, persisted in UserDefaults.
@Observable
@MainActor
final class AppSettings {
    private let defaults = UserDefaults.standard

    var version: UUIDVersion {
        didSet { defaults.set(version.rawValue, forKey: Keys.version) }
    }

    var isUppercase: Bool {
        didSet { defaults.set(isUppercase, forKey: Keys.uppercase) }
    }

    var hasHyphens: Bool {
        didSet { defaults.set(hasHyphens, forKey: Keys.hyphens) }
    }

    var hasBraces: Bool {
        didSet { defaults.set(hasBraces, forKey: Keys.braces) }
    }

    var hasURNPrefix: Bool {
        didSet { defaults.set(hasURNPrefix, forKey: Keys.urn) }
    }

    /// Copies every newly generated UUID to the clipboard.
    var copiesAutomatically: Bool {
        didSet { defaults.set(copiesAutomatically, forKey: Keys.autoCopy) }
    }

    var savesHistory: Bool {
        didSet { defaults.set(savesHistory, forKey: Keys.history) }
    }

    var bulkCount: Int {
        didSet { defaults.set(bulkCount, forKey: Keys.bulkCount) }
    }

    var style: UUIDStyle {
        UUIDStyle(isUppercase: isUppercase, hasHyphens: hasHyphens, hasBraces: hasBraces, hasURNPrefix: hasURNPrefix)
    }

    init() {
        version = UUIDVersion(rawValue: defaults.string(forKey: Keys.version) ?? "") ?? .v4
        isUppercase = defaults.bool(forKey: Keys.uppercase)
        hasHyphens = defaults.object(forKey: Keys.hyphens) as? Bool ?? true
        hasBraces = defaults.bool(forKey: Keys.braces)
        hasURNPrefix = defaults.bool(forKey: Keys.urn)
        copiesAutomatically = defaults.bool(forKey: Keys.autoCopy)
        savesHistory = defaults.object(forKey: Keys.history) as? Bool ?? true
        // integer(forKey:) also reads launch arguments, which arrive as strings.
        bulkCount = defaults.object(forKey: Keys.bulkCount) == nil ? 10 : defaults.integer(forKey: Keys.bulkCount)
    }

    func resetFormat() {
        isUppercase = false
        hasHyphens = true
        hasBraces = false
        hasURNPrefix = false
    }

    private enum Keys {
        static let version = "generator.version"
        static let uppercase = "format.uppercase"
        static let hyphens = "format.hyphens"
        static let braces = "format.braces"
        static let urn = "format.urn"
        static let autoCopy = "generator.autoCopy"
        static let history = "history.enabled"
        static let bulkCount = "bulk.count"
    }
}

enum Clipboard {
    @MainActor
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
