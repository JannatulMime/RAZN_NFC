//
//  AuthNFCManager.swift
//  RAZN NFC
//
//  Isolated NFCTagReaderSession owner for the AuthNFC demo.
//  Does not use or modify the app’s existing NFCReader (NDEF) class.
//

import CoreNFC
import Foundation

@MainActor
final class AuthNFCManager: NSObject, ObservableObject {

    @Published private(set) var isBusy = false
    @Published var status: AuthNFCStatusMessage = .idle
    @Published private(set) var lastAuthCheck: AuthNFCAuthCheckResult?

    private var session: NFCTagReaderSession?
    private var tagContinuation: CheckedContinuation<NFCMiFareTag, Error>?
    private var didResumeTagContinuation = false

    // MARK: - Public API

    /// Scans a tag, reports protection status, and tries PWD_AUTH with expected credentials when protected.
    /// NTAG213/215 use UID-derived credentials; NTAG216 uses `passwordHex` (legacy shared password).
    func checkAuthStatus(passwordHex: String) async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            let legacyPassword = try AuthNFCPasswordService.passwordBytes(fromHex: passwordHex)
            let legacyPACK = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: legacyPassword)

            isBusy = true
            lastAuthCheck = nil
            status = .progress(
                "Ready to Scan",
                message: "Hold a supported NTAG21x near the iPhone to check password protection."
            )

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold a compatible NTAG213, NTAG215, or NTAG216 near the iPhone to check auth."
            ) { tag in
                try await self.performAuthCheck(
                    tag: tag,
                    legacyPassword: legacyPassword,
                    legacyPACK: legacyPACK
                )
            }

            lastAuthCheck = result
            status = .success(
                "Auth Check Complete",
                message: "\(result.displayName): \(result.authStatusTitle). AUTH0=0x\(String(result.auth0, radix: 16)), protection=\(result.protectionModeLabel), CFGLCK=\(result.isConfigLocked ? "1" : "0").",
                nextStep: result.isProtected
                    ? (result.passwordMatch == .matched
                        ? "This tag matches the expected credentials."
                        : "Protection is on, but expected credentials did not authenticate.")
                    : "Use Add Auth to enable password protection."
            )
        } catch let error as AuthNFCError {
            lastAuthCheck = nil
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else {
                status = .from(error: error)
            }
        } catch {
            lastAuthCheck = nil
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
    }

    /// Disables AUTH0-based protection. Tries NTAG215 derived credentials, then `passwordHex`, then fails.
    func removePasswordProtection(passwordHex: String) async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            _ = try AuthNFCPasswordService.passwordBytes(fromHex: passwordHex)

            isBusy = true
            status = .progress(
                "Ready to Scan",
                message: "Hold the tag steady. Password protection will be removed after authentication."
            )

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold the NTAG213/215/216 near the iPhone to remove password protection."
            ) { tag in
                try await self.performRemoveAuth(tag: tag, fallbackPasswordHex: passwordHex)
            }

            lastAuthCheck = AuthNFCAuthCheckResult(
                variant: result.variant,
                displayName: result.variant.displayName,
                auth0: result.verifiedAuth0,
                isProtected: false,
                isReadWriteProtection: false,
                isConfigLocked: false,
                passwordMatch: .skipped
            )

            let wroteNote = result.wroteConfiguration
                ? "AUTH0 was updated to 0xFF and verified."
                : "AUTH0 was already 0xFF; no configuration write was required."
            status = .success(
                "Auth Removed",
                message: "\(result.variant.displayName): password-based protection is disabled. \(wroteNote)",
                nextStep: "You can write to this tag without PWD_AUTH, unless other lock bits remain."
            )
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else {
                status = .from(error: error)
            }
        } catch {
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
    }

    private func performRemoveAuth(
        tag: NFCMiFareTag,
        fallbackPasswordHex: String
    ) async throws -> AuthNFCUnregisterResult {
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        var candidates: [(hex: String, pack: [UInt8]?)] = []
        if Self.usesUIDDerivedCredentials(profile.variant) {
            let uid = try await AuthNFCTagService.readUID(tag)
            let derived = try AuthNFCCredentialDerivation.deriveCredentials(uid: uid)
            candidates.append((derived.passwordHex, derived.pack))
        }
        candidates.append((fallbackPasswordHex, nil))

        var lastError: Error = AuthNFCError.authenticationRejected
        for candidate in candidates {
            do {
                return try await AuthNFCProductionUnregisterGate.disablePasswordProtection(
                    tag: tag,
                    passwordHex: candidate.hex,
                    expectedPACK: candidate.pack,
                    passwordStore: nil,
                    clearStoredPassword: false,
                    onProgress: { [weak self] title, message in
                        self?.status = .progress(title, message: message)
                    }
                )
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Provisions password protection. NTAG213/215 use UID-derived PWD/PACK; NTAG216 uses the legacy shared hex.
    func registerTagAuth(
        allowOverwrite: Bool,
        legacyPasswordHex: String = AuthNFCConstants.tagManagerPasswordHex,
        currentPasswordHex: String? = nil
    ) async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            let legacyPassword = try AuthNFCPasswordService.passwordBytes(fromHex: legacyPasswordHex)
            let legacyPACK = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: legacyPassword)

            var currentPassword: [UInt8]?
            if let currentPasswordHex, !currentPasswordHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentPassword = try AuthNFCPasswordService.passwordBytes(fromHex: currentPasswordHex)
            }

            isBusy = true
            status = .progress(
                "Ready to Scan",
                message: "Registering password protection on a supported NTAG21x. Keep the tag still."
            )

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold a compatible NTAG213, NTAG215, or NTAG216 near the iPhone to register auth."
            ) { tag in
                try await self.performRegistration(
                    tag: tag,
                    allowOverwrite: allowOverwrite,
                    legacyPassword: legacyPassword,
                    legacyPACK: legacyPACK,
                    currentPassword: currentPassword
                )
            }

            lastAuthCheck = AuthNFCAuthCheckResult(
                variant: result.variant,
                displayName: result.variant.displayName,
                auth0: result.verifiedAuth0,
                isProtected: true,
                isReadWriteProtection: !result.writeProtectionOnly,
                isConfigLocked: false,
                passwordMatch: .matched
            )

            let usesDerived = Self.usesUIDDerivedCredentials(result.variant)
            let credentialNote = usesDerived
                ? "\(result.variant.displayName) credentials were derived from the tag UID and the app master key."
                : "Legacy shared Tag Manager password was written."
            status = .success(
                "Password Registered",
                message: "\(result.variant.displayName) configured. AUTH0 is 0x\(String(result.verifiedAuth0, radix: 16)) with write-only protection. PACK was verified via PWD_AUTH. \(credentialNote) Configuration lock bits were not set.",
                nextStep: usesDerived
                    ? "Use production Write, or Test Auth to preview the derived password. Existing cards that used the old shared password must be re-provisioned with Add Auth."
                    : "Use Check Auth with the Tag Manager password."
            )
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else {
                status = .from(error: error)
            }
        } catch {
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
    }

    /// Reads UID and derives credentials for Test Auth. Does not send PWD_AUTH or write.
    func previewDerivedCredentials() async -> AuthNFCDerivedCredentials? {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return nil
        }

        do {
            isBusy = true
            status = .progress(
                "Ready to Scan",
                message: "Hold an NTAG213 or NTAG215 near the iPhone. Credentials are derived locally; the tag is not authenticated."
            )

            let credentials = try await withConnectedMiFareTag(
                alertMessage: "Hold an NTAG213 or NTAG215 near the iPhone to preview derived credentials."
            ) { tag in
                try await self.performCredentialPreview(tag: tag)
            }

            status = .success(
                "Credentials Derived",
                message: "UID \(credentials.uidDisplayHex). Password and master key are shown on this tester screen only. PWD_AUTH was not sent.",
                nextStep: "Use Add Auth on Tag Manager to write these credentials to the tag if needed."
            )
            isBusy = false
            return credentials
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else {
                status = .from(error: error)
            }
        } catch {
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
        return nil
    }

    func registerPassword(
        passwordHex: String,
        confirmationHex: String,
        allowOverwrite: Bool,
        currentPasswordHex: String?
    ) async {
        // Legacy entry point kept for callers that still pass hex; Tag Manager uses registerTagAuth.
        _ = try? AuthNFCPasswordService.validateMatchingPasswords(
            password: passwordHex,
            confirmation: confirmationHex
        )
        await registerTagAuth(
            allowOverwrite: allowOverwrite,
            legacyPasswordHex: passwordHex,
            currentPasswordHex: currentPasswordHex
        )
    }

    /// Writes demo content. Authenticates with PWD_AUTH only when the destination pages require it.
    /// For unprotected tags, performs a normal write without sending PWD_AUTH (password may be empty).
    func authenticateAndWrite(passwordHex: String, content: String) async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            let trimmedPassword = passwordHex.trimmingCharacters(in: .whitespacesAndNewlines)
            var password: [UInt8]?
            var pack: [UInt8]?
            if !trimmedPassword.isEmpty {
                password = try AuthNFCPasswordService.passwordBytes(fromHex: trimmedPassword)
                pack = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: password!)
            }

            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AuthNFCError.emptyContent
            }

            isBusy = true
            status = .progress("Ready to Scan", message: "Hold the tag steady. Authentication runs only if protected pages will be written.")

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold the NTAG213/215/216 near the iPhone to write content."
            ) { tag in
                try await self.performAuthenticatedWrite(
                    tag: tag,
                    password: password,
                    pack: pack,
                    content: content
                )
            }

            status = .success(
                "Write Successful and Verified",
                message: "\(result.variant.displayName): wrote \(result.bytesWritten) UTF-8 byte(s). Authentication \(result.authenticated ? "succeeded" : "was not required"); read-back verified.",
                nextStep: "Use Read Tag (No Authentication) or Read Content to display the stored text."
            )
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else if error == .authenticationRejected {
                status = .from(error: .authenticationRejected)
            } else {
                status = .from(error: error)
            }
        } catch {
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
    }

    /// Existing read path: may authenticate when PROT enables read protection and a password is supplied.
    func readContent(passwordHex: String) async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            let trimmed = passwordHex.trimmingCharacters(in: .whitespacesAndNewlines)
            var password: [UInt8]?
            var pack: [UInt8]?
            if !trimmed.isEmpty {
                password = try AuthNFCPasswordService.passwordBytes(fromHex: trimmed)
                pack = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: password!)
            }

            isBusy = true
            status = .progress("Ready to Scan", message: "Reading stored content.")

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold the NTAG213/215/216 near the iPhone to read content."
            ) { tag in
                try await self.performRead(tag: tag, password: password, pack: pack)
            }

            status = .success(
                "Read Successful",
                message: "[\(result.variant.displayName)] \(result.protectionNote)\n\n\(result.text)",
                nextStep: result.authenticationUsed
                    ? "Authentication was used because read access is protected."
                    : "This read does not prove the password is correct."
            )
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else {
                status = .from(error: error)
            }
        } catch {
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
    }

    /// Dedicated unauthenticated read: never sends PWD_AUTH, never writes, never uses a password.
    func readTagWithoutAuthentication() async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            isBusy = true
            status = .progress("Ready to Scan", message: "Reading accessible content without password authentication.")

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold the NTAG213/215/216 near the iPhone to read without authentication."
            ) { tag in
                try await self.performUnauthenticatedRead(tag: tag)
            }

            if result.contentFormat == .empty {
                status = .warning(
                    "No Readable Content",
                    message: "[\(result.variant.displayName)] \(result.protectionNote)",
                    nextStep: "Write content with this demo, or use a tag with accessible NDEF/demo data."
                )
            } else {
                status = .success(
                    "Read Successful",
                    message: "[\(result.variant.displayName)] \(result.protectionNote)\n\n\(result.text)",
                    nextStep: "PWD_AUTH was not sent. This does not bypass read protection when PROT requires it."
                )
            }
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning("Tag Removed or Session Cancelled", message: error.explanation, nextStep: error.suggestedNextStep)
            } else if error == .authenticationRequired {
                status = .from(error: .authenticationRequired)
            } else {
                status = .from(error: error)
            }
        } catch {
            status = .from(error: AuthNFCError.fromNFCReaderError(error))
        }

        isBusy = false
    }

    func clearStatus() {
        status = .idle
        lastAuthCheck = nil
    }

    // MARK: - Session

    private func withConnectedMiFareTag<T>(
        alertMessage: String,
        perform: @escaping (NFCMiFareTag) async throws -> T
    ) async throws -> T {
        guard NFCTagReaderSession.readingAvailable else {
            throw AuthNFCError.nfcUnavailable
        }
        guard session == nil, tagContinuation == nil else {
            throw AuthNFCError.sessionAlreadyActive
        }

        let tag = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NFCMiFareTag, Error>) in
            self.didResumeTagContinuation = false
            self.tagContinuation = continuation
            guard let newSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil) else {
                self.tagContinuation = nil
                continuation.resume(throwing: AuthNFCError.nfcUnavailable)
                return
            }
            newSession.alertMessage = alertMessage
            self.session = newSession
            newSession.begin()
        }

        do {
            let value = try await perform(tag)
            session?.alertMessage = "Success"
            session?.invalidate()
            session = nil
            return value
        } catch {
            let message: String
            if let authError = error as? AuthNFCError {
                message = authError.title
            } else {
                message = error.localizedDescription
            }
            session?.invalidate(errorMessage: message)
            session = nil
            throw error
        }
    }

    // MARK: - Operations

    private func performAuthCheck(
        tag: NFCMiFareTag,
        legacyPassword: [UInt8],
        legacyPACK: [UInt8]
    ) async throws -> AuthNFCAuthCheckResult {
        status = .progress("Tag Detected", message: "Identifying NTAG variant via GET_VERSION.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        let expected = try await expectedCredentials(
            tag: tag,
            profile: profile,
            legacyPassword: legacyPassword,
            legacyPACK: legacyPACK
        )

        status = .progress("Reading Configuration", message: "Reading AUTH0 and ACCESS.")

        var didAuth = false
        let snapshot: AuthNFCConfigSnapshot
        do {
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch {
            status = .progress("Authenticating", message: "Configuration pages are not readable; trying PWD_AUTH.")
            do {
                try await AuthNFCTagService.authenticate(
                    tag,
                    password: expected.password,
                    expectedPACK: expected.pack
                )
                didAuth = true
            } catch AuthNFCError.packMismatch {
                throw AuthNFCError.packMismatch
            } catch AuthNFCError.authenticationRejected {
                throw AuthNFCError.authenticationRejected
            } catch {
                throw AuthNFCError.authenticationRejected
            }
            status = .progress("Authentication Successful", message: "Re-reading configuration.")
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        }

        let isProtected = snapshot.isEffectivelyProtected(on: profile)
        let passwordMatch: AuthNFCPasswordMatchStatus

        if !isProtected {
            passwordMatch = .skipped
        } else if didAuth {
            passwordMatch = .matched
        } else {
            status = .progress("Authenticating", message: "Protection is enabled. Verifying expected credentials.")
            do {
                try await AuthNFCTagService.authenticate(
                    tag,
                    password: expected.password,
                    expectedPACK: expected.pack
                )
                passwordMatch = .matched
            } catch {
                passwordMatch = .rejected
            }
        }

        return AuthNFCAuthCheckResult(
            variant: profile.variant,
            displayName: profile.displayName,
            auth0: snapshot.auth0,
            isProtected: isProtected,
            isReadWriteProtection: snapshot.isReadWriteProtection,
            isConfigLocked: snapshot.isConfigLocked,
            passwordMatch: passwordMatch
        )
    }

    private func performCredentialPreview(tag: NFCMiFareTag) async throws -> AuthNFCDerivedCredentials {
        status = .progress("Tag Detected", message: "Identifying tag. No authentication will be sent.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        guard Self.usesUIDDerivedCredentials(profile.variant) else {
            throw AuthNFCError.unsupportedTagType(
                details: "Test Auth previews UID-derived credentials for NTAG213 and NTAG215 only (got \(profile.displayName))."
            )
        }
        let uid = try await AuthNFCTagService.readUID(tag)
        return try AuthNFCCredentialDerivation.deriveCredentials(uid: uid)
    }

    static func usesUIDDerivedCredentials(_ variant: AuthNFCTagVariant) -> Bool {
        variant == .ntag213 || variant == .ntag215
    }

    private func performRegistration(
        tag: NFCMiFareTag,
        allowOverwrite: Bool,
        legacyPassword: [UInt8],
        legacyPACK: [UInt8],
        currentPassword: [UInt8]?
    ) async throws -> AuthNFCRegisterResult {
        status = .progress("Tag Detected", message: "Identifying NTAG variant via GET_VERSION.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        let snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)

        if snapshot.isConfigLocked {
            throw AuthNFCError.configurationPermanentlyLocked
        }

        let newCredentials = try await expectedCredentials(
            tag: tag,
            profile: profile,
            legacyPassword: legacyPassword,
            legacyPACK: legacyPACK
        )
        let newPassword = newCredentials.password
        let newPACK = newCredentials.pack

        if snapshot.isEffectivelyProtected(on: profile) {
            guard allowOverwrite else {
                throw AuthNFCError.existingProtectionRequiresConfirmation
            }
            try await authenticateForOverwrite(
                tag: tag,
                profile: profile,
                derivedPassword: newPassword,
                derivedPACK: newPACK,
                legacyPassword: legacyPassword,
                legacyPACK: legacyPACK,
                currentPassword: currentPassword
            )
        }

        // Write PWD, PACK, then ACCESS (write-only, CFGLCK=0), then AUTH0=user start.
        // Never touch lock pages. Use only the identified profile addresses.
        do {
            try await AuthNFCTagService.writePage(tag, page: profile.pwdPage, data: newPassword)
            try await AuthNFCTagService.writePage(
                tag,
                page: profile.packPage,
                data: AuthNFCPasswordService.makePACKPage(pack: newPACK)
            )
            let cfg1 = AuthNFCPasswordService.makeCFG1WriteProtectOnly(preserving: snapshot)
            try await AuthNFCTagService.writePage(tag, page: profile.cfg1Page, data: cfg1)
            let cfg0 = AuthNFCPasswordService.makeCFG0(
                preserving: snapshot,
                auth0: profile.userMemoryStartPage
            )
            try await AuthNFCTagService.writePage(tag, page: profile.cfg0Page, data: cfg0)
        } catch let error as AuthNFCError {
            throw AuthNFCError.partialConfigurationFailure(details: error.explanation)
        } catch {
            throw AuthNFCError.partialConfigurationFailure(details: error.localizedDescription)
        }

        // Verify configuration + authentication.
        let verified = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        guard verified.auth0 == profile.userMemoryStartPage,
              !verified.isReadWriteProtection,
              !verified.isConfigLocked else {
            throw AuthNFCError.partialConfigurationFailure(
                details: String(
                    format: "Post-check AUTH0=0x%02X PROT=%@ CFGLCK=%@ (%@)",
                    verified.auth0,
                    verified.isReadWriteProtection ? "1" : "0",
                    verified.isConfigLocked ? "1" : "0",
                    profile.displayName
                )
            )
        }

        status = .progress("Authentication Successful", message: "Verifying PACK with PWD_AUTH after configuration.")
        try await AuthNFCTagService.authenticate(tag, password: newPassword, expectedPACK: newPACK)

        return AuthNFCRegisterResult(
            variant: profile.variant,
            verifiedAuth0: verified.auth0,
            writeProtectionOnly: !verified.isReadWriteProtection
        )
    }

    private func expectedCredentials(
        tag: NFCMiFareTag,
        profile: AuthNFCTagProfile,
        legacyPassword: [UInt8],
        legacyPACK: [UInt8]
    ) async throws -> (password: [UInt8], pack: [UInt8]) {
        if Self.usesUIDDerivedCredentials(profile.variant) {
            let uid = try await AuthNFCTagService.readUID(tag)
            let derived = try AuthNFCCredentialDerivation.deriveCredentials(uid: uid)
            return (derived.password, derived.pack)
        }
        return (legacyPassword, legacyPACK)
    }

    /// Tries derived credentials, then legacy shared password, then an explicit current password.
    private func authenticateForOverwrite(
        tag: NFCMiFareTag,
        profile: AuthNFCTagProfile,
        derivedPassword: [UInt8],
        derivedPACK: [UInt8],
        legacyPassword: [UInt8],
        legacyPACK: [UInt8],
        currentPassword: [UInt8]?
    ) async throws {
        var candidates: [(password: [UInt8], pack: [UInt8])] = []
        if Self.usesUIDDerivedCredentials(profile.variant) {
            candidates.append((derivedPassword, derivedPACK))
            candidates.append((legacyPassword, legacyPACK))
        } else {
            candidates.append((legacyPassword, legacyPACK))
        }
        if let currentPassword {
            let currentPACK = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: currentPassword)
            if !candidates.contains(where: { $0.password == currentPassword && $0.pack == currentPACK }) {
                candidates.append((currentPassword, currentPACK))
            }
        }

        for candidate in candidates {
            do {
                try await AuthNFCTagService.authenticate(
                    tag,
                    password: candidate.password,
                    expectedPACK: candidate.pack
                )
                return
            } catch AuthNFCError.authenticationRejected, AuthNFCError.packMismatch {
                continue
            } catch AuthNFCError.unexpectedResponse {
                continue
            }
        }
        throw AuthNFCError.authenticationRejected
    }

    private func performAuthenticatedWrite(
        tag: NFCMiFareTag,
        password: [UInt8]?,
        pack: [UInt8]?,
        content: String
    ) async throws -> AuthNFCWriteResult {
        status = .progress("Tag Detected", message: "Identifying tag and protection configuration.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        let encoded = try AuthNFCPasswordService.encodeContent(content, for: profile)

        var didAuth = false
        let snapshot: AuthNFCConfigSnapshot
        do {
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch {
            // Config pages themselves may be read-protected (PROT=1). Auth first if possible.
            guard let password, let pack else {
                throw AuthNFCError.authenticationRequired
            }
            status = .progress("Authentication Required", message: "Configuration pages are not readable; authenticating before write.")
            do {
                try await AuthNFCTagService.authenticate(tag, password: password, expectedPACK: pack)
            } catch AuthNFCError.packMismatch {
                throw AuthNFCError.packMismatch
            } catch {
                throw AuthNFCError.authenticationRejected
            }
            didAuth = true
            status = .progress("Authentication Successful", message: "PACK verified. Re-reading configuration.")
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        }

        let startPage = profile.userMemoryStartPage
        let pageCount = AuthNFCPasswordService.pagesNeeded(forEncodedData: encoded)
        let writeNeedsAuth = snapshot.writeRangeRequiresAuthentication(
            startPage: startPage,
            pageCount: pageCount,
            profile: profile
        )

        if writeNeedsAuth {
            if !didAuth {
                guard let password, let pack else {
                    throw AuthNFCError.authenticationRequired
                }
                status = .progress("Authentication Required", message: "Destination pages are password-protected. Sending PWD_AUTH.")
                do {
                    try await AuthNFCTagService.authenticate(tag, password: password, expectedPACK: pack)
                } catch AuthNFCError.packMismatch {
                    throw AuthNFCError.packMismatch
                } catch {
                    throw AuthNFCError.authenticationRejected
                }
                didAuth = true
            }
            status = .progress("Authentication Successful", message: "PACK verified. Writing user memory.")
        } else {
            // Unprotected / normal write path: never send PWD_AUTH.
            status = .progress("Writing In Progress", message: "Tag is not write-protecting these pages. Writing without PWD_AUTH.")
        }

        // Fail closed: never write protected pages without a successful auth in this session.
        if writeNeedsAuth && !didAuth {
            throw AuthNFCError.authenticationRequired
        }

        status = .progress("Writing In Progress", message: "Writing \(encoded.count) encoded byte(s) to \(profile.displayName) user memory.")

        do {
            try await AuthNFCTagService.writePages(
                tag,
                startPage: startPage,
                data: encoded,
                profile: profile,
                mapNAKToProtectionError: !didAuth
            )
        } catch let error as AuthNFCError {
            if error == .writeProtectionOrLock {
                throw error
            }
            throw error
        } catch {
            throw AuthNFCError.writeFailure(details: error.localizedDescription)
        }

        status = .progress("Writing In Progress", message: "Verifying written content with read-back.")
        let readBack = try await AuthNFCTagService.readContentBytes(tag, startPage: startPage, pageCount: pageCount)
        guard readBack.prefix(encoded.count) == encoded else {
            throw AuthNFCError.partialWriteFailure(details: "Read-back did not match written bytes.")
        }

        let utf8Count = Int(encoded[0]) << 8 | Int(encoded[1])
        return AuthNFCWriteResult(
            variant: profile.variant,
            bytesWritten: utf8Count,
            authenticated: didAuth,
            verified: true
        )
    }

    private func performRead(
        tag: NFCMiFareTag,
        password: [UInt8]?,
        pack: [UInt8]?
    ) async throws -> AuthNFCReadResult {
        status = .progress("Tag Detected", message: "Identifying tag.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        let snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)

        let startPage = profile.userMemoryStartPage
        let needsReadAuth = snapshot.readRequiresAuthentication(forPage: startPage, profile: profile)

        var authUsed = false
        if needsReadAuth {
            guard let password, let pack else {
                throw AuthNFCError.authenticationRequired
            }
            status = .progress("Authentication Required", message: "Content is read-protected. Authenticating.")
            try await AuthNFCTagService.authenticate(tag, password: password, expectedPACK: pack)
            authUsed = true
            status = .progress("Authentication Successful", message: "Reading content.")
        }

        let pageCount = profile.contentPageCount
        let bytes: Data
        do {
            bytes = try await AuthNFCTagService.readContentBytes(tag, startPage: startPage, pageCount: pageCount)
        } catch {
            throw AuthNFCError.readFailure(details: error.localizedDescription)
        }

        let text = try AuthNFCPasswordService.decodeContent(bytes, for: profile)

        let note: String
        if !snapshot.isEffectivelyProtected(on: profile) {
            note = "Tag AUTH0 shows protection disabled. This read did not use password authentication."
        } else if snapshot.isReadWriteProtection {
            note = authUsed
                ? "Content is in a read/write-protected region; authentication was performed."
                : "Content is read/write-protected."
        } else {
            note = "Tag uses write-only password protection (AUTH0=0x\(String(snapshot.auth0, radix: 16))). Reading succeeded without proving the password."
        }

        return AuthNFCReadResult(
            variant: profile.variant,
            text: text,
            authenticationUsed: authUsed,
            protectionNote: note,
            contentFormat: .demoLengthPrefixed
        )
    }

    /// Read-only path: never sends PWD_AUTH, never writes, never mutates configuration.
    private func performUnauthenticatedRead(tag: NFCMiFareTag) async throws -> AuthNFCReadResult {
        status = .progress("Tag Detected", message: "Identifying tag. PWD_AUTH will not be sent.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)

        status = .progress("Reading Without Authentication", message: "Inspecting accessible configuration and user memory.")

        var snapshot: AuthNFCConfigSnapshot?
        var configNote = ""
        do {
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch {
            configNote = "Configuration pages could not be read without authentication. "
        }

        if let snapshot {
            let startPage = profile.userMemoryStartPage
            if snapshot.readRequiresAuthentication(forPage: startPage, profile: profile) {
                throw AuthNFCError.authenticationRequired
            }
            let prot = snapshot.isReadWriteProtection ? "read/write" : "write-only"
            if snapshot.isEffectivelyProtected(on: profile) {
                configNote = "Protection enabled: AUTH0=0x\(String(snapshot.auth0, radix: 16)), ACCESS \(prot) (PROT=\(snapshot.isReadWriteProtection ? "1" : "0")). "
            } else {
                configNote = "Protection disabled (AUTH0=0x\(String(snapshot.auth0, radix: 16))). "
            }
        }

        let startPage = profile.userMemoryStartPage
        let pageCount = profile.contentPageCount
        let bytes: Data
        do {
            bytes = try await AuthNFCTagService.readContentBytes(tag, startPage: startPage, pageCount: pageCount)
        } catch {
            // Likely read-protected user memory without a readable config snapshot.
            throw AuthNFCError.authenticationRequired
        }

        let interpreted = AuthNFCPasswordService.interpretUserMemory(bytes, for: profile)
        guard interpreted.format != .empty else {
            return AuthNFCReadResult(
                variant: profile.variant,
                text: "",
                authenticationUsed: false,
                protectionNote: configNote + "No readable demo or NDEF content in accessible user memory. PWD_AUTH was not sent.",
                contentFormat: .empty
            )
        }

        let formatNote: String
        switch interpreted.format {
        case .demoLengthPrefixed:
            formatNote = "Decoded demo length-prefixed UTF-8 payload."
        case .ndef:
            formatNote = "Decoded NDEF text/URI from Type 2 TLVs."
        case .rawHex:
            formatNote = "No demo/NDEF payload decoded; showing raw hex preview."
        case .empty:
            formatNote = ""
        }

        return AuthNFCReadResult(
            variant: profile.variant,
            text: interpreted.text,
            authenticationUsed: false,
            protectionNote: configNote + formatNote + " PWD_AUTH was not sent.",
            contentFormat: interpreted.format
        )
    }
}

// MARK: - NFCTagReaderSessionDelegate

extension AuthNFCManager: NFCTagReaderSessionDelegate {

    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.handleInvalidation(error)
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Task { @MainActor in
            await self.handleDetect(session: session, tags: tags)
        }
    }

    private func handleInvalidation(_ error: Error) {
        session = nil
        guard let continuation = tagContinuation, !didResumeTagContinuation else { return }
        didResumeTagContinuation = true
        tagContinuation = nil

        let mapped = AuthNFCError.fromNFCReaderError(error)
        continuation.resume(throwing: mapped)
    }

    private func handleDetect(session: NFCTagReaderSession, tags: [NFCTag]) async {
        guard tags.count == 1 else {
            session.invalidate(errorMessage: AuthNFCError.multipleTagsDetected.title)
            failTagContinuation(.multipleTagsDetected)
            return
        }

        status = .progress("Tag Detected", message: "Connecting to tag.")

        let tag = tags[0]
        session.connect(to: tag) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    session.invalidate(errorMessage: AuthNFCError.connectionFailed(details: "").title)
                    self.failTagContinuation(.connectionFailed(details: error.localizedDescription))
                    return
                }

                guard case let .miFare(miFareTag) = tag else {
                    session.invalidate(errorMessage: AuthNFCError.unsupportedTagType(details: "").title)
                    self.failTagContinuation(
                        .unsupportedTagType(details: "Tag is not NFCMiFare / ISO14443 Type 2.")
                    )
                    return
                }

                self.resumeTagContinuation(with: miFareTag)
            }
        }
    }

    private func resumeTagContinuation(with tag: NFCMiFareTag) {
        guard let continuation = tagContinuation, !didResumeTagContinuation else { return }
        didResumeTagContinuation = true
        tagContinuation = nil
        continuation.resume(returning: tag)
    }

    private func failTagContinuation(_ error: AuthNFCError) {
        guard let continuation = tagContinuation, !didResumeTagContinuation else { return }
        didResumeTagContinuation = true
        tagContinuation = nil
        continuation.resume(throwing: error)
    }
}
