import CoreNFC

class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate, NFCTagReaderSessionDelegate {

    @Published var message = "Waiting for NFC tag..."
    /// NDEF session used for production reads (never requires a password).
    private var ndefSession: NFCNDEFReaderSession?
    /// Tag session used for production writes (may PWD_AUTH before writeNDEF).
    private var tagSession: NFCTagReaderSession?
    var onScanComplete: ((String) -> Void)?
    var onWriteComplete: ((Bool) -> Void)?
    /// Optional user-facing failure detail (never includes the password).
    var onWriteFailureMessage: ((String) -> Void)?
    var isWriting = false
    var textToWrite: String?

    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    private let passwordStore: AuthNFCPasswordStore

    init(passwordStore: AuthNFCPasswordStore = AuthNFCPasswordStore()) {
        self.passwordStore = passwordStore
        super.init()
    }

    func scan(completion: @escaping (String) -> Void) {
        onScanComplete = completion
        isWriting = false
        startNDEFSession()
    }

    /// If `text` looks like a URL, we’ll write a URL record. Otherwise we write a Text record.
    func write(_ text: String, completion: @escaping (Bool) -> Void) {
        onWriteComplete = completion
        textToWrite = text
        isWriting = true
        startTagWriteSession()
    }

    /// Convenience: explicitly write a URL (recommended for your use case)
    func writeURL(_ urlString: String, completion: @escaping (Bool) -> Void) {
        onWriteComplete = completion
        textToWrite = urlString
        isWriting = true
        startTagWriteSession()
    }

    // MARK: - Session start

