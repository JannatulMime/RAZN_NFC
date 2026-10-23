//
//  AuthNFCProductionWriteGate.swift
//  RAZN NFC
//
//  Authentication gate + Type 2 NDEF page writer for the production write path.
//  A production write is sent only after the tag is confirmed to be an NTAG213 or
//  NTAG215 whose destination pages are password-protected, and PWD_AUTH with the
//  stored password succeeds. Unprotected tags and failed authentication do not write.
//
//  After MiFare commands (GET_VERSION / PWD_AUTH), Core NFC's queryNDEFStatus/writeNDEF
//  often fails with NFCError 104 ("Stack Error"). Writing the same NDEF payload via
//  page WRITE avoids that conflict while preserving URI/Text record encoding.
//

import CoreNFC
import Foundation

struct AuthNFCProductionWritePrep: Equatable {
    var authenticated: Bool
    var profile: AuthNFCTagProfile
}

enum AuthNFCProductionWriteGate {

    /// Identifies the tag, requires password protection on the destination pages, then authenticates.
    /// Does not write payload or configuration pages.
    static func prepareAuthenticatedWrite(
        tag: any AuthNFCTagCommanding,
        ndefMessage: NFCNDEFMessage,
        passwordStore: AuthNFCPasswordStore
    ) async throws -> AuthNFCProductionWritePrep {
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        guard profile.variant == .ntag213 || profile.variant == .ntag215 else {
            throw AuthNFCError.unsupportedTagType(
                details: "Production writes accept NTAG213 and NTAG215 only."
            )
        }

        let tlv = try type2UserMemory(for: ndefMessage, profile: profile)
        let pageCount = max(1, (tlv.count + 3) / 4)
        let snapshot = try await readProductionConfig(tag, profile: profile)

        // CFG0 AUTH0 and CFG1 ACCESS come from the variant's own pages.
        // Protection has to cover the whole user-memory span that will be written.
        guard AuthNFCProtection.productionDestinationIsFullyProtected(
            startPage: profile.userMemoryStartPage,
            pageCount: pageCount,
            auth0: snapshot.auth0,
            access: snapshot.access,
            profile: profile
        ) else {
            throw AuthNFCError.unprotectedTag
        }

        try await authenticateWithStoredPassword(tag: tag, passwordStore: passwordStore)
        return AuthNFCProductionWritePrep(authenticated: true, profile: profile)
    }

    /// Production entry point for a live Core NFC tag.
    static func writeProtectedNDEF(
        tag: NFCMiFareTag,
        message: NFCNDEFMessage,
        passwordStore: AuthNFCPasswordStore
    ) async throws {
        try await writeProtectedNDEF(
            tag: AuthNFCMiFareCommandBox(tag: tag),
            message: message,
            passwordStore: passwordStore
        )
    }

    /// Production entry point. Writes only after `prepareAuthenticatedWrite` succeeds.
    static func writeProtectedNDEF(
        tag: any AuthNFCTagCommanding,
        message: NFCNDEFMessage,
        passwordStore: AuthNFCPasswordStore
    ) async throws {
        let prep = try await prepareAuthenticatedWrite(
            tag: tag,
            ndefMessage: message,
            passwordStore: passwordStore
        )
        guard prep.authenticated else {
            throw AuthNFCError.authenticationRequired
        }
        try await writeNDEFViaPages(
            tag: tag,
            message: message,
            profile: prep.profile,
            authenticated: true
        )
    }

    /// Writes the production NDEF message into Type 2 user memory (page 4+).
    /// Refuses to send WRITE unless authentication has already succeeded.
    static func writeNDEFViaPages(
        tag: any AuthNFCTagCommanding,
        message: NFCNDEFMessage,
        profile: AuthNFCTagProfile,
        authenticated: Bool
    ) async throws {
        guard authenticated else {
            throw AuthNFCError.authenticationRequired
        }
        let tlv = try type2UserMemory(for: message, profile: profile)
        try await ensureCapabilityContainer(tag, profile: profile)
        try await AuthNFCTagService.writePages(
            tag,
            startPage: profile.userMemoryStartPage,
            data: tlv,
            profile: profile,
            mapNAKToProtectionError: !authenticated
        )
    }

