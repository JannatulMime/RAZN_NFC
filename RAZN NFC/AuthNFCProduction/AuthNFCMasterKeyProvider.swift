//
//  AuthNFCMasterKeyProvider.swift
//  RAZN NFC
//
//  Loads the offline NTAG215 HMAC master key from build configuration.
//  The real production key must be supplied via Config/Secrets.xcconfig
//  (gitignored) → Info.plist RAZN_NFC_MASTER_KEY_HEX. Never log or show
//  this key outside the tester-only Test Auth screen.
//

import Foundation

protocol AuthNFCMasterKeyProviding {
    /// Raw master-key bytes used for HMAC derivation.
    func masterKeyBytes() throws -> [UInt8]

    /// Uppercase hex of the master key for tester-only display.
    func masterKeyHexForDisplay() throws -> String
}

enum AuthNFCMasterKeyProvider {
    /// Process-wide provider. Tests may replace this.
    static var shared: AuthNFCMasterKeyProviding = BundleAuthNFCMasterKeyProvider()

    /// Documented test-only 32-byte key. Never use as a production secret.
    static let testOnlyMasterKeyHex =
        "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"

    static let infoPlistKey = "RAZN_NFC_MASTER_KEY_HEX"
    static let minimumKeyByteCount = 32
}

struct BundleAuthNFCMasterKeyProvider: AuthNFCMasterKeyProviding {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func masterKeyBytes() throws -> [UInt8] {
        let hex = try resolvedMasterKeyHex()
        return try Self.parseMasterKeyHex(hex)
    }

    func masterKeyHexForDisplay() throws -> String {
        try resolvedMasterKeyHex().uppercased()
    }

    private func resolvedMasterKeyHex() throws -> String {
        let raw = (bundle.object(forInfoDictionaryKey: AuthNFCMasterKeyProvider.infoPlistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !raw.isEmpty {
            return raw
        }

        #if DEBUG
        return AuthNFCMasterKeyProvider.testOnlyMasterKeyHex
        #else
        throw AuthNFCError.missingMasterKey
        #endif
    }

    static func parseMasterKeyHex(_ hex: String) throws -> [UInt8] {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AuthNFCMasterKeyProvider.minimumKeyByteCount * 2,
              trimmed.count % 2 == 0,
              trimmed.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil else {
            throw AuthNFCError.invalidMasterKey
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(trimmed.count / 2)
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let next = trimmed.index(index, offsetBy: 2)
            let pair = String(trimmed[index..<next])
            guard let byte = UInt8(pair, radix: 16) else {
                throw AuthNFCError.invalidMasterKey
            }
            bytes.append(byte)
            index = next
        }
        guard bytes.count >= AuthNFCMasterKeyProvider.minimumKeyByteCount else {
            throw AuthNFCError.invalidMasterKey
        }
        return bytes
    }
}

/// Fixed key for unit tests.
struct FixedAuthNFCMasterKeyProvider: AuthNFCMasterKeyProviding {
    let hex: String

    func masterKeyBytes() throws -> [UInt8] {
        try BundleAuthNFCMasterKeyProvider.parseMasterKeyHex(hex)
    }

    func masterKeyHexForDisplay() throws -> String {
        hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
