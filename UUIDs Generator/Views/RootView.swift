//
//  RootView.swift
//  UUIDs Generator
//

import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(StoreManager.self) private var store
    @Environment(AdsManager.self) private var ads
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Start", systemImage: "house", value: .generator) {
                GeneratorView()
            }
            Tab("Bulk", systemImage: "square.stack.3d.up", value: .bulk) {
                BulkView()
            }
            Tab("History", systemImage: "clock", value: .history) {
                HistoryView()
            }
            Tab("Tools", systemImage: "wrench.and.screwdriver", value: .tools) {
                ToolsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $router.isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $router.isShowingPaywall) {
            PaywallView(feature: router.paywallFeature)
        }
        .sheet(isPresented: $router.isShowingWelcome) {
            WelcomeView {
                UserDefaults.standard.set(WelcomeView.currentVersion, forKey: WelcomeView.storageKey)
                router.isShowingWelcome = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                ads.refreshNativeAdsIfNeeded(isPro: store.isPro)
                ads.appDidBecomeActive(
                    isPro: store.isPro,
                    isBlocked: router.isShowingWelcome || router.isShowingPaywall || router.isKeyboardVisible
                )
            case .background:
                ads.appDidEnterBackground()
            default:
                break
            }
        }
        .onChange(of: router.selectedTab) {
            ads.registerTabSwitch(isPro: store.isPro)
        }
        .task {
            await store.refreshEntitlements()
        }
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "debugPaywallPlans") {
                router.isShowingWelcome = false
                router.showPaywall()
            }
        }
        #endif
        .task(id: router.isShowingWelcome) {
            // Ask for ad consent only after the welcome screen is gone,
            // so the first thing people see is the app, not a dialog.
            guard !router.isShowingWelcome else { return }
            #if DEBUG
            // Review-screenshot runs must not be covered by consent dialogs.
            guard !UserDefaults.standard.bool(forKey: "debugPaywallPlans") else { return }
            #endif
            try? await Task.sleep(for: .milliseconds(600))
            await ads.start(isPro: store.isPro)
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillShowNotification) {
                router.isKeyboardVisible = true
            }
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: UIResponder.keyboardWillHideNotification) {
                router.isKeyboardVisible = false
            }
        }
    }
}
