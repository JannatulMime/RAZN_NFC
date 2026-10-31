//
//  AuthNFCCredentialDerivation.swift
//  RAZN NFC
//
//  Offline NTAG213/NTAG215 PWD / PACK derivation (same protocol for both).
//
//  Protocol (v1) — domain separator strings are historical ("NTAG215") and must
//  stay unchanged so existing provisioned cards remain valid:
//    uid   = 7 raw UID bytes from tag memory (page0[0..2] || page1[0..3])
//    pwd   = HMAC-SHA256(key, UTF8("RAZN-NTAG215-PWD-v1") || uid)[0..<4]
//    pack  = HMAC-SHA256(key, UTF8("RAZN-NTAG215-PACK-v1") || uid)[0..<2]
//
//  Do not feed hex/colon display strings into HMAC. Byte order is the physical
//  NTAG UID order (UID0…UID6). See docs/NTAG215_UID_PASSWORD_DERIVATION.md.
//

import CryptoKit
import Foundation

struct AuthNFCDerivedCredentials: Equatable {
    let uid: [UInt8]
    let password: [UInt8]
    let pack: [UInt8]

    var uidHex: String {
        AuthNFCCredentialDerivation.hexString(uid, separator: "")
    }

    var uidDisplayHex: String {
        AuthNFCCredentialDerivation.hexString(uid, separator: ":")
    }

    var passwordHex: String {
        AuthNFCCredentialDerivation.hexString(password, separator: "")
    }

    var packHex: String {
        AuthNFCCredentialDerivation.hexString(pack, separator: "")
    }
}

enum AuthNFCCredentialDerivation {
    static let expectedUIDByteCount = 7
    static let passwordDomainSeparator = "RAZN-NTAG215-PWD-v1"
    static let packDomainSeparator = "RAZN-NTAG215-PACK-v1"

    /// Validates and returns a 7-byte NTAG UID.
    static func validatedUID(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count == expectedUIDByteCount else {
            throw AuthNFCError.invalidUID(
                details: "Expected \(expectedUIDByteCount) UID bytes, got \(bytes.count)."
            )
        }
        return bytes
    }

    /// Parses UID from an NTAG READ starting at page 0 (16-byte response).
    static func uidBytes(fromPage0Read block: Data) throws -> [UInt8] {
        guard block.count >= 8 else {
            throw AuthNFCError.invalidUID(details: "UID pages too short (\(block.count) bytes).")
        }
        // Page 0: UID0 UID1 UID2 BCC0 | Page 1: UID3 UID4 UID5 UID6
        let uid: [UInt8] = [
            block[0], block[1], block[2],
            block[4], block[5], block[6], block[7]
        ]
        return try validatedUID(uid)
    }

    static func deriveCredentials(
        uid: [UInt8],
        masterKey: [UInt8]
    ) throws -> AuthNFCDerivedCredentials {
        let uidBytes = try validatedUID(uid)
        guard masterKey.count >= AuthNFCMasterKeyProvider.minimumKeyByteCount else {
            throw AuthNFCError.invalidMasterKey
        }

        let key = SymmetricKey(data: Data(masterKey))
        let passwordDigest = hmacSHA256(key: key, domain: passwordDomainSeparator, uid: uidBytes)
        let packDigest = hmacSHA256(key: key, domain: packDomainSeparator, uid: uidBytes)

        return AuthNFCDerivedCredentials(
            uid: uidBytes,
            password: Array(passwordDigest.prefix(4)),
            pack: Array(packDigest.prefix(2))
        )
    }

    static func deriveCredentials(
        uid: [UInt8],
        masterKeyProvider: AuthNFCMasterKeyProviding = AuthNFCMasterKeyProvider.shared
    ) throws -> AuthNFCDerivedCredentials {
        try deriveCredentials(uid: uid, masterKey: masterKeyProvider.masterKeyBytes())
    }

    private static func hmacSHA256(
        key: SymmetricKey,
        domain: String,
        uid: [UInt8]
    ) -> Data {
        var message = Data(domain.utf8)
        message.append(contentsOf: uid)
        let code = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return Data(code)
    }

    static func hexString(_ bytes: [UInt8], separator: String) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: separator)
    }
}
