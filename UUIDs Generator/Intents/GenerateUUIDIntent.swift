//
//  GenerateUUIDIntent.swift
//  UUIDs Generator
//

import AppIntents
import UIKit

extension UUIDVersion: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "UUID Version"

    static let caseDisplayRepresentations: [UUIDVersion: DisplayRepresentation] = [
        .v4: DisplayRepresentation(title: "Version 4", subtitle: "Random"),
        .v7: DisplayRepresentation(title: "Version 7", subtitle: "Time-ordered"),
        .v1: DisplayRepresentation(title: "Version 1", subtitle: "Timestamp-based")
    ]
}

/// Creates a UUID for Siri, Spotlight and Shortcuts without opening the app.
struct GenerateUUIDIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate UUID"
    static let description = IntentDescription("Creates a new UUID and optionally copies it to the clipboard.")
    /// Pro runs in the background; free users continue in the app, where the usual ads apply.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Version", default: .v4)
    var version: UUIDVersion

    @Parameter(title: "Uppercase", default: false)
    var isUppercase: Bool

    @Parameter(title: "Copy to Clipboard", default: true)
    var copiesToClipboard: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$version) UUID") {
            \.$isUppercase
            \.$copiesToClipboard
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let uuid = UUIDFactory.make(version)
        let value = UUIDStyle(isUppercase: isUppercase).format(uuid)

        if !Self.isPro {
            guard systemContext.currentMode.canContinueInForeground else {
                throw needsToContinueInForegroundError("Open UUID Generator to create a UUID.", alwaysConfirm: false)
            }
            try await continueInForeground(alwaysConfirm: false)
            let version = version
            await MainActor.run {
                let router = AppRouter.shared
                router.selectedTab = .generator
                router.intentResult = AppRouter.IntentResult(uuid: uuid, version: version)
            }
        }

        if copiesToClipboard {
            await MainActor.run { UIPasteboard.general.string = value }
        }
        return .result(value: value, dialog: "\(value)")
    }

    /// Cached subscription state (StoreManager keeps it up to date).
    private static var isPro: Bool {
        let defaults = UserDefaults.standard
        #if DEBUG
        if defaults.bool(forKey: "debug.simulatePro") { return true }
        #endif
        return defaults.bool(forKey: "isPro")
    }
}

struct UUIDShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateUUIDIntent(),
            phrases: [
                "Generate a UUID with \(.applicationName)",
                "New UUID in \(.applicationName)",
                "Create a \(\.$version) UUID with \(.applicationName)"
            ],
            shortTitle: "Generate UUID",
            systemImageName: "sparkles"
        )
    }
}