    // MARK: - Type 2 / NDEF encoding (same records as NFCNDEFMessage / writeNDEF)

    /// NDEF TLV + terminator, padded to full pages, sized for the tag profile.
    static func type2UserMemory(for message: NFCNDEFMessage, profile: AuthNFCTagProfile) throws -> Data {
        let ndef = serializeNDEFMessage(message)
        var tlv = Data()
        if ndef.count < 0xFF {
            tlv.append(0x03)
            tlv.append(UInt8(ndef.count))
        } else {
            tlv.append(0x03)
            tlv.append(0xFF)
            tlv.append(UInt8((ndef.count >> 8) & 0xFF))
            tlv.append(UInt8(ndef.count & 0xFF))
        }
        tlv.append(ndef)
        tlv.append(0xFE)
        while tlv.count % 4 != 0 {
            tlv.append(0x00)
        }

        guard tlv.count <= profile.userMemoryByteCount else {
            throw AuthNFCError.contentTooLarge(maxUTF8Bytes: profile.userMemoryByteCount)
        }
        return tlv
    }

    /// Binary NDEF message from Core NFC records (URI / Text well-known, etc.).
    static func serializeNDEFMessage(_ message: NFCNDEFMessage) -> Data {
        let records = message.records
        var data = Data()
        for (index, record) in records.enumerated() {
            let mb = index == 0
            let me = index == records.count - 1
            let sr = record.payload.count < 256
            let il = !record.identifier.isEmpty
            let tnf = record.typeNameFormat.rawValue & 0x07

            var header: UInt8 = tnf
            if mb { header |= 0x80 }
            if me { header |= 0x40 }
            if sr { header |= 0x10 }
            if il { header |= 0x08 }

            data.append(header)
            data.append(UInt8(record.type.count))
            if sr {
                data.append(UInt8(record.payload.count))
            } else {
                let length = UInt32(record.payload.count)
                data.append(UInt8((length >> 24) & 0xFF))
                data.append(UInt8((length >> 16) & 0xFF))
                data.append(UInt8((length >> 8) & 0xFF))
                data.append(UInt8(length & 0xFF))
            }
            if il {
                data.append(UInt8(record.identifier.count))
            }
            data.append(record.type)
            if il {
                data.append(record.identifier)
            }
            data.append(record.payload)
        }
        return data
    }

    /// Conservative page span helper for tests / callers that only have a message length.
    static func estimatedNDEFPageCount(for message: NFCNDEFMessage) -> Int {
        let ndefBytes = message.length
        let tlvOverhead = 6
        let total = max(1, ndefBytes + tlvOverhead)
        return max(1, (total + 3) / 4)
    }

    // MARK: - Private

