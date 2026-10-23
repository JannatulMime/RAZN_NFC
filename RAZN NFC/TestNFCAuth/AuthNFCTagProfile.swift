//
//  AuthNFCTagProfile.swift
//  RAZN NFC
//
//  Verified NTAG213/215/216 memory maps from NXP NTAG213_215_216 product data sheet.
//

import Foundation

enum AuthNFCTagVariant: String, Equatable, CaseIterable {
    case ntag213
    case ntag215
    case ntag216

    var displayName: String {
        switch self {
        case .ntag213: return "NTAG213"
        case .ntag215: return "NTAG215"
        case .ntag216: return "NTAG216"
        }
    }
}

/// Tag-specific configuration used by the AuthNFC demo.
/// Addresses are applied only after GET_VERSION identifies the variant.
struct AuthNFCTagProfile: Equatable {
    let variant: AuthNFCTagVariant
    /// GET_VERSION storage-size byte (datasheet Table 28).
    let storageSizeByte: UInt8
    let userMemoryStartPage: UInt8
    let userMemoryEndPage: UInt8
    let dynamicLockPage: UInt8
    /// CFG0 — contains AUTH0 at byte 3.
    let cfg0Page: UInt8
    /// CFG1 — contains ACCESS at byte 0.
    let cfg1Page: UInt8
    let pwdPage: UInt8
    let packPage: UInt8

    var displayName: String { variant.displayName }

    var auth0Page: UInt8 { cfg0Page }
    var accessPage: UInt8 { cfg1Page }

    var userMemoryPageCount: Int {
        Int(userMemoryEndPage) - Int(userMemoryStartPage) + 1
    }

    var userMemoryByteCount: Int {
        userMemoryPageCount * 4
    }

    /// UTF-8 payload bytes after the demo’s 2-byte length prefix.
    var maxContentUTF8ByteCount: Int {
        max(0, userMemoryByteCount - AuthNFCConstants.contentLengthPrefixByteCount)
    }

    /// Pages available for length-prefixed demo content.
    var contentPageCount: Int {
        userMemoryPageCount
    }

    var supportsPasswordAuthentication: Bool { true }
    var supportsAuthenticatedRead: Bool { true }
    var supportsAuthenticatedWrite: Bool { true }

    /// Last page that would be written for `encoded` bytes starting at user memory.
    func lastContentPage(forEncodedByteCount byteCount: Int) -> Int {
        let pages = max(1, (byteCount + 3) / 4)
        return Int(userMemoryStartPage) + pages - 1
    }

    func canFitEncodedData(_ data: Data) -> Bool {
        lastContentPage(forEncodedByteCount: data.count) <= Int(userMemoryEndPage)
    }

    func containsUserPage(_ page: UInt8) -> Bool {
        page >= userMemoryStartPage && page <= userMemoryEndPage
    }

    // MARK: - Verified profiles (NXP datasheet)

    static let ntag213 = AuthNFCTagProfile(
        variant: .ntag213,
        storageSizeByte: AuthNFCConstants.ntag213StorageSize,
        userMemoryStartPage: 0x04,
        userMemoryEndPage: 0x27,
        dynamicLockPage: 0x28,
        cfg0Page: 0x29,
        cfg1Page: 0x2A,
        pwdPage: 0x2B,
        packPage: 0x2C
    )

    static let ntag215 = AuthNFCTagProfile(
        variant: .ntag215,
        storageSizeByte: AuthNFCConstants.ntag215StorageSize,
        userMemoryStartPage: 0x04,
        userMemoryEndPage: 0x81,
        dynamicLockPage: 0x82,
        cfg0Page: 0x83,
        cfg1Page: 0x84,
        pwdPage: 0x85,
        packPage: 0x86
    )

    static let ntag216 = AuthNFCTagProfile(
        variant: .ntag216,
        storageSizeByte: AuthNFCConstants.ntag216StorageSize,
        userMemoryStartPage: 0x04,
        userMemoryEndPage: 0xE1,
        dynamicLockPage: 0xE2,
        cfg0Page: 0xE3,
        cfg1Page: 0xE4,
        pwdPage: 0xE5,
        packPage: 0xE6
    )

    static let allSupported: [AuthNFCTagProfile] = [.ntag213, .ntag215, .ntag216]

    static func profile(forStorageSize size: UInt8) -> AuthNFCTagProfile? {
        allSupported.first { $0.storageSizeByte == size }
    }
}
