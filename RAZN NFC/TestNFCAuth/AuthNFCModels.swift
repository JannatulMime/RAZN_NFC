//
//  AuthNFCModels.swift
//  RAZN NFC
//

import Foundation

// MARK: - Status

enum AuthNFCStatusKind: Equatable {
    case idle
    case progress
    case success
    case warning
    case error
}

struct AuthNFCStatusMessage: Equatable {
    var kind: AuthNFCStatusKind
    var title: String
    var message: String
    var nextStep: String?
    var technicalDetails: String?

    static let idle = AuthNFCStatusMessage(kind: .idle, title: "", message: "")

    static func progress(_ title: String, message: String = "") -> AuthNFCStatusMessage {
        AuthNFCStatusMessage(kind: .progress, title: title, message: message)
    }

    static func success(_ title: String, message: String, nextStep: String? = nil) -> AuthNFCStatusMessage {
        AuthNFCStatusMessage(kind: .success, title: title, message: message, nextStep: nextStep)
    }

    static func warning(_ title: String, message: String, nextStep: String? = nil, technicalDetails: String? = nil) -> AuthNFCStatusMessage {
        AuthNFCStatusMessage(kind: .warning, title: title, message: message, nextStep: nextStep, technicalDetails: technicalDetails)
    }

    static func from(error: AuthNFCError) -> AuthNFCStatusMessage {
        AuthNFCStatusMessage(
            kind: .error,
            title: error.title,
            message: error.explanation,
            nextStep: error.suggestedNextStep,
            technicalDetails: error.technicalDetails
        )
    }
}

// MARK: - Tag configuration snapshot

struct AuthNFCConfigSnapshot: Equatable {
    var mirror: UInt8
    var mirrorPage: UInt8
    var auth0: UInt8
    var access: UInt8
    var cfg0Raw: [UInt8]
    var cfg1Raw: [UInt8]

    /// Raw AUTH0 ≠ 0xFF. Prefer `isEffectivelyProtected(on:)` for access decisions.
    var isProtectionEnabled: Bool {
        auth0 != AuthNFCConstants.auth0Disabled
    }

    var isConfigLocked: Bool {
        (access & AuthNFCConstants.accessBitCFGLCK) != 0
    }

    var isReadWriteProtection: Bool {
        (access & AuthNFCConstants.accessBitPROT) != 0
    }

    var authLim: UInt8 {
        access & AuthNFCConstants.accessBitAuthLimMask
    }

    /// Datasheet: AUTH0 above the last configuration page disables protection.
    func isEffectivelyProtected(on profile: AuthNFCTagProfile) -> Bool {
        AuthNFCProtection.isEffectivelyEnabled(auth0: auth0, profile: profile)
    }

    func writeRangeRequiresAuthentication(
        startPage: UInt8,
        pageCount: Int,
        profile: AuthNFCTagProfile
    ) -> Bool {
        AuthNFCProtection.writeRangeRequiresAuthentication(
            startPage: startPage,
            pageCount: pageCount,
            auth0: auth0,
            profile: profile
        )
    }

    func pageRequiresAuthentication(_ page: UInt8, profile: AuthNFCTagProfile) -> Bool {
        AuthNFCProtection.pageRequiresAuthentication(page: page, auth0: auth0, profile: profile)
    }

    /// Read access to `page` requires PWD_AUTH when PROT=1 and the page is in the AUTH0 region.
    func readRequiresAuthentication(forPage page: UInt8, profile: AuthNFCTagProfile) -> Bool {
        isReadWriteProtection && pageRequiresAuthentication(page, profile: profile)
    }

