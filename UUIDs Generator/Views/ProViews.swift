//
//  ProViews.swift
//  UUIDs Generator
//

import SwiftUI

/// Small capsule marking a Pro feature.
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "PRO")
            .font(.caption2.weight(.heavy))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.gradient, in: .capsule)
            .accessibilityLabel("Pro feature")
    }
}

/// A row teasing a Pro feature; tapping it opens the paywall.
struct ProLockedRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let systemImage: String
    var color: Color = .orange
    var feature: ProFeature?

    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.showPaywall(for: feature)
        } label: {
            HStack(spacing: 12) {
                IconTile(systemImage: systemImage, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                ProBadge()
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Opt-in rewarded ad that unlocks one use of the feature that opened the paywall.
/// Only offered when an ad is ready and the feature isn't available already.
struct RewardedUnlockButton: View {
    let feature: ProFeature
    var onUnlocked: () -> Void = {}

    @Environment(AdsManager.self) private var ads
    @Environment(StoreManager.self) private var store

    var body: some View {
        if ads.isRewardedAdReady, !store.canUse(feature) {
            Button {
                ads.showRewardedAd {
                    store.unlockOnce(feature)
                    onUnlocked()
                }
            } label: {
                VStack(spacing: 2) {
                    Label("Watch an Ad to Use It Once", systemImage: "play.rectangle.fill")
                        .font(.subheadline.weight(.semibold))
                    Text(feature.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
            .buttonStyle(.glass)
        }
    }
}