    private func startNDEFSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            NSLog("NFC is not available on this device")
            alertMessage = "NFC is not available on this device"
            showAlert = true
            return
        }

        ndefSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        ndefSession?.alertMessage = "Hold your iPhone near an NFC tag to read."
        ndefSession?.begin()
    }

    private func startTagWriteSession() {
        guard NFCTagReaderSession.readingAvailable else {
            NSLog("NFC is not available on this device")
            alertMessage = "NFC is not available on this device"
            showAlert = true
            reportWriteFailure("NFC is not available on this device.")
            return
        }

        guard tagSession == nil else {
            reportWriteFailure("Another NFC session is already active. Wait for it to finish.")
            return
        }

        guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil) else {
            reportWriteFailure("NFC is not available on this device.")
            return
        }
        session.alertMessage = "Hold your iPhone near an NFC tag to write."
        tagSession = session
        session.begin()
    }

    // MARK: - Reading (NDEF session — no password)

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard !isWriting else { return }
        for message in messages { processMessage(message) }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        // Production read path only. Writes use NFCTagReaderSession.
        handleReading(session: session, tags: tags)
    }

    private func handleReading(session: NFCNDEFReaderSession, tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than 1 tag detected. Please try again with only one tag."
            session.invalidate()
            return
        }

        let tag = tags.first!
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { status, _, error in
                if let error = error {
                    session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                case .readOnly, .readWrite:
                    tag.readNDEF { message, error in
                        if let error = error {
                            session.invalidate(errorMessage: "Read error: \(error.localizedDescription)")
                        } else if let message = message {
                            self.processMessage(message)
                            session.alertMessage = "Tag read successfully!"
                            session.invalidate()
                        } else {
                            session.invalidate(errorMessage: "No NDEF message found on tag")
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }

    private func processMessage(_ message: NFCNDEFMessage) {
        for record in message.records {
            switch record.typeNameFormat {
            case .nfcWellKnown:
                // Prefer URL if present
                if let url = record.wellKnownTypeURIPayload() {
                    DispatchQueue.main.async {
                        self.message = url.absoluteString
                        self.onScanComplete?(url.absoluteString)
                    }
                    return
                }
                if let text = record.wellKnownTypeTextPayload().0 {
                    DispatchQueue.main.async {
                        self.message = text
                        self.onScanComplete?(text)
                    }
                }
            case .absoluteURI:
                if let text = String(data: record.payload, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.message = text
                        self.onScanComplete?(text)
                    }
                }
            default:
                break
            }
        }
    }

    // MARK: - Writing (TagReader session — auth gate then existing NDEF write)

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if readerError.code != .readerSessionInvalidationErrorUserCanceled {
                // Avoid noisy logs for cancel; other codes may still be useful for debug without secrets.
                if readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead {
                    NSLog("Tag write session invalidated: \(readerError.code.rawValue)")
                }
            }
        }
        tagSession = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard isWriting else {
            session.invalidate(errorMessage: "Unexpected tag detection during write.")
            return
        }

        if tags.count > 1 {
            session.invalidate(errorMessage: "More than 1 tag detected. Please try again with only one tag.")
            reportWriteFailure("More than one tag was present. Use a single tag.")
            return
        }

        guard let first = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            reportWriteFailure("No NFC tag was detected during the session.")
            return
        }

        guard case .miFare(let miFareTag) = first else {
            session.invalidate(errorMessage: "Unsupported tag type for writing.")
            reportWriteFailure("Unsupported or unidentified tag. Use an NTAG213, NTAG215, or NTAG216.")
            return
        }

        Task {
            await self.performProductionWrite(session: session, tag: miFareTag)
        }
    }

    private func performProductionWrite(session: NFCTagReaderSession, tag: NFCMiFareTag) async {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.connect(to: .miFare(tag)) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            session.invalidate(errorMessage: "Connection error")
            reportWriteFailure("Could not connect to the tag. Keep the tag near the iPhone and try again.")
            return
        }

        guard let textToWrite else {
            session.invalidate(errorMessage: "No text to write")
            reportWriteFailure("No text to write.")
            return
        }

        // Preserve existing payload encoding: URL vs Text NDEF records.
        let message: NFCNDEFMessage
        if let urlPayload = makeURIPayload(from: textToWrite) {
            message = NFCNDEFMessage(records: [urlPayload])
        } else {
            let textPayload = NFCNDEFPayload.wellKnownTypeTextPayload(string: textToWrite, locale: Locale(identifier: "en"))!
            message = NFCNDEFMessage(records: [textPayload])
        }

        // Auth gate: PWD_AUTH only when protected destination pages require it.
        // Never writes payload before this returns successfully when auth is required.
        //
        // After MiFare commands, Core NFC queryNDEFStatus/writeNDEF often fail with
        // NFCError 104 ("Stack Error"). Write the same NDEF URI/Text payload via
        // Type 2 page WRITE in this session instead.
        let prep: AuthNFCProductionWritePrep
        do {
            prep = try await AuthNFCProductionWriteGate.prepareAuthenticatedWrite(
                tag: tag,
                ndefMessage: message,
                passwordStore: passwordStore
            )
        } catch let error as AuthNFCError {
            let userMessage = productionWriteErrorMessage(for: error)
            session.invalidate(errorMessage: error.title)
            reportWriteFailure(userMessage)
            return
        } catch {
            session.invalidate(errorMessage: "Authentication failed")
            reportWriteFailure(
                "Authentication failed. Check the stored password and try again. No new payload was written by this operation."
            )
            return
        }

        do {
            try await AuthNFCProductionWriteGate.writeNDEFViaPages(
                tag: tag,
                message: message,
                profile: prep.profile,
                authenticated: prep.authenticated
            )
            session.alertMessage = "Write successful!"
            session.invalidate()
            DispatchQueue.main.async {
                self.onWriteComplete?(true)
            }
        } catch let error as AuthNFCError {
            session.invalidate(errorMessage: error.title)
            reportWriteFailure(productionWriteErrorMessage(for: error))
        } catch {
            session.invalidate(errorMessage: "Write failed")
            reportWriteFailure(
                "The tag could not be written. Keep the tag near the iPhone and try again. If the problem continues, check the tag's protection settings."
            )
        }
    }

    private func productionWriteErrorMessage(for error: AuthNFCError) -> String {
        switch error {
        case .noStoredPassword:
            return error.explanation
        case .authenticationRejected, .packMismatch:
            return "Authentication failed. Check the stored password and try again. No new payload was written by this operation."
        case .invalidPasswordFormat:
            return error.explanation
        case .unsupportedTagType, .versionIdentificationFailed:
            return "Unsupported or unidentified tag. Use an NTAG213, NTAG215, or NTAG216."
        case .userCancelled:
            return "NFC session cancelled."
        case .tagRemoved, .sessionTimeoutOrInvalidation:
            return "The tag was removed or the NFC session timed out. Keep the tag near the iPhone and try again."
        case .writeProtectionOrLock:
            return "The tag could not be written. Keep the tag near the iPhone and try again. If the problem continues, check the tag's protection settings."
        default:
            return error.explanation
        }
    }

    private func reportWriteFailure(_ message: String) {
        DispatchQueue.main.async {
            self.onWriteFailureMessage?(message)
            self.onWriteComplete?(false)
        }
    }

    /// Returns a URI payload if the input is (or can be made into) a valid http(s) URL.
    private func makeURIPayload(from input: String) -> NFCNDEFPayload? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add https:// if the user passed "example.com"
        let normalized: String = {
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return trimmed
            } else if trimmed.contains(".") { // very light heuristic
                return "https://\(trimmed)"
            } else {
                return trimmed
            }
        }()

        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            return nil
        }

        // This is the key for iPhone auto-open behavior
        return NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
    }

    // MARK: - NDEF session end

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead &&
               readerError.code != .readerSessionInvalidationErrorUserCanceled {
                NSLog("Session invalidated with error: \(error.localizedDescription)")
            }
        }
        ndefSession = nil
    }
}
