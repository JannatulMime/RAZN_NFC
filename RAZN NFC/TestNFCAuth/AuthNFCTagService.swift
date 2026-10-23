//
//  AuthNFCTagService.swift
//  RAZN NFC
//

import CoreNFC
import Foundation

/// Command surface shared by `NFCMiFareTag` and unit-test doubles.
protocol AuthNFCTagCommanding: AnyObject {
    var mifareFamily: NFCMiFareFamily { get }
    func sendAuthNFCCommand(_ packet: Data) async throws -> Data
}

extension NFCMiFareTag {
    func sendAuthNFCCommand(_ packet: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            sendMiFareCommand(commandPacket: packet) { response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: response)
                }
            }
        }
    }
}

/// Wraps a Core NFC tag. `NFCMiFareTag` cannot be declared as conforming to a Swift protocol.
final class AuthNFCMiFareCommandBox: AuthNFCTagCommanding {
    let tag: NFCMiFareTag

    init(tag: NFCMiFareTag) {
        self.tag = tag
    }

    var mifareFamily: NFCMiFareFamily { tag.mifareFamily }

    func sendAuthNFCCommand(_ packet: Data) async throws -> Data {
        try await tag.sendAuthNFCCommand(packet)
    }
}

/// Low-level NTAG21x page operations via MiFare transceive.
/// Independent of the app’s existing `NFCReader` NDEF read implementation.
enum AuthNFCTagService {

    static func sendCommand(_ tag: any AuthNFCTagCommanding, _ packet: Data) async throws -> Data {
        do {
            return try await tag.sendAuthNFCCommand(packet)
        } catch let error as AuthNFCError {
            throw error
        } catch {
            throw mapTransceiveError(error)
        }
    }

    static func getVersion(_ tag: any AuthNFCTagCommanding) async throws -> AuthNFCVersionInfo {
        let response: Data
        do {
            response = try await sendCommand(tag, Data([AuthNFCConstants.cmdGetVersion]))
        } catch let error as AuthNFCError {
            throw AuthNFCError.versionIdentificationFailed(details: error.explanation)
        } catch {
            throw AuthNFCError.versionIdentificationFailed(details: error.localizedDescription)
        }
        return try AuthNFCVersionInfo.parse(response)
    }

    /// Identifies a supported NTAG213/215/216 via GET_VERSION. Does not guess from UID or family alone.
    static func identifySupportedTag(_ tag: any AuthNFCTagCommanding) async throws -> (version: AuthNFCVersionInfo, profile: AuthNFCTagProfile) {
        if tag.mifareFamily != .ultralight && tag.mifareFamily != .unknown {
            throw AuthNFCError.unsupportedTagType(
                details: "MiFare family is \(String(describing: tag.mifareFamily)), expected Ultralight/NTAG."
            )
        }

        let version = try await getVersion(tag)
        guard let profile = version.resolvedProfile else {
            throw AuthNFCError.unsupportedTagType(
                details: String(
                    format: "GET_VERSION vendor=0x%02X type=0x%02X storage=0x%02X (need NXP NTAG with storage 0x0F/0x11/0x13).",
                    version.vendorID,
                    version.productType,
                    version.storageSize
                )
            )
        }
        return (version, profile)
    }

    /// READ returns 16 bytes (4 pages) starting at `page`.
    static func readPages(_ tag: any AuthNFCTagCommanding, startingAt page: UInt8) async throws -> Data {
        let response = try await sendCommand(tag, Data([AuthNFCConstants.cmdRead, page]))
        guard response.count >= 16 else {
            throw AuthNFCError.unexpectedResponse(details: "READ returned \(response.count) bytes")
        }
        return response.prefix(16)
    }

    static func readPage(_ tag: any AuthNFCTagCommanding, page: UInt8) async throws -> Data {
        let block = try await readPages(tag, startingAt: page)
        return Data(block.prefix(4))
    }

    /// WRITE one 4-byte page. ACK is typically a single 0x0A byte on success.
    static func writePage(
        _ tag: any AuthNFCTagCommanding,
        page: UInt8,
        data: [UInt8],
        treatingNAKAsProtectionFailure: Bool = false
    ) async throws {
        guard data.count == 4 else {
            throw AuthNFCError.writeFailure(details: "Page data must be 4 bytes.")
        }
        var packet = Data([AuthNFCConstants.cmdWrite, page])
        packet.append(contentsOf: data)
        let response: Data
        do {
            response = try await sendCommand(tag, packet)
        } catch let error as AuthNFCError {
            if treatingNAKAsProtectionFailure, case .unexpectedResponse = error {
                throw AuthNFCError.writeProtectionOrLock
            }
            throw error
        }
        // Accept empty or ACK (0x0A). Some stacks return empty on success.
        if response.count == 1, response[0] != 0x0A {
            if treatingNAKAsProtectionFailure {
                throw AuthNFCError.writeProtectionOrLock
            }
            throw AuthNFCError.writeFailure(
                details: String(format: "WRITE NAK 0x%02X on page 0x%02X", response[0], page)
            )
        }
    }

