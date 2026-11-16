//
//  ExportMenu.swift
//  UUIDs Generator
//

import SwiftUI

/// What happens with the exported file.
enum ExportAction {
    /// Opens the share sheet (AirDrop, Mail, …).
    case share
    /// Opens the system dialog to save the file in Files or iCloud Drive.
    case save
}

/// Menu that writes values to PDF, text, CSV or JSON and then shares or saves the file.
/// CSV and JSON require Pro (or a one-time unlock with a rewarded ad).
struct ExportMenu<MenuLabel: View>: View {
    let action: ExportAction
    let title: String
    let values: () -> [String]
    @ViewBuilder let label: () -> MenuLabel

    @Environment(StoreManager.self) private var store
    @Environment(AdsManager.self) private var ads
    @Environment(AppRouter.self) private var router

    @State private var exportFile: ExportFile?
    @State private var document: ExportDocument?
    @State private var isExporting = false

    var body: some View {
        Menu {
            ForEach(ExportFormat.allCases) { format in
                let isLocked = format.requiresPro && !store.canUse(.dataExport)
                Button {
                    export(format)
                } label: {
                    Label {
                        Text(format.title)
                        if isLocked {
                            Text("Pro")
                        }
                    } icon: {
                        Image(systemName: isLocked ? "lock.fill" : format.systemImage)
                    }
                }
            }
        } label: {
            if isExporting {
                ProgressView()
            } else {
                label()
            }
        }
        .disabled(isExporting)
        .sheet(item: $exportFile, onDismiss: {
            // A finished export is a natural break.
            ads.registerCompletedAction(isPro: store.isPro)
        }) { file in
            ActivityView(items: [file.url])
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .fileExporter(
            isPresented: Binding(get: { document != nil }, set: { if !$0 { document = nil } }),
            document: document,
            contentType: document?.contentType ?? .plainText,
            defaultFilename: title
        ) { result in
            if case .success = result {
                ads.registerCompletedAction(isPro: store.isPro)
            }
        }
    }

    private func export(_ format: ExportFormat) {
        if format.requiresPro {
            guard store.canUse(.dataExport) else {
                router.showPaywall(for: .dataExport)
                return
            }
            store.consume(.dataExport)
        }
        let values = values()
        let title = title
        let action = action
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                switch action {
                case .share:
                    let url = try await Task.detached(priority: .userInitiated) {
                        try Exporter.write(values, format: format, title: title)
                    }.value
                    exportFile = ExportFile(url: url)
                case .save:
                    let data = try await Task.detached(priority: .userInitiated) {
                        try Exporter.data(values, format: format, title: title)
                    }.value
                    document = ExportDocument(data: data, contentType: format.contentType)
                }
            } catch {
                print("Export failed: \(error.localizedDescription)")
            }
        }
    }
}

extension ExportMenu where MenuLabel == Label<Text, Image> {
    /// Toolbar-style menu with the standard share or save label.
    init(_ action: ExportAction, title: String, values: @escaping () -> [String]) {
        self.init(action: action, title: title, values: values) {
            action == .share
                ? Label("Share", systemImage: "square.and.arrow.up")
                : Label("Save to Files", systemImage: "folder")
        }
    }
}
