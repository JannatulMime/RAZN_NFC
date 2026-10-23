//
//  AuthNFCPasswordStore.swift
//  RAZN NFC
//
//  Local storage for the production NFC write password.
//  NOTE: UserDefaults is not encrypted. Prefer Keychain if stronger confidentiality is required.
//

import Foundation

enum AuthNFCStoredPasswordLookup: Equatable {
    case missing
    case invalid
    /// Uppercase 8-character hex. Never log this value.
    case valid(hex: String)
}

/// Persists a validated 8-hex-character NTAG21x password for production write authentication.
struct AuthNFCPasswordStore {
    static let defaultsKey = "authNFCStoredPassword"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether a validated password is currently stored.
    var hasPassword: Bool {
        retrieve() != nil
    }

    /// Distinguishes a missing key from a stored value that is not 8 hex characters.
    func lookup() -> AuthNFCStoredPasswordLookup {
        guard let value = defaults.string(forKey: Self.defaultsKey) else { return .missing }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .missing }
        guard (try? AuthNFCPasswordService.passwordBytes(fromHex: trimmed)) != nil else {
            return .invalid
        }
        return .valid(hex: trimmed.uppercased())
    }

    /// Returns the stored uppercase hex password, or `nil` if none / malformed.
    func retrieve() -> String? {
        guard case .valid(let hex) = lookup() else { return nil }
        return hex
    }

    /// Validates and stores the password as uppercase hex. Rejects malformed input.
    func save(hexPassword: String) throws {
        let bytes = try AuthNFCPasswordService.passwordBytes(fromHex: hexPassword)
        let normalized = bytes.map { String(format: "%02X", $0) }.joined()
        defaults.set(normalized, forKey: Self.defaultsKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
