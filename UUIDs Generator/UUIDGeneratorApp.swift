//
//  UUIDGeneratorApp.swift
//  UUIDs Generator
//

import SwiftData
import SwiftUI

@main
struct UUIDGeneratorApp: App {
    @State private var settings = AppSettings()
    @State private var router = AppRouter.shared
    @State private var store = StoreManager()
    @State private var ads = AdsManager()
    private let container = HistoryStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
                .environment(store)
                .environment(ads)
        }
        .modelContainer(container)
    }
}
