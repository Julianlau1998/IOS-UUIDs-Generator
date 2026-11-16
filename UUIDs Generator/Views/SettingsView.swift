//
//  SettingsView.swift
//  UUIDs Generator
//

import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @State private var isShowingPaywall = false
    @State private var paywallFeature: ProFeature?
    @State private var isManagingSubscription = false
    @State private var isRedeemingCode = false

    static let appStoreURL = URL(string: "https://apps.apple.com/app/id1603050260")!
    private let privacyURL = URL(string: "https://uuids.netlify.app/data-security")!
    private let supportURL = URL(string: "mailto:jlauapps@gmail.com?subject=UUID%20Generator")!

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                proSection

                Section {
                    Toggle(isOn: $settings.copiesAutomatically) {
                        SettingsLabel("Copy Automatically", systemImage: "doc.on.clipboard.fill", color: .blue)
                    }
                    Toggle(isOn: $settings.savesHistory) {
                        SettingsLabel("Save to History", systemImage: "clock.fill", color: .purple)
                    }
                    Button {
                        settings.resetFormat()
                    } label: {
                        SettingsLabel("Reset Format", systemImage: "arrow.counterclockwise", color: .gray)
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Generator")
                } footer: {
                    Text("“Copy Automatically” puts every new UUID on the clipboard. The history keeps every ID you copy or share.")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        LabeledContent {
                            Image(systemName: "arrow.up.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        } label: {
                            SettingsLabel("Language", systemImage: "globe", color: .teal)
                        }
                    }
                    .foregroundStyle(.primary)
                } footer: {
                    Text("The app follows your device language. You can choose a different language for this app in the Settings app.")
                }

                if ads.isPrivacyOptionsRequired {
                    Section("Privacy") {
                        Button {
                            Task { await ads.presentPrivacyOptions() }
                        } label: {
                            SettingsLabel("Ad Privacy Settings", systemImage: "hand.raised.fill", color: .indigo)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                #if DEBUG
                debugSection
                #endif

                Section("About") {
                    Button {
                        requestReview()
                    } label: {
                        SettingsLabel("Rate the App", systemImage: "star.fill", color: .yellow)
                    }
                    .foregroundStyle(.primary)
                    ShareLink(item: Self.appStoreURL, message: Text("Create UUIDs in a second with UUID Generator:")) {
                        SettingsLabel("Recommend the App", systemImage: "heart.fill", color: .pink)
                    }
                    .foregroundStyle(.primary)
                    Button {
                        openURL(supportURL)
                    } label: {
                        SettingsLabel("Contact Support", systemImage: "envelope.fill", color: .blue)
                    }
                    .foregroundStyle(.primary)
                    Button {
                        openURL(privacyURL)
                    } label: {
                        SettingsLabel("Privacy Policy", systemImage: "lock.shield.fill", color: .green)
                    }
                    .foregroundStyle(.primary)
                    LabeledContent {
                        Text(appVersion)
                    } label: {
                        SettingsLabel("Version", systemImage: "info", color: .gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(feature: paywallFeature)
            }
            .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
            .offerCodeRedemption(isPresented: $isRedeemingCode) { _ in
                Task { await store.refreshEntitlements() }
            }
            .onChange(of: router.isShowingPaywall) { _, isShowing in
                // Locked rows request the paywall via the router; the root can't
                // present it while this sheet is up, so present it from here.
                if isShowing {
                    paywallFeature = router.paywallFeature
                    router.isShowingPaywall = false
                    isShowingPaywall = true
                }
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack(spacing: 14) {
                    AppIconView()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro Active")
                            .font(.headline)
                        Text("Thank you for your support!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Button {
                    isManagingSubscription = true
                } label: {
                    SettingsLabel("Manage Subscription", systemImage: "creditcard.fill", color: .blue)
                }
                .foregroundStyle(.primary)
            } else {
                Button {
                    paywallFeature = nil
                    isShowingPaywall = true
                } label: {
                    HStack(spacing: 14) {
                        AppIconView()
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("UUID Generator")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                ProBadge()
                            }
                            Text("No ads, 100,000 at once, CSV & JSON, more ID types")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    isRedeemingCode = true
                } label: {
                    SettingsLabel("Redeem Code", systemImage: "giftcard.fill", color: .pink)
                }
                .foregroundStyle(.primary)
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    SettingsLabel("Restore Purchases", systemImage: "arrow.clockwise", color: .gray)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        @Bindable var store = store
        return Section {
            Toggle(isOn: $store.isSimulatingPro) {
                SettingsLabel("Simulate Pro", systemImage: "hammer.fill", color: .gray)
            }
            Button {
                UserDefaults.standard.removeObject(forKey: WelcomeView.storageKey)
            } label: {
                SettingsLabel("Show Welcome on Next Launch", systemImage: "hand.wave.fill", color: .gray)
            }
            .foregroundStyle(.primary)
        } header: {
            Text(verbatim: "Debug")
        } footer: {
            Text(verbatim: "Only visible in debug builds.")
        }
    }
    #endif
}
