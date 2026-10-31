//
//  AuthNFCProductionUnregister.swift
//  RAZN NFC
//
//  Production path to disable AUTH0-based password protection on NTAG21x tags.
//  Uses the stored UserDefaults password (`authNFCStoredPassword`) and shared
//  AuthNFCTagService I/O. Does not erase NDEF/user content.
//

import CoreNFC
import Foundation

struct AuthNFCUnregisterResult: Equatable {
    var variant: AuthNFCTagVariant
    var verifiedAuth0: UInt8
    var wroteConfiguration: Bool
    var clearedStoredPassword: Bool
}

/// Pure tag-side unregister steps (no NFC session ownership).
enum AuthNFCProductionUnregisterGate {

    /// Authenticates with the stored password when needed, sets AUTH0 to `0xFF`, verifies,
    /// then clears the local password store only after successful verification.
    /// Never writes configuration before a required PWD_AUTH succeeds.
    static func disablePasswordProtection(
        tag: NFCMiFareTag,
        passwordStore: AuthNFCPasswordStore,
        onProgress: (@MainActor (String, String) -> Void)? = nil
    ) async throws -> AuthNFCUnregisterResult {
        guard let hex = passwordStore.retrieve() else {
            throw AuthNFCError.noStoredPassword
        }
        return try await disablePasswordProtection(
            tag: tag,
            passwordHex: hex,
            passwordStore: passwordStore,
            clearStoredPassword: true,
            onProgress: onProgress
        )
    }

