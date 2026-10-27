//
//  AuthNFCConstants.swift
//  RAZN NFC
//
//  Shared NTAG21x commands and ACCESS bits from NXP NTAG213/215/216 datasheet.
//  Variant-specific page addresses live in AuthNFCTagProfile.
//

import Foundation

enum AuthNFCConstants {
    // MARK: - Commands

    static let cmdGetVersion: UInt8 = 0x60
    static let cmdRead: UInt8 = 0x30
    static let cmdFastRead: UInt8 = 0x3A
    static let cmdWrite: UInt8 = 0xA2
    static let cmdPwdAuth: UInt8 = 0x1B

    // MARK: - Shared memory defaults

    /// First user-memory page on NTAG213/215/216.
    static let userMemoryStartPage: UInt8 = 0x04

    /// AUTH0 value that disables password protection.
    static let auth0Disabled: UInt8 = 0xFF

    // MARK: - GET_VERSION (datasheet Table 28)

    /// NXP vendor ID.
    static let nxpVendorID: UInt8 = 0x04
    /// Product type byte for NTAG.
    static let ntagProductType: UInt8 = 0x04
    /// Storage-size byte for NTAG213 (144-byte user memory class).
    static let ntag213StorageSize: UInt8 = 0x0F
    /// Storage-size byte for NTAG215 (504-byte user memory class).
    static let ntag215StorageSize: UInt8 = 0x11
    /// Storage-size byte for NTAG216 (888-byte user memory class).
    static let ntag216StorageSize: UInt8 = 0x13

    // MARK: - ACCESS byte (CFG1 byte 0)

    static let accessBitPROT: UInt8 = 0x80
    static let accessBitCFGLCK: UInt8 = 0x40
    static let accessBitAuthLimMask: UInt8 = 0x07

    // MARK: - Demo content

    /// Big-endian length prefix before UTF-8 payload (not NDEF).
    static let contentLengthPrefixByteCount = 2

    // MARK: - Password input

    static let passwordHexLength = 8

    /// Fixed password for Tag Manager (tester mode). Display-only; not user-editable.
    static let tagManagerPasswordHex = "AADDCCBB"
}