    static func parse(cfg0: Data, cfg1: Data) throws -> AuthNFCConfigSnapshot {
        guard cfg0.count >= 4, cfg1.count >= 4 else {
            throw AuthNFCError.unexpectedResponse(details: "CFG page length < 4")
        }
        let c0 = [UInt8](cfg0.prefix(4))
        let c1 = [UInt8](cfg1.prefix(4))
        return AuthNFCConfigSnapshot(
            mirror: c0[0],
            mirrorPage: c0[2],
            auth0: c0[3],
            access: c1[0],
            cfg0Raw: c0,
            cfg1Raw: c1
        )
    }
}

/// Pure protection-range rules from the NTAG213/215/216 datasheet (no RF I/O).
enum AuthNFCProtection {
    static func isEffectivelyEnabled(auth0: UInt8, profile: AuthNFCTagProfile) -> Bool {
        guard auth0 != AuthNFCConstants.auth0Disabled else { return false }
        // AUTH0 above the last addressable config page (PACK) disables protection.
        return auth0 <= profile.packPage
    }

    static func pageRequiresAuthentication(page: UInt8, auth0: UInt8, profile: AuthNFCTagProfile) -> Bool {
        isEffectivelyEnabled(auth0: auth0, profile: profile) && page >= auth0
    }

    /// True when any page in `[startPage, startPage + pageCount)` needs PWD_AUTH for write access.
    static func writeRangeRequiresAuthentication(
        startPage: UInt8,
        pageCount: Int,
        auth0: UInt8,
        profile: AuthNFCTagProfile
    ) -> Bool {
        guard pageCount > 0, isEffectivelyEnabled(auth0: auth0, profile: profile) else { return false }
        let first = Int(startPage)
        let last = first + pageCount - 1
        let protectedFrom = Int(auth0)
        return last >= protectedFrom
    }
}

struct AuthNFCVersionInfo: Equatable {
    var raw: Data
    var vendorID: UInt8
    var productType: UInt8
    var productSubtype: UInt8
    var majorVersion: UInt8
    var minorVersion: UInt8
    var storageSize: UInt8
    var protocolType: UInt8

    /// True when GET_VERSION matches NXP NTAG with a known 213/215/216 storage size.
    var isSupportedNTAG21x: Bool {
        resolvedProfile != nil
    }

    var isNTAG213: Bool { resolvedProfile?.variant == .ntag213 }
    var isNTAG215: Bool { resolvedProfile?.variant == .ntag215 }
    var isNTAG216: Bool { resolvedProfile?.variant == .ntag216 }

    var resolvedProfile: AuthNFCTagProfile? {
        guard vendorID == AuthNFCConstants.nxpVendorID,
              productType == AuthNFCConstants.ntagProductType else {
            return nil
        }
        return AuthNFCTagProfile.profile(forStorageSize: storageSize)
    }

    static func parse(_ data: Data) throws -> AuthNFCVersionInfo {
        // Datasheet: GET_VERSION returns 8 bytes on NTAG21x.
        guard data.count >= 8 else {
            throw AuthNFCError.versionIdentificationFailed(
                details: "GET_VERSION length \(data.count); expected 8 bytes."
            )
        }
        let bytes = [UInt8](data)
        return AuthNFCVersionInfo(
            raw: data,
            vendorID: bytes[1],
            productType: bytes[2],
            productSubtype: bytes[3],
            majorVersion: bytes[4],
            minorVersion: bytes[5],
            storageSize: bytes[6],
            protocolType: bytes[7]
        )
    }
}

// MARK: - Operation results

struct AuthNFCRegisterResult: Equatable {
    var variant: AuthNFCTagVariant
    var verifiedAuth0: UInt8
    var writeProtectionOnly: Bool
}

struct AuthNFCWriteResult: Equatable {
    var variant: AuthNFCTagVariant
    var bytesWritten: Int
    var authenticated: Bool
    var verified: Bool
}

struct AuthNFCReadResult: Equatable {
    var variant: AuthNFCTagVariant
    var text: String
    var authenticationUsed: Bool
    var protectionNote: String
    var contentFormat: AuthNFCContentFormat = .demoLengthPrefixed
}

