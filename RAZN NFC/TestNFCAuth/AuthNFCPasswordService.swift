//
//  AuthNFCPasswordService.swift
//  RAZN NFC
//

import CryptoKit
import Foundation

enum AuthNFCPasswordService {

    // MARK: - Hex password

    /// Parses exactly 8 hex characters into 4 bytes (left-to-right transmission order).
    static func passwordBytes(fromHex hex: String) throws -> [UInt8] {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == AuthNFCConstants.passwordHexLength else {
            throw AuthNFCError.invalidPasswordFormat
        }
        guard trimmed.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil else {
            throw AuthNFCError.invalidPasswordFormat
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(4)
        var index = trimmed.startIndex
        for _ in 0..<4 {
            let next = trimmed.index(index, offsetBy: 2)
            let pair = String(trimmed[index..<next])
            guard let byte = UInt8(pair, radix: 16) else {
                throw AuthNFCError.invalidPasswordFormat
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    static func validateMatchingPasswords(password: String, confirmation: String) throws -> [UInt8] {
        let bytes = try passwordBytes(fromHex: password)
        let confirmTrimmed = confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        let passwordTrimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard passwordTrimmed.caseInsensitiveCompare(confirmTrimmed) == .orderedSame else {
            throw AuthNFCError.passwordConfirmationMismatch
        }
        // Confirm also parses as valid hex of same length (no silent reinterpretation).
        _ = try passwordBytes(fromHex: confirmation)
        return bytes
    }

    // MARK: - PACK

    /// Demo PACK: first two bytes of SHA256(password). Not a second user secret.
    static func derivedPACK(fromPasswordBytes password: [UInt8]) -> [UInt8] {
        precondition(password.count == 4)
        let digest = SHA256.hash(data: Data(password))
        return Array(digest.prefix(2))
    }

    // MARK: - Config builders (safe bits only)

    /// Builds CFG0 page bytes preserving mirror fields; sets AUTH0.
    static func makeCFG0(preserving snapshot: AuthNFCConfigSnapshot, auth0: UInt8) -> [UInt8] {
        var page = snapshot.cfg0Raw
        while page.count < 4 { page.append(0) }
        page[3] = auth0
        return Array(page.prefix(4))
    }

    /// Builds CFG1 with write-only protection, CFGLCK cleared, AUTHLIM cleared.
    /// Preserves other RFUI / counter bits from the snapshot where possible, but forces CFGLCK=0.
    static func makeCFG1WriteProtectOnly(preserving snapshot: AuthNFCConfigSnapshot) -> [UInt8] {
        var page = snapshot.cfg1Raw
        while page.count < 4 { page.append(0) }
        var access = page[0]
        // Clear PROT (write-only), CFGLCK, AUTHLIM.
        access &= ~AuthNFCConstants.accessBitPROT
        access &= ~AuthNFCConstants.accessBitCFGLCK
        access &= ~AuthNFCConstants.accessBitAuthLimMask
        page[0] = access
        // RFUI bytes: keep existing or zero — datasheet says write RFUI as 0; zero reserved for safety.
        page[1] = 0
        page[2] = 0
        page[3] = 0
        return Array(page.prefix(4))
    }

    /// PACK page: 2-byte PACK + two RFUI zeros.
    static func makePACKPage(pack: [UInt8]) -> [UInt8] {
        precondition(pack.count == 2)
        return [pack[0], pack[1], 0x00, 0x00]
    }

    // MARK: - Content encoding (length-prefixed UTF-8, not NDEF)

    static func encodeContent(_ text: String, maxUTF8ByteCount: Int) throws -> Data {
        guard !text.isEmpty else { throw AuthNFCError.emptyContent }
        guard let utf8 = text.data(using: .utf8) else {
            throw AuthNFCError.writeFailure(details: "Content is not valid UTF-8.")
        }
        guard utf8.count <= maxUTF8ByteCount else {
            throw AuthNFCError.contentTooLarge(maxUTF8Bytes: maxUTF8ByteCount)
        }
        var data = Data()
        let length = UInt16(utf8.count)
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        data.append(utf8)
        // Pad to full pages with zeros.
        while data.count % 4 != 0 {
            data.append(0)
        }
        return data
    }

    static func encodeContent(_ text: String, for profile: AuthNFCTagProfile) throws -> Data {
        let encoded = try encodeContent(text, maxUTF8ByteCount: profile.maxContentUTF8ByteCount)
        guard profile.canFitEncodedData(encoded) else {
            throw AuthNFCError.contentTooLarge(maxUTF8Bytes: profile.maxContentUTF8ByteCount)
        }
        return encoded
    }

    static func decodeContent(_ data: Data, maxUTF8ByteCount: Int) throws -> String {
        guard data.count >= 2 else {
            throw AuthNFCError.readFailure(details: "Payload too short.")
        }
        let length = (Int(data[0]) << 8) | Int(data[1])
        if length == 0 {
            throw AuthNFCError.readFailure(details: "No content stored (length 0).")
        }
        guard length <= maxUTF8ByteCount else {
            throw AuthNFCError.readFailure(
                details: "Stored length \(length) exceeds tag capacity (\(maxUTF8ByteCount))."
            )
        }
        guard data.count >= 2 + length else {
            throw AuthNFCError.readFailure(details: "Stored length exceeds available bytes.")
        }
        let payload = data.subdata(in: 2..<(2 + length))
        guard let text = String(data: payload, encoding: .utf8) else {
            throw AuthNFCError.readFailure(details: "Stored bytes are not valid UTF-8.")
        }
        return text
    }

    static func decodeContent(_ data: Data, for profile: AuthNFCTagProfile) throws -> String {
        try decodeContent(data, maxUTF8ByteCount: profile.maxContentUTF8ByteCount)
    }

    static func pagesNeeded(forEncodedData data: Data) -> Int {
        max(1, (data.count + 3) / 4)
    }

    // MARK: - Unauthenticated content interpretation (no RF I/O)

    /// Interprets user-memory bytes without requiring a password.
    /// Prefers this demo’s length-prefixed format, then Type 2 NDEF TLVs, then a short hex preview.
    static func interpretUserMemory(_ data: Data, for profile: AuthNFCTagProfile) -> (text: String, format: AuthNFCContentFormat) {
        if let demo = try? decodeContent(data, for: profile), !demo.isEmpty {
            return (demo, .demoLengthPrefixed)
        }
        if let ndef = decodeType2NDEFTextOrURI(from: data), !ndef.isEmpty {
            return (ndef, .ndef)
        }
        if let hex = hexPreview(of: data), !hex.isEmpty {
            return (hex, .rawHex)
        }
        return ("", .empty)
    }

    /// Minimal Type 2 Tag TLV walk for NDEF Text / URI payloads in user memory.
    static func decodeType2NDEFTextOrURI(from data: Data) -> String? {
        var index = 0
        let bytes = [UInt8](data)
        while index < bytes.count {
            let type = bytes[index]
            if type == 0x00 {
                index += 1
                continue
            }
            if type == 0xFE { break }

            guard index + 1 < bytes.count else { break }
            var length = Int(bytes[index + 1])
            var valueStart = index + 2
            if length == 0xFF {
                guard index + 3 < bytes.count else { break }
                length = (Int(bytes[index + 2]) << 8) | Int(bytes[index + 3])
                valueStart = index + 4
            }
            guard valueStart + length <= bytes.count else { break }

            if type == 0x03 {
                let ndef = Data(bytes[valueStart..<(valueStart + length)])
                if let text = decodeNDEFMessagePayload(ndef) {
                    return text
                }
            }

            index = valueStart + length
        }
        return nil
    }

    private static func decodeNDEFMessagePayload(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        var offset = 0
        let bytes = [UInt8](data)
        while offset < bytes.count {
            let header = bytes[offset]
            let me = (header & 0x40) != 0
            let sr = (header & 0x10) != 0
            let il = (header & 0x08) != 0
            let tnf = header & 0x07
            offset += 1
            guard offset < bytes.count else { break }
            let typeLength = Int(bytes[offset])
            offset += 1

            let payloadLength: Int
            if sr {
                guard offset < bytes.count else { break }
                payloadLength = Int(bytes[offset])
                offset += 1
            } else {
                guard offset + 3 < bytes.count else { break }
                payloadLength = (Int(bytes[offset]) << 24)
                    | (Int(bytes[offset + 1]) << 16)
                    | (Int(bytes[offset + 2]) << 8)
                    | Int(bytes[offset + 3])
                offset += 4
            }

            var idLength = 0
            if il {
                guard offset < bytes.count else { break }
                idLength = Int(bytes[offset])
                offset += 1
            }

            guard offset + typeLength + idLength + payloadLength <= bytes.count else { break }
            let typeBytes = Array(bytes[offset..<(offset + typeLength)])
            offset += typeLength + idLength
            let payload = Data(bytes[offset..<(offset + payloadLength)])
            offset += payloadLength

            if tnf == 0x01, typeBytes == Array("T".utf8), let text = decodeWellKnownText(payload) {
                return text
            }
            if tnf == 0x01, typeBytes == Array("U".utf8), let uri = decodeWellKnownURI(payload) {
                return uri
            }

            if me { break }
        }
        return nil
    }

    private static func decodeWellKnownText(_ payload: Data) -> String? {
        guard !payload.isEmpty else { return nil }
        let status = payload[0]
        let langLen = Int(status & 0x3F)
        guard 1 + langLen <= payload.count else { return nil }
        let textData = payload.dropFirst(1 + langLen)
        return String(data: textData, encoding: .utf8)
    }

    private static func decodeWellKnownURI(_ payload: Data) -> String? {
        guard !payload.isEmpty else { return nil }
        let code = payload[0]
        let prefixes: [UInt8: String] = [
            0x00: "",
            0x01: "http://www.",
            0x02: "https://www.",
            0x03: "http://",
            0x04: "https://"
        ]
        let prefix = prefixes[code] ?? ""
        let rest = String(data: payload.dropFirst(), encoding: .utf8) ?? ""
        let value = prefix + rest
        return value.isEmpty ? nil : value
    }

    private static func hexPreview(of data: Data, maxBytes: Int = 48) -> String? {
        let trimmed = data.drop { $0 == 0 }
        guard !trimmed.isEmpty else { return nil }
        // If the buffer is all padding after a tiny head of zeros, still show from first non-zero.
        let start = data.firstIndex(where: { $0 != 0 }) ?? data.startIndex
        let slice = data[start..<min(data.endIndex, start + maxBytes)]
        guard slice.contains(where: { $0 != 0 }) else { return nil }
        let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
        let suffix = (data.endIndex - start) > maxBytes ? " …" : ""
        return "Raw (hex): \(hex)\(suffix)"
    }
}
