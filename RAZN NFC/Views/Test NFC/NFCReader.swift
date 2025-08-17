////
////  NFCReader.swift
////  RAZN NFC
////
////  Created by Habibur_Periscope on 10/8/25.
////
//
//import CoreNFC
//
//
//class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
//   
//    @Published var message = "Waiting for NFC tag..."
//    var session: NFCNDEFReaderSession?
//    var onScanComplete: ((String) -> Void)?
//    var onWriteComplete: ((Bool) -> Void)?
//    var isWriting = false
//    var textToWrite: String?
//    
//    @Published var alertMessage : String = ""
//    @Published var showAlert : Bool = false
//
//    
//    func scan(completion: @escaping (String) -> Void) {
//        onScanComplete = completion
//        isWriting = false
//        startSession()
//    }
//
//    func write(_ text: String, completion: @escaping (Bool) -> Void) {
//        onWriteComplete = completion
//        textToWrite = text
//        isWriting = true
//        startSession()
//    }
//
//    private func startSession() {
//        guard NFCNDEFReaderSession.readingAvailable else {
//            NSLog("NFC is not available on this device")
//            alertMessage = "NFC is not available on this device"
//            showAlert = true
//            return
//        }
//
//        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
//        session?.alertMessage = isWriting ? "Hold your iPhone near an NFC tag to write." : "Hold your iPhone near an NFC tag to read."
//        session?.begin()
//    }
//
//    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
//        guard !isWriting else { return }
//
//        for message in messages {
//            for record in message.records {
//                if record.typeNameFormat == .nfcWellKnown {
//                    if let text = record.wellKnownTypeTextPayload().0 {
//                        DispatchQueue.main.async {
//                            self.message = text
//                            self.onScanComplete?(text)
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
//        if isWriting {
//            handleWriting(session: session, tags: tags)
//        } else {
//            handleReading(session: session, tags: tags)
//        }
//    }
//
//    private func handleReading(session: NFCNDEFReaderSession, tags: [NFCNDEFTag]) {
//        if tags.count > 1 {
//            session.alertMessage = "More than 1 tag detected. Please try again with only one tag."
//            session.invalidate()
//            return
//        }
//
//        let tag = tags.first!
//        session.connect(to: tag) { error in
//            if let error = error {
//                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
//                return
//            }
//
//
//            tag.queryNDEFStatus { status, _, error in
//                if let error = error {
//                    session.invalidate(errorMessage: "Failed to query tag: \(error.localizedDescription)")
//                    return
//                }
//
//                switch status {
//                case .notSupported:
//                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
//                case .readOnly, .readWrite:
//                    
//                    tag.readNDEF { message, error in
//                        if let error = error {
//                            session.invalidate(errorMessage: "Read error: \(error.localizedDescription)")
//                        } else if let message = message {
//                            self.processMessage(message)
//                            session.alertMessage = "Tag read successfully!"
//                            session.invalidate()
//                        } else {
//                            session.invalidate(errorMessage: "No NDEF message found on tag")
//                        }
//                    }
//                @unknown default:
//                    session.invalidate(errorMessage: "Unknown tag status")
//                }
//            }
//        }
//    }
//
//    private func processMessage(_ message: NFCNDEFMessage) {
//        for record in message.records {
//            switch record.typeNameFormat {
//            case .nfcWellKnown:
//                if let text = record.wellKnownTypeTextPayload().0 {
//                    DispatchQueue.main.async {
//                        self.message = text
//                        self.onScanComplete?(text)
//                    }
//                } else if let url = record.wellKnownTypeURIPayload() {
//                    DispatchQueue.main.async {
//                        self.message = url.absoluteString
//                        self.onScanComplete?(url.absoluteString)
//                    }
//                }
//            case .absoluteURI:
//                if let text = String(data: record.payload, encoding: .utf8) {
//                    DispatchQueue.main.async {
//                        self.message = text
//                        self.onScanComplete?(text)
//                    }
//                }
//            default:
//                break
//            }
//        }
//    }
//
//    private func handleWriting(session: NFCNDEFReaderSession, tags: [NFCNDEFTag]) {
//        guard let tag = tags.first else {
//            session.invalidate(errorMessage: "No tag detected")
//            return
//        }
//
//        session.connect(to: tag) { error in
//            if let error = error {
//                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
//                return
//            }
//
//            tag.queryNDEFStatus { status, _, error in
//                guard error == nil else {
//                    session.invalidate(errorMessage: "Failed to query tag")
//                    return
//                }
//
//                switch status {
//                case .notSupported:
//                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
//                case .readOnly:
//                    session.invalidate(errorMessage: "Tag is read-only")
//                case .readWrite:
//                    guard let textToWrite = self.textToWrite else {
//                        session.invalidate(errorMessage: "No text to write")
//                        return
//                    }
//
//                    let payload = NFCNDEFPayload.wellKnownTypeTextPayload(string: textToWrite, locale: Locale(identifier: "en"))!
//                    let message = NFCNDEFMessage(records: [payload])
//
//                    tag.writeNDEF(message) { error in
//                        if let error = error {
//                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
//                        } else {
//                            session.alertMessage = "Write successful!"
//                            session.invalidate()
//                        }
//
//                        DispatchQueue.main.async {
//                            self.onWriteComplete?(error == nil)
//                        }
//                    }
//                @unknown default:
//                    session.invalidate(errorMessage: "Unknown tag status")
//                }
//            }
//        }
//    }
//
//    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
//        if let readerError = error as? NFCReaderError {
//            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
//                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
//                NSLog("Session invalidated with error: \(error.localizedDescription)")
//            }
//        }
//        self.session = nil
//    }
//}

