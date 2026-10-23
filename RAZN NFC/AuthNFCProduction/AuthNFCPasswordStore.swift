//
//  AuthNFCPasswordStore.swift
//  RAZN NFC
//
//  Local storage for the production NFC write password.
//  NOTE: UserDefaults is not encrypted. Prefer Keychain if stronger confidentiality is required.
//

import Foundation

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

    /// Returns the stored uppercase hex password, or `nil` if none / malformed.
    func retrieve() -> String? {
        guard let value = defaults.string(forKey: Self.defaultsKey) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (try? AuthNFCPasswordService.passwordBytes(fromHex: trimmed)) != nil else {
            return nil
        }
        return trimmed.uppercased()
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
