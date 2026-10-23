//
//  AuthNFCError.swift
//  RAZN NFC
//

import CoreNFC
import Foundation

enum AuthNFCError: Error, Equatable {
    case invalidPasswordFormat
    case passwordConfirmationMismatch
    case emptyContent
    case contentTooLarge(maxUTF8Bytes: Int)
    case noTagDetected
    case multipleTagsDetected
    case unsupportedTagType(details: String)
    case versionIdentificationFailed(details: String)
    case nfcUnavailable
    case authenticationRejected
    case authenticationRequired
    case packMismatch
    case tagNotConfiguredForProtection
    case writeProtectionOrLock
    case configurationPermanentlyLocked
    case existingProtectionRequiresConfirmation
    case pageOutOfRange(details: String)
    case writeFailure(details: String)
    case readFailure(details: String)
    case noReadableContent
    case partialConfigurationFailure(details: String)
    case partialWriteFailure(details: String)
    case sessionTimeoutOrInvalidation(details: String)
    case userCancelled
    case tagRemoved
    case unexpectedResponse(details: String)
    case sessionAlreadyActive
    case connectionFailed(details: String)
    case operationInProgress

    var title: String {
        switch self {
        case .invalidPasswordFormat:
            return "Invalid Password Format"
        case .passwordConfirmationMismatch:
            return "Passwords Do Not Match"
        case .emptyContent:
            return "Content Required"
        case .contentTooLarge:
            return "Content Too Large"
        case .noTagDetected:
            return "No Tag Detected"
        case .multipleTagsDetected:
            return "Multiple Tags Detected"
        case .unsupportedTagType:
            return "Unsupported Tag"
        case .versionIdentificationFailed:
            return "Tag Identification Failed"
        case .nfcUnavailable:
            return "NFC Unavailable"
        case .authenticationRejected:
            return "Authentication Failed"
        case .authenticationRequired:
            return "Authentication Required"
        case .packMismatch:
            return "PACK Mismatch"
        case .tagNotConfiguredForProtection:
            return "Tag Not Password-Protected"
        case .writeProtectionOrLock:
            return "Write Restricted"
        case .configurationPermanentlyLocked:
            return "Configuration Locked"
        case .existingProtectionRequiresConfirmation:
            return "Existing Protection Detected"
        case .pageOutOfRange:
            return "Page Out Of Range"
        case .writeFailure:
            return "Write Failed"
        case .readFailure:
            return "Read Failed"
        case .noReadableContent:
            return "No Readable Content"
        case .partialConfigurationFailure:
            return "Partial Configuration Failure"
        case .partialWriteFailure:
            return "Partial Write Failure"
        case .sessionTimeoutOrInvalidation:
            return "NFC Session Ended"
        case .userCancelled:
            return "Cancelled"
        case .tagRemoved:
            return "Tag Removed"
        case .unexpectedResponse:
            return "Unexpected Tag Response"
        case .sessionAlreadyActive:
            return "NFC Busy"
        case .connectionFailed:
            return "Connection Failed"
        case .operationInProgress:
            return "Operation In Progress"
        }
    }

    var explanation: String {
        switch self {
        case .invalidPasswordFormat:
            return "The password must be exactly eight hexadecimal characters (0–9, A–F), representing four bytes. Nothing is padded or truncated."
        case .passwordConfirmationMismatch:
            return "The password and confirmation fields do not match."
        case .emptyContent:
            return "Enter the text you want to write to the tag."
        case .contentTooLarge(let maxUTF8Bytes):
            return "The content exceeds this tag’s usable capacity (\(maxUTF8Bytes) UTF-8 bytes after the length prefix). Nothing was truncated."
        case .noTagDetected:
            return "No NFC tag was detected during the session."
        case .multipleTagsDetected:
            return "More than one tag was present. Use a single tag."
        case .unsupportedTagType(let details):
            return "This demo supports genuine NTAG213, NTAG215, and NTAG216 tags identified via GET_VERSION. \(details)"
        case .versionIdentificationFailed(let details):
            return "The tag could not be identified with GET_VERSION. Configuration pages were not modified. \(details)"
        case .nfcUnavailable:
            return "NFC is not available or not allowed on this device."
        case .authenticationRejected:
            return "The tag rejected the password. Wrong password, or the tag is not configured as expected."
        case .authenticationRequired:
            return "The relevant memory is password-protected. This operation cannot continue without a successful PWD_AUTH, and it will not bypass tag protection."
        case .packMismatch:
            return "Authentication returned a PACK that does not match the expected acknowledgement for this password."
        case .tagNotConfiguredForProtection:
            return "The tag’s AUTH0 setting does not indicate the protection mode this demo expects."
        case .writeProtectionOrLock:
            return "The tag refused a write due to password protection or lock bits. Protected pages were not modified without authentication."
        case .noReadableContent:
            return "No decodable demo payload or NDEF text/URI was found in accessible user memory."
        case .configurationPermanentlyLocked:
            return "CFGLCK is set. Configuration pages are permanently locked against normal writes (except PWD/PACK). This demo will not attempt recovery."
        case .existingProtectionRequiresConfirmation:
            return "Password protection appears to be already enabled. Reconfiguration can overwrite the existing password and settings."
        case .pageOutOfRange(let details):
            return "A page address is outside the detected tag’s user memory. \(details)"
        case .writeFailure(let details):
            return "Writing to the tag failed. \(details)"
        case .readFailure(let details):
            return "Reading from the tag failed. \(details)"
        case .partialConfigurationFailure(let details):
            return "Configuration may be incomplete. The tag might need manual recovery with a known password or a fresh test tag. \(details)"
        case .partialWriteFailure(let details):
            return "Some pages may have been written before the failure. \(details)"
        case .sessionTimeoutOrInvalidation(let details):
            return "The NFC session ended unexpectedly. \(details)"
        case .userCancelled:
            return "You cancelled the NFC session."
        case .tagRemoved:
            return "The tag was removed before the operation finished."
        case .unexpectedResponse(let details):
            return "The tag returned an unexpected or malformed response. \(details)"
        case .sessionAlreadyActive:
            return "Another NFC session is already active. Wait for it to finish."
        case .connectionFailed(let details):
            return "Could not connect to the tag. \(details)"
        case .operationInProgress:
            return "An NFC operation is already running."
        }
    }

