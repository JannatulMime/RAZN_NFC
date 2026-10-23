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

    private var session: NFCTagReaderSession?
    private var tagContinuation: CheckedContinuation<NFCMiFareTag, Error>?
    private var didResumeTagContinuation = false

    // MARK: - Public API

    func registerPassword(
        passwordHex: String,
        confirmationHex: String,
        allowOverwrite: Bool,
        currentPasswordHex: String?
    ) async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        do {
            let newPassword = try AuthNFCPasswordService.validateMatchingPasswords(
                password: passwordHex,
                confirmation: confirmationHex
            )
            let newPACK = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: newPassword)

            var currentPassword: [UInt8]?
            if let currentPasswordHex, !currentPasswordHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentPassword = try AuthNFCPasswordService.passwordBytes(fromHex: currentPasswordHex)
            }

            isBusy = true
            status = .progress(
                "Ready to Scan",
                message: "Registering password on a supported NTAG21x. Keep the tag still."
            )

            let result = try await withConnectedMiFareTag(
                alertMessage: "Hold a compatible NTAG213, NTAG215, or NTAG216 near the iPhone to register the password."
            ) { tag in
                try await self.performRegistration(
                    tag: tag,
                    newPassword: newPassword,
                    newPACK: newPACK,
                    allowOverwrite: allowOverwrite,
                    currentPassword: currentPassword
                )
            }

            status = .success(
                "Password Registered",
                message: "\(result.variant.displayName) configured. AUTH0 is 0x\(String(result.verifiedAuth0, radix: 16)) with write-only protection. PACK was verified via PWD_AUTH. Configuration lock bits were not set.",
                nextStep: "Use Authenticate & Write with the same 8-character hex password, or Read Tag (No Authentication) to inspect accessible memory."
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

    private func performRegistration(
        tag: NFCMiFareTag,
        newPassword: [UInt8],
        newPACK: [UInt8],
        allowOverwrite: Bool,
        currentPassword: [UInt8]?
    ) async throws -> AuthNFCRegisterResult {
        status = .progress("Tag Detected", message: "Identifying NTAG variant via GET_VERSION.")
        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        let snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)

        if snapshot.isConfigLocked {
            throw AuthNFCError.configurationPermanentlyLocked
        }

        if snapshot.isEffectivelyProtected(on: profile) {
            guard allowOverwrite else {
                throw AuthNFCError.existingProtectionRequiresConfirmation
            }
            guard let currentPassword else {
                throw AuthNFCError.existingProtectionRequiresConfirmation
            }
            let currentPACK = AuthNFCPasswordService.derivedPACK(fromPasswordBytes: currentPassword)
            do {
                try await AuthNFCTagService.authenticate(tag, password: currentPassword, expectedPACK: currentPACK)
            } catch is AuthNFCError {
                // Do not guess unknown PACK values from other tools.
                throw AuthNFCError.authenticationRejected
            }
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