enum AuthNFCContentFormat: String, Equatable {
    case demoLengthPrefixed
    case ndef
    case rawHex
    case empty
}

// MARK: - Help content

enum AuthNFCHelpTopic: String, Identifiable {
    case demoOverview
    case registration
    case authenticateWrite
    case reading
    case unauthenticatedRead

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demoOverview: return "Demo Workflow"
        case .registration: return "Registration Instructions"
        case .authenticateWrite: return "Authenticate & Write"
        case .reading: return "Reading Content"
        case .unauthenticatedRead: return "Read Tag (No Authentication)"
        }
    }

    var paragraphs: [String] {
        switch self {
        case .demoOverview:
            return [
                "1. Register a spare NTAG213, NTAG215, or NTAG216 with an 8-character hex password.",
                "2. On Write / Read, enter the same password, authenticate, then write content.",
                "3. Use Read Tag (No Authentication) to inspect accessible user memory without sending a password.",
                "4. With this demo’s write-only protection, a successful unauthenticated read does not prove the password.",
                "5. PACK is a 2-byte acknowledgement returned after PWD_AUTH — not the password itself.",
                "6. Passwords are never stored in UserDefaults or files by this demo.",
                "7. The tag variant is identified with GET_VERSION before any configuration pages are written."
            ]
        case .registration:
            return [
                "1. Use a genuine NTAG213, NTAG215, or NTAG216 tag.",
                "2. Keep the tag near the iPhone until the operation finishes.",
                "3. Registration may modify the tag’s configuration pages (PWD, PACK, AUTH0, ACCESS) for the detected variant only.",
                "4. Test only with a spare tag.",
                "5. Do not remove the tag during configuration.",
                "6. A tag configured with a password may reject writes that do not authenticate correctly.",
                "7. The PACK acknowledgement confirms authentication; it is not the password.",
                "8. Password format: exactly 8 hex characters → 4 bytes, sent in that order with PWD_AUTH (0x1B).",
                "9. This demo never sets CFGLCK or irreversible lock bits.",
                "10. If the tag already has protection enabled, you must confirm before reconfiguration and supply the current password.",
                "11. Unknown or unidentified tags are rejected without changing configuration pages."
            ]
        case .authenticateWrite:
            return [
                "1. For a password-protected tag, enter the same 8-character hex password used at registration.",
                "2. For an unprotected tag, the password field may be left empty — the app writes user memory without PWD_AUTH.",
                "3. Enter the text to store (UTF-8). Maximum size depends on the detected tag (NTAG213 has less user memory than NTAG215/216).",
                "4. When the destination pages require authentication, the app sends PWD_AUTH and checks PACK before any write.",
                "5. Content is never written to protected pages before successful authentication.",
                "6. Content that exceeds the tag’s user-memory capacity is rejected (not truncated).",
                "7. Success is reported only after read-back verification.",
                "8. Passwords are not logged or included in error text."
            ]
        case .reading:
            return [
                "1. Reading unprotected (or write-only-protected) memory does not prove the password is correct.",
                "2. If PROT enables read protection for the content pages, this Read Content action may authenticate when a password is supplied.",
                "3. Empty or invalid payloads are shown with a clear message.",
                "4. Malformed UTF-8 is surfaced as a read error rather than silent garbage."
            ]
        case .unauthenticatedRead:
            return [
                "1. This action reads accessible content only. It never asks for a password and never sends PWD_AUTH.",
                "2. It does not use a cached password, and it does not change, lock, format, or erase the tag.",
                "3. On typical write-only protection (PROT=0), user memory often remains readable; this read still does not prove any password.",
                "4. If user memory is read-protected (PROT=1 in the AUTH0 region), the app reports that authentication is required instead of pretending the data is available.",
                "5. Decoded demo payloads, NDEF text/URI (when present), or a short raw hex preview may be shown depending on what is stored."
            ]
        }
    }
}
