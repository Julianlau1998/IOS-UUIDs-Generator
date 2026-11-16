//
//  StoreManager.swift
//  UUIDs Generator
//

import Foundation
import Observation
import StoreKit

/// Pro features that can also be unlocked once with a rewarded ad.
enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case dataExport, nameBased, ulid, nanoID

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .dataExport: "CSV & JSON export"
        case .nameBased: "Name-based UUIDs"
        case .ulid: "ULID"
        case .nanoID: "NanoID"
        }
    }
}

/// Tracks the "UUID Generator Pro" subscription using StoreKit 2.
@Observable
@MainActor
final class StoreManager {
    /// Product identifiers configured in App Store Connect (same subscription group).
    static let productIDs = [
        "app.jl.uuid.generator.pro.monthly",
        "app.jl.uuid.generator.pro.yearly"
    ]

    /// Largest list without Pro; each free list needs a rewarded ad.
    static let freeBulkLimit = 1_000
    static let proBulkLimit = 100_000

    /// Verified subscription state from StoreKit (cached for a fast launch).
    private(set) var hasActiveSubscription = UserDefaults.standard.bool(forKey: "isPro") {
        didSet { UserDefaults.standard.set(hasActiveSubscription, forKey: "isPro") }
    }

    #if DEBUG
    /// Debug-only switch in Settings to try Pro features without buying.
    var isSimulatingPro = UserDefaults.standard.bool(forKey: "debug.simulatePro") {
        didSet { UserDefaults.standard.set(isSimulatingPro, forKey: "debug.simulatePro") }
    }

    var isPro: Bool { hasActiveSubscription || isSimulatingPro }
    #else
    var isPro: Bool { hasActiveSubscription }
    #endif

    /// Features unlocked for a single use by watching a rewarded ad.
    /// Ads stay on; only the subscription removes them.
    private(set) var oneTimeUnlocks: Set<ProFeature> = Set(
        (UserDefaults.standard.stringArray(forKey: "oneTimeUnlocks") ?? []).compactMap(ProFeature.init(rawValue:))
    ) {
        didSet { UserDefaults.standard.set(oneTimeUnlocks.map(\.rawValue), forKey: "oneTimeUnlocks") }
    }

    /// Whether the feature may be used right now (subscription or a pending one-time unlock).
    func canUse(_ feature: ProFeature) -> Bool {
        isPro || oneTimeUnlocks.contains(feature)
    }

    func unlockOnce(_ feature: ProFeature) {
        oneTimeUnlocks.insert(feature)
    }

    /// Uses up a one-time unlock; subscribers keep the feature.
    func consume(_ feature: ProFeature) {
        guard !isPro else { return }
        oneTimeUnlocks.remove(feature)
    }

    var bulkLimit: Int { isPro ? Self.proBulkLimit : Self.freeBulkLimit }

    private var updatesTask: Task<Void, Never>?

    init() {
        // Purchases made on other devices, renewals, refunds, Ask to Buy, …
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlements()
            }
        }
    }

    /// Re-derives Pro status from the verified current entitlements.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                active = true
            }
            await transaction.finish()
        }
        hasActiveSubscription = active
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