    /// Disables password protection using an explicit hex password.
    /// When `clearStoredPassword` is false, the local store is left unchanged (Tag Manager).
    /// Pass `expectedPACK` for NTAG215 HMAC-derived credentials; otherwise PACK is SHA256(pwd)[0..<2].
    static func disablePasswordProtection(
        tag: NFCMiFareTag,
        passwordHex: String,
        expectedPACK: [UInt8]? = nil,
        passwordStore: AuthNFCPasswordStore? = nil,
        clearStoredPassword: Bool = false,
        onProgress: (@MainActor (String, String) -> Void)? = nil
    ) async throws -> AuthNFCUnregisterResult {
        await onProgress?("Scan Tag", "Identifying tag type.")

        let password: [UInt8]
        do {
            password = try AuthNFCPasswordService.passwordBytes(fromHex: passwordHex)
        } catch {
            throw AuthNFCError.invalidPasswordFormat
        }
        let pack = expectedPACK ?? AuthNFCPasswordService.derivedPACK(fromPasswordBytes: password)
        guard pack.count == 2 else {
            throw AuthNFCError.invalidPasswordFormat
        }

        let (_, profile) = try await AuthNFCTagService.identifySupportedTag(tag)
        // Requirements focus on NTAG213/215; NTAG216 shares the same AUTH0 disable semantics
        // with a distinct verified profile map.
        await onProgress?(
            "Tag Detected",
            "\(profile.displayName) identified. Reading configuration (CFG0 page 0x\(String(profile.cfg0Page, radix: 16)))."
        )

        var didAuth = false
        let snapshot: AuthNFCConfigSnapshot
        do {
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch {
            await onProgress?("Authenticating", "Configuration pages are not readable; sending PWD_AUTH.")
            try await authenticate(tag: tag, password: password, pack: pack)
            didAuth = true
            await onProgress?("Authenticating", "Authentication succeeded. Re-reading configuration.")
            snapshot = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        }

        if snapshot.isConfigLocked {
            throw AuthNFCError.configurationPermanentlyLocked
        }

        let effectivelyProtected = snapshot.isEffectivelyProtected(on: profile)

        if effectivelyProtected && !didAuth {
            await onProgress?("Authenticating", "Password protection is enabled. Sending PWD_AUTH before any configuration write.")
            try await authenticate(tag: tag, password: password, pack: pack)
            didAuth = true
            await onProgress?("Authenticating", "Authentication succeeded.")
        }

        // Fail closed: never write protected configuration without auth in this session.
        if effectivelyProtected && !didAuth {
            throw AuthNFCError.authenticationRequired
        }

        var wroteConfiguration = false
        if snapshot.auth0 != AuthNFCConstants.auth0Disabled {
            await onProgress?(
                "Removing Password Protection",
                "Updating AUTH0 to 0xFF on \(profile.displayName) CFG0 (page 0x\(String(profile.cfg0Page, radix: 16))). Other configuration bytes are preserved."
            )
            let cfg0 = AuthNFCPasswordService.makeCFG0(
                preserving: snapshot,
                auth0: AuthNFCConstants.auth0Disabled
            )
            // Safety: only AUTH0 (byte 3) may differ from the preserved CFG0 bytes.
            guard cfg0.count == 4,
                  snapshot.cfg0Raw.count >= 4,
                  cfg0[0] == snapshot.cfg0Raw[0],
                  cfg0[1] == snapshot.cfg0Raw[1],
                  cfg0[2] == snapshot.cfg0Raw[2],
                  cfg0[3] == AuthNFCConstants.auth0Disabled else {
                throw AuthNFCError.partialConfigurationFailure(
                    details: "Refusing to write CFG0: unexpected page layout before WRITE."
                )
            }
            do {
                try await AuthNFCTagService.writePage(tag, page: profile.cfg0Page, data: cfg0)
            } catch let error as AuthNFCError {
                if error == .writeProtectionOrLock {
                    throw AuthNFCError.configurationPermanentlyLocked
                }
                throw AuthNFCError.writeFailure(details: error.explanation)
            } catch {
                throw AuthNFCError.writeFailure(details: error.localizedDescription)
            }
            wroteConfiguration = true
        } else {
            await onProgress?(
                "Verifying Configuration",
                "AUTH0 is already 0xFF (password-based protection threshold disabled)."
            )
        }

        await onProgress?("Verifying Configuration", "Reading CFG0 to confirm AUTH0 is 0xFF.")
        let verified: AuthNFCConfigSnapshot
        do {
            verified = try await AuthNFCTagService.readConfigSnapshot(tag, profile: profile)
        } catch {
            throw AuthNFCError.configurationVerificationFailed
        }

        guard verified.auth0 == AuthNFCConstants.auth0Disabled,
              !verified.isEffectivelyProtected(on: profile) else {
            throw AuthNFCError.configurationVerificationFailed
        }

        var didClearStore = false
        if clearStoredPassword, let passwordStore {
            passwordStore.clear()
            didClearStore = true
        }

        return AuthNFCUnregisterResult(
            variant: profile.variant,
            verifiedAuth0: verified.auth0,
            wroteConfiguration: wroteConfiguration,
            clearedStoredPassword: didClearStore
        )
    }

    private static func authenticate(
        tag: NFCMiFareTag,
        password: [UInt8],
        pack: [UInt8]
    ) async throws {
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

/// NFCTagReaderSession owner for the production Unregister action.
@MainActor
final class AuthNFCUnregisterController: NSObject, ObservableObject {

    @Published private(set) var isBusy = false
    @Published var status: AuthNFCStatusMessage = .idle

    private let passwordStore: AuthNFCPasswordStore
    private var session: NFCTagReaderSession?
    private var tagContinuation: CheckedContinuation<NFCMiFareTag, Error>?
    private var didResumeTagContinuation = false

    init(passwordStore: AuthNFCPasswordStore = AuthNFCPasswordStore()) {
        self.passwordStore = passwordStore
        super.init()
    }

    /// Starts the unregister flow after the UI confirmation dialog.
    func unregister() async {
        guard !isBusy else {
            status = .from(error: .operationInProgress)
            return
        }

        guard passwordStore.retrieve() != nil else {
            status = .from(error: .noStoredPassword)
            return
        }

        // Validate format before opening the NFC sheet (retrieve already validates; double-check).
        if let hex = passwordStore.retrieve() {
            do {
                _ = try AuthNFCPasswordService.passwordBytes(fromHex: hex)
            } catch {
                status = .from(error: .invalidPasswordFormat)
                return
            }
        }

        isBusy = true
        status = .progress(
            "Scan Tag",
            message: "Scan the NFC tag you want to unregister. Password-based protection will be disabled on the tag after authentication."
        )

        do {
            let result = try await withConnectedMiFareTag(
                alertMessage: "Scan the NFC tag you want to unregister."
            ) { tag in
                try await AuthNFCProductionUnregisterGate.disablePasswordProtection(
                    tag: tag,
                    passwordStore: self.passwordStore,
                    onProgress: { [weak self] title, message in
                        self?.status = .progress(title, message: message)
                    }
                )
            }

            let wroteNote = result.wroteConfiguration
                ? "AUTH0 was updated to 0xFF and verified."
                : "AUTH0 was already 0xFF; no configuration write was required."
            status = .success(
                "Unregister Successful",
                message: "\(result.variant.displayName): password-based protection has been disabled on the tag. \(wroteNote) The locally stored password was cleared.",
                nextStep: "You can write to this tag again without password authentication, unless other lock bits or protection remain."
            )
        } catch let error as AuthNFCError {
            if error == .userCancelled {
                status = .warning(
                    "Tag Removed or Session Cancelled",
                    message: error.explanation,
                    nextStep: error.suggestedNextStep
                )
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
            session?.alertMessage = "Unregister successful"
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
}

extension AuthNFCUnregisterController: NFCTagReaderSessionDelegate {

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
        continuation.resume(throwing: AuthNFCError.fromNFCReaderError(error))
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
