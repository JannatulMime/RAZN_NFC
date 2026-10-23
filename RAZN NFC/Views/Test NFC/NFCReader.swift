import CoreNFC

class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate, NFCTagReaderSessionDelegate {

    @Published var message = "Waiting for NFC tag..."
    /// NDEF session used for production reads (never requires a password).
    private var ndefSession: NFCNDEFReaderSession?
    /// Tag session used for production writes (PWD_AUTH, then page write).
    private var tagSession: NFCTagReaderSession?
    var onScanComplete: ((String) -> Void)?
    var onWriteComplete: ((Bool) -> Void)?
    /// Optional user-facing failure detail (never includes the password).
    var onWriteFailureMessage: ((String) -> Void)?
    var isWriting = false
    var textToWrite: String?

    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    /// Titled dialog for a rejected production write. Reading does not set this.
    @Published var writeAlert: AuthNFCProductionWriteAlert?
    private var currentWriteGeneration: UInt = 0
    private var completedWriteGeneration: UInt = 0
    private var acceptedWriteGeneration: UInt = 0

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
        beginWrite(text, completion: completion)
    }

    /// Convenience: explicitly write a URL (recommended for your use case)
    func writeURL(_ urlString: String, completion: @escaping (Bool) -> Void) {
        beginWrite(urlString, completion: completion)
    }

    private func beginWrite(_ text: String, completion: @escaping (Bool) -> Void) {
        if tagSession != nil {
            let alert = AuthNFCProductionWriteAlert(
                title: "NFC Busy",
                message: "Another NFC session is already active. Wait for it to finish. Nothing was written."
            )
            DispatchQueue.main.async {
                self.writeAlert = alert
                completion(false)
            }
            return
        }

        currentWriteGeneration &+= 1
        onWriteComplete = completion
        textToWrite = text
        isWriting = true
        DispatchQueue.main.async {
            self.writeAlert = nil
        }
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
        let generation = currentWriteGeneration
        guard NFCTagReaderSession.readingAvailable else {
            NSLog("NFC is not available on this device")
            failWrite(
                session: nil,
                generation: generation,
                error: AuthNFCError.nfcUnavailable
            )
            return
        }

        guard tagSession == nil else {
            failWrite(
                session: nil,
                generation: generation,
                alert: AuthNFCProductionWriteAlert(
                    title: "NFC Busy",
                    message: "Another NFC session is already active. Wait for it to finish. Nothing was written."
                )
            )
            return
        }

        guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil) else {
            failWrite(session: nil, generation: generation, error: AuthNFCError.nfcUnavailable)
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
        guard acceptedWriteGeneration != currentWriteGeneration else { return }
        acceptedWriteGeneration = currentWriteGeneration
        let generation = currentWriteGeneration

        if tags.count > 1 {
            failWrite(session: session, generation: generation, error: AuthNFCError.multipleTagsDetected)
            return
        }

        guard let first = tags.first else {
            failWrite(session: session, generation: generation, error: AuthNFCError.noTagDetected)
            return
        }

        guard case .miFare(let miFareTag) = first else {
            failWrite(
                session: session,
                generation: generation,
                error: AuthNFCError.unsupportedTagType(details: "The tag is not MiFare Ultralight/NTAG.")
            )
            return
        }

        Task {
            await self.performProductionWrite(session: session, tag: miFareTag, generation: generation)
        }
    }

    private func performProductionWrite(
        session: NFCTagReaderSession,
        tag: NFCMiFareTag,
        generation: UInt
    ) async {
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
            failWrite(session: session, generation: generation, error: error)
            return
        }

        guard let textToWrite else {
            failWrite(
                session: session,
                generation: generation,
                alert: AuthNFCProductionWriteAlert(
                    title: "Write Failed",
                    message: "No text to write. Nothing was written."
                )
            )
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

        // Password protection and PWD_AUTH both have to succeed before any WRITE.
        // Page WRITE is used because queryNDEFStatus/writeNDEF often returns NFCError 104
        // after MiFare commands in the same session.
        do {
            try await AuthNFCProductionWriteGate.writeProtectedNDEF(
                tag: tag,
                message: message,
                passwordStore: passwordStore
            )
            finishWrite(session: session, generation: generation, success: true, alert: nil)
        } catch {
            failWrite(session: session, generation: generation, error: error)
        }
    }

    private func failWrite(session: NFCTagReaderSession?, generation: UInt, error: Error) {
        let alert = AuthNFCProductionWriteAlert.presented(for: error)
        if alert == nil, error is AuthNFCError || (error as? NFCReaderError)?.code == .readerSessionInvalidationErrorUserCanceled {
            finishWrite(session: session, generation: generation, success: false, alert: nil, invalidateSilently: true)
            return
        }
        failWrite(session: session, generation: generation, alert: alert)
    }

    private func failWrite(
        session: NFCTagReaderSession?,
        generation: UInt,
        alert: AuthNFCProductionWriteAlert?
    ) {
        finishWrite(session: session, generation: generation, success: false, alert: alert, invalidateSilently: false)
    }

    private func finishWrite(
        session: NFCTagReaderSession?,
        generation: UInt,
        success: Bool,
        alert: AuthNFCProductionWriteAlert?,
        invalidateSilently: Bool = false
    ) {
        guard generation == currentWriteGeneration, completedWriteGeneration != generation else { return }
        completedWriteGeneration = generation
        let completion = onWriteComplete
        onWriteComplete = nil
        if let session {
            if success {
                session.alertMessage = "Write successful!"
                session.invalidate()
            } else if let alert, !invalidateSilently {
                session.invalidate(errorMessage: alert.message)
            } else if !invalidateSilently {
                session.invalidate(errorMessage: "The tag could not be written. Nothing was written.")
            } else {
                session.invalidate()
            }
        }
        DispatchQueue.main.async {
            self.isWriting = false
            self.writeAlert = alert
            completion?(success)
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
