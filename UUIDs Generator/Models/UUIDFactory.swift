//
//  UUIDFactory.swift
//  UUIDs Generator
//

import CryptoKit
import Foundation
import Synchronization

/// UUID versions offered in the generator and bulk screens.
enum UUIDVersion: String, CaseIterable, Identifiable, Codable, Sendable {
    case v4, v7, v1

    var id: Self { self }

    var number: Int {
        switch self {
        case .v1: 1
        case .v4: 4
        case .v7: 7
        }
    }

    var title: LocalizedStringResource { "Version \(number)" }

    var subtitle: LocalizedStringResource {
        switch self {
        case .v4: "Random"
        case .v7: "Time-ordered"
        case .v1: "Timestamp-based"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .v4: "122 random bits. The most common choice for IDs that reveal nothing."
        case .v7: "Starts with a millisecond timestamp, so IDs sort by creation time. Ideal for database keys."
        case .v1: "Based on a timestamp and a node. The node is random, so no device information is included."
        }
    }

    /// Label stored in the history, e.g. "v4".
    var historyKind: String { "v\(number)" }
}

/// Name-based UUID versions (RFC 9562).
enum NameBasedVersion: String, CaseIterable, Identifiable, Sendable {
    case v5, v3

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .v5: "Version 5 (SHA-1)"
        case .v3: "Version 3 (MD5)"
        }
    }

    var historyKind: String { rawValue }
}

/// Predefined namespaces from RFC 9562 for name-based UUIDs.
enum UUIDNamespace: String, CaseIterable, Identifiable, Sendable {
    case dns, url, oid, x500, custom

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .dns: "DNS"
        case .url: "URL"
        case .oid: "OID"
        case .x500: "X.500"
        case .custom: "Custom"
        }
    }

    var uuid: UUID? {
        switch self {
        case .dns: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")
        case .url: UUID(uuidString: "6ba7b811-9dad-11d1-80b4-00c04fd430c8")
        case .oid: UUID(uuidString: "6ba7b812-9dad-11d1-80b4-00c04fd430c8")
        case .x500: UUID(uuidString: "6ba7b814-9dad-11d1-80b4-00c04fd430c8")
        case .custom: nil
        }
    }
}

/// Creates UUIDs and other unique identifiers.
enum UUIDFactory {
    /// Last v1 timestamp, so UUIDs created within the same 100 ns tick stay unique.
    private static let lastV1Timestamp = Mutex<UInt64>(0)

    /// 100-ns intervals between the Gregorian reform (1582-10-15) and 1970-01-01.
    static let gregorianOffset: UInt64 = 0x01B2_1DD2_1381_4000

    static let nilUUID = UUID(bytes: [UInt8](repeating: 0, count: 16))
    static let maxUUID = UUID(bytes: [UInt8](repeating: 0xFF, count: 16))

    static func make(_ version: UUIDVersion) -> UUID {
        switch version {
        case .v4: UUID()
        case .v7: v7()
        case .v1: v1()
        }
    }

    static func make(_ version: UUIDVersion, count: Int) -> [UUID] {
        (0..<count).map { _ in make(version) }
    }

