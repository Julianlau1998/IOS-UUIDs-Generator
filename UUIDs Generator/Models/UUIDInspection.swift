//
//  UUIDInspection.swift
//  UUIDs Generator
//

import Foundation

extension String {
    /// The identifier with line breaks allowed only after hyphens. Word joiners keep
    /// the hex blocks together, so automatic hyphenation (e.g. German) never splits them.
    /// A zero-width space after each hyphen is needed too: Unicode forbids a break
    /// between a hyphen and a digit ("-7D14"). For display only; copy the original string.
    var lineBreakingAtHyphens: String {
        var result = ""
        for (index, character) in enumerated() {
            if result.last == "-" {
                result.append("\u{200B}")
            } else if index > 0, character != "-" {
                result.append("\u{2060}")
            }
            result.append(character)
        }
        return result
    }
}

/// How UUIDs are written out: case, hyphens, braces and URN prefix.
struct UUIDStyle: Equatable, Sendable {
    var isUppercase = false
    var hasHyphens = true
    var hasBraces = false
    var hasURNPrefix = false

    func format(_ uuid: UUID) -> String {
        var text = isUppercase ? uuid.uuidString : uuid.uuidString.lowercased()
        if !hasHyphens {
            text = text.replacingOccurrences(of: "-", with: "")
        }
        if hasBraces {
            text = "{\(text)}"
        }
        if hasURNPrefix {
            text = "urn:uuid:" + text
        }
        return text
    }
}

/// Everything that can be read from a UUID: validity, version, variant, embedded time.
struct UUIDInspection: Equatable {
    enum Variant: Equatable {
        case ncs, rfc, microsoft, future

        var title: LocalizedStringResource {
            switch self {
            case .ncs: "NCS (reserved)"
            case .rfc: "RFC 9562 / RFC 4122"
            case .microsoft: "Microsoft (reserved)"
            case .future: "Future (reserved)"
            }
        }
    }

    let uuid: UUID

    private var bytes: [UInt8] { uuid.bytes }

    var version: Int { Int(bytes[6] >> 4) }

    var isNil: Bool { uuid == UUIDFactory.nilUUID }
    var isMax: Bool { uuid == UUIDFactory.maxUUID }

    var variant: Variant {
        let byte = bytes[8]
        if byte & 0x80 == 0 { return .ncs }
        if byte & 0xC0 == 0x80 { return .rfc }
        if byte & 0xE0 == 0xC0 { return .microsoft }
        return .future
    }

    var versionDescription: LocalizedStringResource {
        if isNil { return "Nil UUID" }
        if isMax { return "Max UUID" }
        switch version {
        case 1: return "Version 1 · Timestamp-based"
        case 2: return "Version 2 · DCE Security"
        case 3: return "Version 3 · Name-based (MD5)"
        case 4: return "Version 4 · Random"
        case 5: return "Version 5 · Name-based (SHA-1)"
        case 6: return "Version 6 · Reordered time"
        case 7: return "Version 7 · Unix time-ordered"
        case 8: return "Version 8 · Custom"
        default: return "Unknown version"
        }
    }

    /// Creation time embedded in v1, v6 and v7 UUIDs.
    var date: Date? {
        guard variant == .rfc else { return nil }
        let b = bytes.map(UInt64.init)
        switch version {
        case 1:
            let timeLow = b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3]
            let timeMid = b[4] << 8 | b[5]
            let timeHigh = (b[6] & 0x0F) << 8 | b[7]
            return gregorianDate(timeHigh << 48 | timeMid << 32 | timeLow)
        case 6:
            let high = b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3]
            let mid = b[4] << 8 | b[5]
            let low = (b[6] & 0x0F) << 8 | b[7]
            return gregorianDate(high << 28 | mid << 12 | low)
        case 7:
            let milliseconds = b[0..<6].reduce(0) { $0 << 8 | $1 }
            return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        default:
            return nil
        }
    }

    private func gregorianDate(_ timestamp: UInt64) -> Date? {
        guard timestamp >= UUIDFactory.gregorianOffset else { return nil }
        return Date(timeIntervalSince1970: Double(timestamp - UUIDFactory.gregorianOffset) / 10_000_000)
    }

    /// The same UUID in common notations.
    var representations: [(title: LocalizedStringResource, value: String)] {
        let lower = uuid.uuidString.lowercased()
        let data = Data(bytes)
        let base64URL = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return [
            ("Standard", lower),
            ("Uppercase", uuid.uuidString),
            ("Without Hyphens", lower.replacingOccurrences(of: "-", with: "")),
            ("Braces (Microsoft)", "{\(uuid.uuidString)}"),
            ("URN", "urn:uuid:\(lower)"),
            ("Base64", data.base64EncodedString()),
            ("Base64 URL", base64URL),
            ("Integer", String(UInt128(bigEndianBytes: bytes))),
            ("Byte Array", bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", "))
        ]
    }

    /// Accepts the common notations: with or without hyphens, braces, URN prefix or quotes.
    static func parse(_ text: String) -> UUID? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'")))
            .lowercased()
        if value.hasPrefix("urn:uuid:") {
            value.removeFirst("urn:uuid:".count)
        }
        if value.hasPrefix("{"), value.hasSuffix("}") {
            value = String(value.dropFirst().dropLast())
        }
        let hex = value.replacingOccurrences(of: "-", with: "")
        guard hex.count == 32, hex.allSatisfy(\.isHexDigit) else { return nil }
        // Hyphens, if present, must sit at the standard positions.
        if value.contains("-") {
            let parts = value.split(separator: "-", omittingEmptySubsequences: false).map(\.count)
            guard parts == [8, 4, 4, 4, 12] else { return nil }
        }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return UUID(bytes: bytes)
    }
}