    private static func readProductionConfig(
        _ tag: any AuthNFCTagCommanding,
        profile: AuthNFCTagProfile
    ) async throws -> AuthNFCConfigSnapshot {
        do {
            return try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch let error as AuthNFCError {
            switch error {
            case .tagRemoved, .connectionFailed, .sessionTimeoutOrInvalidation, .userCancelled, .nfcUnavailable:
                throw error
            default:
                // A failed CFG read is not AUTH0=0xFF and must not fall through to a write.
                throw AuthNFCError.configurationUnreadable
            }
        } catch {
            throw AuthNFCError.configurationUnreadable
        }
    }

    private static func ensureCapabilityContainer(
        _ tag: any AuthNFCTagCommanding,
        profile: AuthNFCTagProfile
    ) async throws {
        // Page 3 holds the Capability Container. Leave a valid CC untouched.
        let page = try await AuthNFCTagService.readPage(tag, page: 0x03)
        if page.count >= 4, page[0] == 0xE1 {
            return
        }
        let cc = defaultCapabilityContainer(for: profile)
        try await AuthNFCTagService.writePage(tag, page: 0x03, data: cc)
    }

    private static func defaultCapabilityContainer(for profile: AuthNFCTagProfile) -> [UInt8] {
        // Datasheet CC: E1 10 <size/8> 00
        let sizeByte: UInt8
        switch profile.variant {
        case .ntag213: sizeByte = 0x12
        case .ntag215: sizeByte = 0x3F
        case .ntag216: sizeByte = 0x6D
        }
        return [0xE1, 0x10, sizeByte, 0x00]
    }

    private static func authenticateWithStoredPassword(
        tag: any AuthNFCTagCommanding,
        passwordStore: AuthNFCPasswordStore
    ) async throws {
        let hex: String
        switch passwordStore.lookup() {
        case .missing:
            throw AuthNFCError.noStoredPassword
        case .invalid:
            throw AuthNFCError.invalidPasswordFormat
        case .valid(let stored):
            hex = stored
        }
        let password = try AuthNFCPasswordService.passwordBytes(fromHex: hex)
        let pack = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: password)
        do {
            try await AuthNFCTagService.authenticate(tag, password: password, expectedPACK: pack)
        } catch AuthNFCError.packMismatch {
            throw AuthNFCError.packMismatch
        } catch AuthNFCError.authenticationRejected {
            throw AuthNFCError.authenticationRejected
        } catch AuthNFCError.unexpectedResponse {
            throw AuthNFCError.authenticationRejected
        } catch {
            throw error
        }
    }
}

// MARK: - Production write dialogs

struct AuthNFCProductionWriteAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func == (lhs: AuthNFCProductionWriteAlert, rhs: AuthNFCProductionWriteAlert) -> Bool {
        lhs.title == rhs.title && lhs.message == rhs.message
    }

    /// `nil` when the user already dismissed the system NFC sheet.
    static func presented(for error: Error) -> AuthNFCProductionWriteAlert? {
        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled {
            return nil
        }
        guard let authError = error as? AuthNFCError else {
            return AuthNFCProductionWriteAlert(
                title: "NFC Communication Failed",
                message: "The tag could not be read reliably. Keep it near the iPhone and try again. Nothing was written."
            )
        }
        if case .userCancelled = authError {
            return nil
        }
        return AuthNFCProductionWriteAlert(title: title(for: authError), message: message(for: authError))
    }

    private static func title(for error: AuthNFCError) -> String {
        switch error {
        case .unprotectedTag:
            return "Unprotected Tag"
        case .authenticationRejected, .packMismatch:
            return "Wrong Tag"
        case .unsupportedTagType, .versionIdentificationFailed:
            return "Unsupported Tag"
        case .configurationUnreadable:
            return "Configuration Unreadable"
        case .noStoredPassword:
            return "No NFC Password Stored"
        case .invalidPasswordFormat:
            return "Invalid Password"
        case .tagRemoved, .connectionFailed, .sessionTimeoutOrInvalidation, .nfcUnavailable:
            return "NFC Communication Failed"
        default:
            return error.title
        }
    }

    private static func message(for error: AuthNFCError) -> String {
        switch error {
        case .unprotectedTag:
            return "This tag does not have password protection enabled. Writing is not allowed."
        case .authenticationRejected, .packMismatch:
            return "Authentication failed. This tag does not match the password configured in this app. Writing is not allowed."
        case .unsupportedTagType, .versionIdentificationFailed:
            return "This tag is not a supported NTAG213 or NTAG215. Writing is not allowed."
        case .configurationUnreadable:
            return "The tag password-protection settings could not be read reliably. Writing is not allowed."
        case .noStoredPassword:
            return "No NFC password is stored on this iPhone. Save an 8-character hexadecimal password before writing. Writing is not allowed."
        case .invalidPasswordFormat:
            return "The stored NFC password must be exactly eight hexadecimal characters. Writing is not allowed."
        case .tagRemoved, .connectionFailed, .sessionTimeoutOrInvalidation:
            return "The tag could not be read reliably. Keep it near the iPhone and try again. Nothing was written."
        case .nfcUnavailable:
            return "NFC is not available on this device. Writing is not allowed."
        default:
            return error.explanation
        }
    }
}
