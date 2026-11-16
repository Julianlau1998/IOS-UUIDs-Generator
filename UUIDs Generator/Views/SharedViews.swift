//
//  SharedViews.swift
//  UUIDs Generator
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// System share sheet for exported files.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Sheet with a large QR code of an identifier.
struct QRCodeSheet: View {
    let value: String

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel("QR code")
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 264, height: 264)
                .padding(18)
                .background(.white, in: .rect(cornerRadius: 24, style: .continuous))
                Text(verbatim: value)
                    .font(.callout.monospaced())
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal)

                if let image {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("QR Code", image: Image(uiImage: image))
                    ) {
                        Label("Share QR Code", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: value) {
            // Render off the main thread so the sheet appears immediately.
            let value = value
            image = await Task.detached(priority: .userInitiated) {
                QRCode.image(for: value, scale: 20)
            }.value
        }
    }
}

enum QRCode {
    /// Creating a Core Image context is expensive, so the app shares one.
    nonisolated private static let context = CIContext()

    /// Touches the shared context once in the background, so the first QR code is instant.
    static func prepare() async {
        await Task.detached(priority: .utility) {
            _ = image(for: "warm-up", scale: 1)
        }.value
    }

    nonisolated static func image(for text: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Compact label for an identifier type, e.g. "v4" or "ULID".
struct KindBadge: View {
    let kind: String

    var body: some View {
        Text(verbatim: kind)
            .font(.caption2.weight(.bold).monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.fill.tertiary, in: .capsule)
    }
}
