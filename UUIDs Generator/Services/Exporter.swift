//
//  Exporter.swift
//  UUIDs Generator
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// File formats for exporting a batch of identifiers.
enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf, txt, csv, json

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .pdf: "PDF Document"
        case .txt: "Plain Text"
        case .csv: "CSV Spreadsheet"
        case .json: "JSON Array"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc.richtext"
        case .txt: "doc.plaintext"
        case .csv: "tablecells"
        case .json: "curlybraces"
        }
    }

    var contentType: UTType {
        switch self {
        case .pdf: .pdf
        case .txt: .plainText
        case .csv: .commaSeparatedText
        case .json: .json
        }
    }

    /// CSV and JSON are part of Pro; PDF and text were free in the previous app.
    var requiresPro: Bool {
        switch self {
        case .pdf, .txt: false
        case .csv, .json: true
        }
    }
}

/// Already rendered file contents for the "Save to Files" dialog.
struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf, .plainText, .commaSeparatedText, .json]

    let data: Data
    let contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        // Export only; the app never opens these files.
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// A file ready to be handed to the share sheet.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

enum Exporter {
    /// Writes the values to a temporary file named like "100 UUIDs.pdf" (for the share sheet).
    nonisolated static func write(_ values: [String], format: ExportFormat, title: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(title).\(format.rawValue)")
        try data(values, format: format, title: title).write(to: url, options: .atomic)
        return url
    }

    /// The file contents in the given format.
    nonisolated static func data(_ values: [String], format: ExportFormat, title: String) throws -> Data {
        switch format {
        case .txt:
            return Data(values.joined(separator: "\n").utf8)
        case .csv:
            let rows = values.enumerated().map { "\($0.offset + 1),\($0.element)" }
            return Data((["index,id"] + rows).joined(separator: "\n").utf8)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            return try encoder.encode(values)
        case .pdf:
            return pdfData(values, title: title)
        }
    }

    /// A4 pages with a header and numbered, monospaced rows.
    nonisolated private static func pdfData(_ values: [String], title: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 48
        let lineHeight: CGFloat = 17
        let headerHeight: CGFloat = 56
        let rowsPerPage = Int((pageRect.height - 2 * margin - headerHeight) / lineHeight)
        let pageCount = max(1, Int((Double(values.count) / Double(rowsPerPage)).rounded(.up)))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        let indexAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let created = Date.now.formatted(date: .abbreviated, time: .shortened)
        let indexWidth = CGFloat(String(values.count).count) * 7 + 12

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for page in 0..<pageCount {
                context.beginPage()
                (title as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: titleAttributes)
                let meta = "\(created) · \(page + 1)/\(pageCount)"
                (meta as NSString).draw(at: CGPoint(x: margin, y: margin + 26), withAttributes: metaAttributes)

                let start = page * rowsPerPage
                let end = min(values.count, start + rowsPerPage)
                for index in start..<end {
                    let y = margin + headerHeight + CGFloat(index - start) * lineHeight
                    ("\(index + 1)" as NSString).draw(at: CGPoint(x: margin, y: y + 1), withAttributes: indexAttributes)
                    (values[index] as NSString).draw(at: CGPoint(x: margin + indexWidth, y: y), withAttributes: valueAttributes)
                }
            }
        }
    }
}
