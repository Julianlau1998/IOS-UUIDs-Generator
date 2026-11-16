//
//  PaywallView.swift
//  UUIDs Generator
//

import StoreKit
import SwiftUI

/// Two-step Pro flow: benefits first, then the subscription options.
struct PaywallView: View {
    /// The locked feature that opened the paywall, offered for one use with an ad.
    var feature: ProFeature?

    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    /// Review-screenshot runs (`-debugPaywallPlans YES`) open the plans directly.
    @State private var isShowingPlans = UserDefaults.standard.bool(forKey: "debugPaywallPlans")
    #else
    @State private var isShowingPlans = false
    #endif

    var body: some View {
        NavigationStack {
            PaywallBenefitsStep(feature: feature) {
                isShowingPlans = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingPlans) {
                PaywallPlansStep {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Step 1

private struct PaywallBenefitsStep: View {
    let feature: ProFeature?
    let onContinue: () -> Void

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    AppIconView(size: 92)

                    VStack(spacing: 8) {
                        ProBadge()
                        Text("UUID Generator")
                            .font(.largeTitle.bold())
                        Text("More IDs, more formats — and no ads.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    ForEach(Array(ProBenefit.all.enumerated()), id: \.offset) { _, benefit in
                        ProBenefitCard(benefit: benefit)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(colors: [.indigo.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
        // A bar (not a plain inset) blurs the scrolling benefits behind the buttons.
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 10) {
                StepIndicator(step: 1)
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                if let feature {
                    RewardedUnlockButton(feature: feature) {
                        dismiss()
                    }
                }
                Button("Restore Purchases") {
                    Task { await store.restorePurchases() }
                }
                .font(.footnote)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(maxWidth: 560)
        }
    }
}

private struct ProBenefit {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let color: Color

    static let all: [ProBenefit] = [
        ProBenefit(title: "No Ads", subtitle: "Generate without interruptions", systemImage: "rectangle.slash", color: .blue),
        ProBenefit(title: "100,000 at Once", subtitle: "100 times larger lists, without ads", systemImage: "square.stack.3d.up.fill", color: .indigo),
        ProBenefit(title: "CSV & JSON Export", subtitle: "Straight into Excel, Numbers or your code", systemImage: "tablecells.fill", color: .green),
        ProBenefit(title: "Name-Based UUIDs", subtitle: "Deterministic versions 3 and 5", systemImage: "number", color: .purple),
        ProBenefit(title: "ULID & NanoID", subtitle: "Sortable and short ID formats", systemImage: "textformat.abc", color: .pink),
        ProBenefit(title: "Unlimited History", subtitle: "Keep every ID you copied, with notes", systemImage: "clock.fill", color: .orange)
    ]
}

private struct ProBenefitCard: View {
    let benefit: ProBenefit

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: benefit.systemImage, color: benefit.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.title)
                    .font(.headline)
                Text(benefit.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step 2

private struct PaywallPlansStep: View {
    let onPurchased: () -> Void

    @Environment(StoreManager.self) private var store

    var body: some View {
        SubscriptionStoreView(productIDs: StoreManager.productIDs) {
            VStack(spacing: 12) {
                AppIconView(size: 64)
                Text("Choose Your Plan")
                    .font(.title.bold())
                Text("Cancel anytime in the App Store settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                StepIndicator(step: 2)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .redeemCode)
        .storeButton(.visible, for: .policies)
        .storeButton(.hidden, for: .cancellation)
        .navigationBarTitleDisplayMode(.inline)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await store.refreshEntitlements()
                onPurchased()
            }
        }
    }
}

/// "● ○" style progress for the two paywall steps.
private struct StepIndicator: View {
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...2, id: \.self) { index in
                Capsule()
                    .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == step ? 20 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of 2")
    }
}
