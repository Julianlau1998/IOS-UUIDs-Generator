//
//  WelcomeView.swift
//  UUIDs Generator
//

import SwiftUI

/// "Welcome / What's New" sheet shown on first launch and after major updates.
struct WelcomeView: View {
    /// Increase to show the sheet again after an update with notable changes.
    static let currentVersion = 1
    static let storageKey = "welcome.lastSeenVersion"

    static var needsPresentation: Bool {
        #if DEBUG
        if ScreenshotDemo.isActive { return false }
        #endif
        return UserDefaults.standard.integer(forKey: storageKey) < currentVersion
    }

    let onContinue: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 18) {
                        AppIconView(size: 96)
                            .scaleEffect(isAnimating ? 1 : 0.6)
                            .opacity(isAnimating ? 1 : 0)

                        VStack(spacing: 8) {
                            Text("Welcome to UUID Generator")
                                .font(.largeTitle.bold())
                            Text("Completely rebuilt for iPhone and iPad.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 12)
                    }
                    .padding(.top, 48)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            WelcomeFeatureRow(feature: feature)
                                .opacity(isAnimating ? 1 : 0)
                                .offset(y: isAnimating ? 0 : 16)
                                .animation(.smooth(duration: 0.6).delay(0.15 + Double(index) * 0.08), value: isAnimating)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .frame(maxWidth: 560)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.3)) { isAnimating = true }
        }
        .interactiveDismissDisabled()
    }

    private var features: [WelcomeFeature] {
        [
            WelcomeFeature(
                title: "One Tap, One UUID",
                message: "Versions 4, 7 and 1 in any format — tap the card to copy.",
                systemImage: "sparkles", color: .indigo
            ),
            WelcomeFeature(
                title: "Thousands at Once",
                message: "Generate in bulk and export as PDF, text, CSV or JSON.",
                systemImage: "square.stack.3d.up.fill", color: .blue
            ),
            WelcomeFeature(
                title: "History & Favorites",
                message: "Every ID you copy is saved, searchable and can get a note.",
                systemImage: "clock.fill", color: .purple
            ),
            WelcomeFeature(
                title: "Developer Tools",
                message: "Validate and decode UUIDs, create name-based UUIDs, ULIDs and NanoIDs.",
                systemImage: "wrench.and.screwdriver.fill", color: .teal
            ),
            WelcomeFeature(
                title: "Shortcuts & Siri",
                message: "Ask Siri for a new UUID or use it in your own shortcuts.",
                systemImage: "square.2.layers.3d.fill", color: .pink
            )
        ]
    }
}

private struct WelcomeFeature {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let color: Color
}

private struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 36

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: feature.systemImage)
                .font(.system(size: iconSize * 0.8, weight: .medium))
                .foregroundStyle(feature.color.gradient)
                .symbolRenderingMode(.hierarchical)
                .frame(width: iconSize, height: iconSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView {}
}
