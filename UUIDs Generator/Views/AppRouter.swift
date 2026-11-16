//
//  AppRouter.swift
//  UUIDs Generator
//

import Observation
import SwiftUI

enum AppTab: Hashable {
    case generator, bulk, history, tools
}

/// App-wide navigation state: selected tab and presented sheets.
@Observable
@MainActor
final class AppRouter {
    /// Shared so App Intents can hand results to the running app.
    static let shared = AppRouter()

    var selectedTab: AppTab = .generator
    var isShowingSettings = false
    var isShowingPaywall = false
    /// The locked feature that opened the paywall; it can be unlocked once with an ad.
    var paywallFeature: ProFeature?
    var isShowingWelcome = WelcomeView.needsPresentation
    var isKeyboardVisible = false
    /// A value handed to the inspector, e.g. from the history.
    var inspectorInput: String?
    /// A UUID created by the "Generate UUID" intent for free users; the Start tab shows it
    /// and counts it like a tap on "New UUID" (ads included).
    var intentResult: IntentResult?

    struct IntentResult: Equatable {
        let uuid: UUID
        let version: UUIDVersion
    }

    func showPaywall(for feature: ProFeature? = nil) {
        paywallFeature = feature
        isShowingPaywall = true
    }

    func inspect(_ value: String) {
        inspectorInput = value
        selectedTab = .tools
    }
}

/// Toolbar button that opens the settings sheet.
struct SettingsToolbarItem: ToolbarContent {
    @Environment(AppRouter.self) private var router

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape") {
                router.isShowingSettings = true
            }
        }
    }
}
