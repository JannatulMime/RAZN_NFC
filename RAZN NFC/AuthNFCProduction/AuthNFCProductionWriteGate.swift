//
//  AuthNFCProductionWriteGate.swift
//  RAZN NFC
//
//  Authentication gate + Type 2 NDEF page writer for the production write path.
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

    /// Identifies the tag, authenticates when protected pages require it, and returns the profile.
    /// Does not write payload pages.
    static func prepareAuthenticatedWrite(
        tag: NFCMiFareTag,
        ndefMessage: NFCNDEFMessage,
        passwordStore: AuthNFCPasswordStore
    ) async throws -> AuthNFCProductionWritePrep {
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        let tlv = try type2UserMemory(for: ndefMessage, profile: profile)
        let pageCount = max(1, (tlv.count + 3) / 4)
        var didAuth = false

        let snapshot: AuthNFCConfigSnapshot
        do {
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch {
            try await authenticateWithStoredPassword(
                tag: tag,
                passwordStore: passwordStore,
                treatingMissingPasswordAs: .noStoredPassword
            )
            didAuth = true
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        }

        let writeNeedsAuth = snapshot.writeRangeRequiresAuthentication(
            startPage: profile.userMemoryStartPage,
            pageCount: pageCount,
            profile: profile
        )

        if writeNeedsAuth {
            if !didAuth {
                try await authenticateWithStoredPassword(
                    tag: tag,
                    passwordStore: passwordStore,
                    treatingMissingPasswordAs: .noStoredPassword
                )
                didAuth = true
            }
        }

        if writeNeedsAuth && !didAuth {
            throw AuthNFCError.authenticationRequired
        }

        return AuthNFCProductionWritePrep(authenticated: didAuth, profile: profile)
    }

    /// Writes the production NDEF message into Type 2 user memory (page 4+), after optional auth.
    static func writeNDEFViaPages(
        tag: NFCMiFareTag,
        message: NFCNDEFMessage,
        profile: AuthNFCTagProfile,
        authenticated: Bool
    ) async throws {
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

    private static func ensureCapabilityContainer(
        _ tag: NFCMiFareTag,
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
        tag: NFCMiFareTag,
        passwordStore: AuthNFCPasswordStore,
        treatingMissingPasswordAs missing: AuthNFCError
    ) async throws {
        guard let hex = passwordStore.retrieve() else {
            throw missing
        }
        let password: [UInt8]
        do {
            password = try AuthNFCPasswordService.passwordBytes(fromHex: hex)
        } catch {
            throw AuthNFCError.invalidPasswordFormat
        }
        let pack = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: password)
        do {
            try await AuthNFCTagService.authenticate(tag, password: password, expectedPACK: pack)
        } catch AuthNFCError.packMismatch {
            throw AuthNFCError.packMismatch
        } catch AuthNFCError.authenticationRejected {
            throw AuthNFCError.authenticationRejected
        } catch {
            throw AuthNFCError.authenticationRejected
        }
    }
}