    var suggestedNextStep: String {
        switch self {
        case .invalidPasswordFormat:
            return "Enter exactly 8 hex characters, for example AABBCCDD."
        case .passwordConfirmationMismatch:
            return "Re-enter the same password in both fields."
        case .emptyContent:
            return "Type the content, then try again."
        case .contentTooLarge(let maxUTF8Bytes):
            return "Shorten the text to at most \(maxUTF8Bytes) UTF-8 bytes for this tag, then retry."
        case .noTagDetected:
            return "Hold one NTAG213, NTAG215, or NTAG216 steady near the top of the iPhone and retry."
        case .multipleTagsDetected:
            return "Remove extra tags and scan again."
        case .unsupportedTagType:
            return "Use a genuine NTAG213, NTAG215, or NTAG216 spare tag for this demo."
        case .versionIdentificationFailed:
            return "Retry with a genuine NTAG21x. If GET_VERSION keeps failing, the tag is not supported by this demo."
        case .nfcUnavailable:
            return "Use an iPhone with NFC, enable NFC if needed, and ensure the app has NFC permission."
        case .authenticationRejected:
            return "Confirm the password matches registration, then hold the tag steady and retry."
        case .authenticationRequired:
            return "Use Authenticate & Write with the correct password for protected writes, or Read Content with a password if the tag uses read protection."
        case .packMismatch:
            return "Use the same password encoding as registration. If the tag was configured elsewhere, use a fresh test tag."
        case .tagNotConfiguredForProtection:
            return "Register the tag password in this demo first, or use a tag configured the same way."
        case .writeProtectionOrLock:
            return "Authenticate with the correct password, or use an unlocked spare tag."
        case .noReadableContent:
            return "Write content with this demo first, or scan a tag that already has accessible NDEF/demo data."
        case .configurationPermanentlyLocked:
            return "Use a fresh NTAG213/215/216 that has not had CFGLCK set."
        case .existingProtectionRequiresConfirmation:
            return "Confirm only if you know the current password and accept overwriting configuration."
        case .pageOutOfRange:
            return "Use shorter content, or a larger tag (NTAG215/216)."
        case .writeFailure, .partialWriteFailure:
            return "Keep the tag still and retry. If it keeps failing, try a fresh tag."
        case .readFailure:
            return "Hold the tag steady and try reading again."
        case .partialConfigurationFailure:
            return "Do not assume success. Retry only if you know the password, or switch to a fresh test tag."
        case .sessionTimeoutOrInvalidation, .tagRemoved:
            return "Start again and keep the tag in place until the sheet dismisses."
        case .userCancelled:
            return "Tap the action again when you are ready."
        case .unexpectedResponse:
            return "Retry with a known NTAG213/215/216. If it persists, the tag may be incompatible."
        case .sessionAlreadyActive, .operationInProgress:
            return "Wait for the current NFC sheet to finish, then try again."
        case .connectionFailed:
            return "Reposition the tag and retry."
        }
    }

    var technicalDetails: String? {
        switch self {
        case .unsupportedTagType(let details),
             .versionIdentificationFailed(let details),
             .pageOutOfRange(let details),
             .writeFailure(let details),
             .readFailure(let details),
             .partialConfigurationFailure(let details),
             .partialWriteFailure(let details),
             .sessionTimeoutOrInvalidation(let details),
             .unexpectedResponse(let details),
             .connectionFailed(let details):
            return details.isEmpty ? nil : details
        case .contentTooLarge(let maxUTF8Bytes):
            return "Demo stores a 2-byte length prefix plus UTF-8 (not NDEF). Max UTF-8 payload for this tag: \(maxUTF8Bytes)."
        case .invalidPasswordFormat:
            return "Expected \(AuthNFCConstants.passwordHexLength) hex characters → 4 bytes for PWD_AUTH (0x1B)."
        case .packMismatch:
            return "PWD_AUTH must return the 2-byte PACK written at the variant’s PACK page. This demo derives PACK as SHA256(pwd)[0..<2]."
        case .configurationPermanentlyLocked:
            return "ACCESS.CFGLCK (CFG1 bit 6) permanently locks CFG0/CFG1 after power cycle."
        case .tagNotConfiguredForProtection:
            return "AUTH0 (CFG0 byte 3) is 0xFF when protection is disabled. This demo sets AUTH0 to 0x04 for write protection of user memory."
        default:
            return nil
        }
    }

    /// Maps Core NFC / session errors without exposing secrets.
    static func fromNFCReaderError(_ error: Error) -> AuthNFCError {
        if let readerError = error as? NFCReaderError {
            switch readerError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                return .userCancelled
            case .readerTransceiveErrorTagConnectionLost,
                 .readerTransceiveErrorTagResponseError:
                return .tagRemoved
            case .readerSessionInvalidationErrorSessionTimeout:
                return .sessionTimeoutOrInvalidation(details: readerError.localizedDescription)
            default:
                return .sessionTimeoutOrInvalidation(details: readerError.localizedDescription)
            }
        }
        return .sessionTimeoutOrInvalidation(details: error.localizedDescription)
    }
}