    /// Unix epoch milliseconds followed by random bits (RFC 9562, section 5.7).
    static func v7(date: Date = .now) -> UUID {
        var bytes = randomBytes(16)
        let milliseconds = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        for index in 0..<6 {
            bytes[index] = UInt8(truncatingIfNeeded: milliseconds >> (8 * (5 - index)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x70
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(bytes: bytes)
    }

    /// Gregorian timestamp with a random clock sequence and a random multicast node,
    /// so no hardware address is ever exposed (RFC 9562, section 6.10).
    static func v1(date: Date = .now) -> UUID {
        let now = UInt64(max(0, date.timeIntervalSince1970 * 10_000_000)) + gregorianOffset
        let timestamp = lastV1Timestamp.withLock { last in
            last = max(now, last + 1)
            return last
        }

        var bytes = randomBytes(16)
        let timeLow = UInt32(truncatingIfNeeded: timestamp)
        let timeMid = UInt16(truncatingIfNeeded: timestamp >> 32)
        let timeHigh = (UInt16(truncatingIfNeeded: timestamp >> 48) & 0x0FFF) | 0x1000

        bytes[0] = UInt8(truncatingIfNeeded: timeLow >> 24)
        bytes[1] = UInt8(truncatingIfNeeded: timeLow >> 16)
        bytes[2] = UInt8(truncatingIfNeeded: timeLow >> 8)
        bytes[3] = UInt8(truncatingIfNeeded: timeLow)
        bytes[4] = UInt8(truncatingIfNeeded: timeMid >> 8)
        bytes[5] = UInt8(truncatingIfNeeded: timeMid)
        bytes[6] = UInt8(truncatingIfNeeded: timeHigh >> 8)
        bytes[7] = UInt8(truncatingIfNeeded: timeHigh)
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        // The multicast bit marks the node as random instead of a MAC address.
        bytes[10] |= 0x01
        return UUID(bytes: bytes)
    }

    /// Deterministic UUID from a namespace and a name (v3: MD5, v5: SHA-1).
    static func nameBased(_ version: NameBasedVersion, namespace: UUID, name: String) -> UUID {
        var data = Data(namespace.bytes)
        data.append(Data(name.utf8))

        var bytes: [UInt8]
        switch version {
        case .v3:
            bytes = Array(Insecure.MD5.hash(data: data))
            bytes[6] = (bytes[6] & 0x0F) | 0x30
        case .v5:
            bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
            bytes[6] = (bytes[6] & 0x0F) | 0x50
        }
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(bytes: bytes)
    }

    // MARK: Other identifiers

    private static let crockfordAlphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    /// 26-character, lexicographically sortable identifier (48-bit time + 80 random bits).
    static func ulid(date: Date = .now) -> String {
        var bytes = randomBytes(16)
        let milliseconds = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        for index in 0..<6 {
            bytes[index] = UInt8(truncatingIfNeeded: milliseconds >> (8 * (5 - index)))
        }
        let value = UInt128(bigEndianBytes: bytes)
        // 26 × 5 bits = 130 bits; the two leading bits are always zero.
        return String((0..<26).map { index in
            let shift = 125 - 5 * index
            return crockfordAlphabet[Int(truncatingIfNeeded: (value >> shift) & 0x1F)]
        })
    }

    /// Random ID from the given alphabet, sampled uniformly.
    static func nanoID(length: Int = 21, alphabet: NanoIDAlphabet = .urlSafe) -> String {
        let characters = Array(alphabet.characters)
        var generator = SystemRandomNumberGenerator()
        return String((0..<max(1, length)).map { _ in
            characters[Int.random(in: 0..<characters.count, using: &generator)]
        })
    }

    static func randomBytes(_ count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
    }
}

/// Character sets for NanoIDs.
enum NanoIDAlphabet: String, CaseIterable, Identifiable, Sendable {
    case urlSafe, alphanumeric, lowercase, hex, numbers

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .urlSafe: "URL-Safe"
        case .alphanumeric: "Alphanumeric"
        case .lowercase: "Lowercase & Numbers"
        case .hex: "Hexadecimal"
        case .numbers: "Numbers Only"
        }
    }

    var characters: String {
        switch self {
        case .urlSafe: "useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict"
        case .alphanumeric: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        case .lowercase: "0123456789abcdefghijklmnopqrstuvwxyz"
        case .hex: "0123456789abcdef"
        case .numbers: "0123456789"
        }
    }
}

// MARK: - Byte helpers

extension UUID {
    init(bytes b: [UInt8]) {
        precondition(b.count == 16, "A UUID has exactly 16 bytes.")
        self.init(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                         b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    var bytes: [UInt8] {
        withUnsafeBytes(of: uuid) { Array($0) }
    }
}

extension UInt128 {
    /// Big-endian interpretation of up to 16 bytes.
    init(bigEndianBytes bytes: [UInt8]) {
        self = bytes.reduce(0) { ($0 << 8) | UInt128($1) }
    }
}