import CoreNFC

class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {

    @Published var message = "Waiting for NFC tag..."
    var session: NFCNDEFReaderSession?
    var onScanComplete: ((String) -> Void)?
    var onWriteComplete: ((Bool) -> Void)?
    var isWriting = false
    var textToWrite: String?

    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    func scan(completion: @escaping (String) -> Void) {
        onScanComplete = completion
        isWriting = false
        startSession()
    }

    /// If `text` looks like a URL, we’ll write a URL record. Otherwise we write a Text record.
    func write(_ text: String, completion: @escaping (Bool) -> Void) {
        onWriteComplete = completion
        textToWrite = text
        isWriting = true
        startSession()
    }

    /// Convenience: explicitly write a URL (recommended for your use case)
    func writeURL(_ urlString: String, completion: @escaping (Bool) -> Void) {
        onWriteComplete = completion
        textToWrite = urlString
        isWriting = true
        startSession()
    }

    private func startSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            NSLog("NFC is not available on this device")
            alertMessage = "NFC is not available on this device"
            showAlert = true
            return
        }

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = isWriting ? "Hold your iPhone near an NFC tag to write." : "Hold your iPhone near an NFC tag to read."
        session?.begin()
    }

    // MARK: - Reading

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard !isWriting else { return }
        for message in messages { processMessage(message) }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if isWriting {
            handleWriting(session: session, tags: tags)
        } else {
            handleReading(session: session, tags: tags)
        }
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

    // MARK: - Writing

    private func handleWriting(session: NFCNDEFReaderSession, tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { status, _, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Failed to query tag")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")
                case .readWrite:
                    guard let textToWrite = self.textToWrite else {
                        session.invalidate(errorMessage: "No text to write")
                        return
                    }

                    // Decide payload: URL vs Text
                    let message: NFCNDEFMessage
                    if let urlPayload = self.makeURIPayload(from: textToWrite) {
                        message = NFCNDEFMessage(records: [urlPayload])
                    } else {
                        let textPayload = NFCNDEFPayload.wellKnownTypeTextPayload(string: textToWrite, locale: Locale(identifier: "en"))!
                        message = NFCNDEFMessage(records: [textPayload])
                    }

                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Write successful!"
                            session.invalidate()
                        }

                        DispatchQueue.main.async {
                            self.onWriteComplete?(error == nil)
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
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

    // MARK: - Session end

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead &&
               readerError.code != .readerSessionInvalidationErrorUserCanceled {
                NSLog("Session invalidated with error: \(error.localizedDescription)")
            }
        }
        self.session = nil
    }
}