    static func writePages(
        _ tag: any AuthNFCTagCommanding,
        startPage: UInt8,
        data: Data,
        profile: AuthNFCTagProfile,
        mapNAKToProtectionError: Bool
    ) async throws {
        let pageCount = AuthNFCPasswordService.pagesNeeded(forEncodedData: data)
        let lastPage = Int(startPage) + pageCount - 1
        guard lastPage <= Int(profile.userMemoryEndPage) else {
            throw AuthNFCError.pageOutOfRange(
                details: String(
                    format: "Write would reach page 0x%02X; %@ user memory ends at 0x%02X.",
                    lastPage,
                    profile.displayName,
                    profile.userMemoryEndPage
                )
            )
        }

        var offset = 0
        for i in 0..<pageCount {
            var pageBytes = [UInt8](repeating: 0, count: 4)
            for b in 0..<4 {
                if offset < data.count {
                    pageBytes[b] = data[offset]
                    offset += 1
                }
            }
            let page = startPage &+ UInt8(i)
            guard profile.containsUserPage(page) else {
                throw AuthNFCError.pageOutOfRange(
                    details: String(format: "Page 0x%02X is outside %@ user memory.", page, profile.displayName)
                )
            }
            do {
                // Unauthenticated NAKs are treated as protection/lock refusals (fail closed).
                try await writePage(
                    tag,
                    page: page,
                    data: pageBytes,
                    treatingNAKAsProtectionFailure: mapNAKToProtectionError
                )
            } catch let error as AuthNFCError where error == .writeProtectionOrLock {
                throw error
            } catch {
                throw AuthNFCError.partialWriteFailure(
                    details: "Failed at page 0x\(String(page, radix: 16)) after \(i) page(s). \(error.localizedDescription)"
                )
            }
        }
    }

    static func readContentBytes(_ tag: any AuthNFCTagCommanding, startPage: UInt8, pageCount: Int) async throws -> Data {
        var result = Data()
        var page = startPage
        var remaining = pageCount
        while remaining > 0 {
            let chunk = try await readPages(tag, startingAt: page)
            let pagesInChunk = min(4, remaining)
            result.append(chunk.prefix(pagesInChunk * 4))
            page = page &+ UInt8(pagesInChunk)
            remaining -= pagesInChunk
        }
        return result
    }

    static func readConfigSnapshot(_ tag: any AuthNFCTagCommanding, profile: AuthNFCTagProfile) async throws -> AuthNFCConfigSnapshot {
        // READ at CFG0 returns CFG0, CFG1, PWD, PACK (16 bytes) on NTAG21x.
        let block = try await readPages(tag, startingAt: profile.cfg0Page)
        let cfg0 = Data(block.prefix(4))
        let cfg1 = Data(block.dropFirst(4).prefix(4))
        return try AuthNFCConfigSnapshot.parse(cfg0: cfg0, cfg1: cfg1)
    }

    static func authenticate(
        _ tag: any AuthNFCTagCommanding,
        password: [UInt8],
        expectedPACK: [UInt8]
    ) async throws {
        guard password.count == 4, expectedPACK.count == 2 else {
            throw AuthNFCError.invalidPasswordFormat
        }
        var packet = Data([AuthNFCConstants.cmdPwdAuth])
        packet.append(contentsOf: password)
        let response: Data
        do {
            response = try await sendCommand(tag, packet)
        } catch AuthNFCError.unexpectedResponse {
            // A NAK on PWD_AUTH is an authentication rejection. Connection and
            // session failures stay themselves so callers can avoid calling them "Wrong Tag".
            throw AuthNFCError.authenticationRejected
        } catch {
            throw error
        }
        guard response.count >= 2 else {
            throw AuthNFCError.unexpectedResponse(details: "PWD_AUTH returned \(response.count) bytes")
        }
        let pack = [UInt8](response.prefix(2))
        guard pack == expectedPACK else {
            throw AuthNFCError.packMismatch
        }
    }

    // NFCMiFareTag forwards. Production tests call the `AuthNFCTagCommanding` overloads.

    static func identifySupportedTag(_ tag: NFCMiFareTag) async throws -> (version: AuthNFCVersionInfo, profile: AuthNFCTagProfile) {
        try await identifySupportedTag(AuthNFCMiFareCommandBox(tag: tag))
    }

    static func readConfigSnapshot(_ tag: NFCMiFareTag, profile: AuthNFCTagProfile) async throws -> AuthNFCConfigSnapshot {
        try await readConfigSnapshot(AuthNFCMiFareCommandBox(tag: tag), profile: profile)
    }

    static func authenticate(
        _ tag: NFCMiFareTag,
        password: [UInt8],
        expectedPACK: [UInt8]
    ) async throws {
        try await authenticate(AuthNFCMiFareCommandBox(tag: tag), password: password, expectedPACK: expectedPACK)
    }

    static func writePage(
        _ tag: NFCMiFareTag,
        page: UInt8,
        data: [UInt8],
        treatingNAKAsProtectionFailure: Bool = false
    ) async throws {
        try await writePage(
            AuthNFCMiFareCommandBox(tag: tag),
            page: page,
            data: data,
            treatingNAKAsProtectionFailure: treatingNAKAsProtectionFailure
        )
    }

    static func writePages(
        _ tag: NFCMiFareTag,
        startPage: UInt8,
        data: Data,
        profile: AuthNFCTagProfile,
        mapNAKToProtectionError: Bool
    ) async throws {
        try await writePages(
            AuthNFCMiFareCommandBox(tag: tag),
            startPage: startPage,
            data: data,
            profile: profile,
            mapNAKToProtectionError: mapNAKToProtectionError
        )
    }

    static func readContentBytes(_ tag: NFCMiFareTag, startPage: UInt8, pageCount: Int) async throws -> Data {
        try await readContentBytes(AuthNFCMiFareCommandBox(tag: tag), startPage: startPage, pageCount: pageCount)
    }

    private static func mapTransceiveError(_ error: Error) -> AuthNFCError {
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerTransceiveErrorTagConnectionLost:
                return .tagRemoved
            case .readerTransceiveErrorTagResponseError:
                return .unexpectedResponse(details: readerError.localizedDescription)
            default:
                return AuthNFCError.fromNFCReaderError(error)
            }
        }
        return .connectionFailed(details: error.localizedDescription)
    }
}
