//
//  AppVersionConfig.swift
//  RAZN NFC
//

import Foundation

struct AppVersionConfig: Equatable, Sendable {
    let minimumSupportedVersion: String
    let forceUpdateEnabled: Bool
    let updateMessage: String
    let appStoreURL: String

    enum ValidationError: Error, Equatable {
        case missingMinimumSupportedVersion
        case invalidMinimumSupportedVersion
        case emptyUpdateMessage
    }

    init(
        minimumSupportedVersion: String,
        forceUpdateEnabled: Bool,
        updateMessage: String,
        appStoreURL: String
    ) {
        self.minimumSupportedVersion = minimumSupportedVersion
        self.forceUpdateEnabled = forceUpdateEnabled
        self.updateMessage = updateMessage
        self.appStoreURL = appStoreURL
    }

    init(firestoreData: [String: Any]) throws {
        guard let minimum = firestoreData["minimumSupportedVersion"] as? String,
              !minimum.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingMinimumSupportedVersion
        }
        guard SemanticVersion(string: minimum) != nil else {
            throw ValidationError.invalidMinimumSupportedVersion
        }

        let message = (firestoreData["updateMessage"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !message.isEmpty else {
            throw ValidationError.emptyUpdateMessage
        }

        let forceEnabled = firestoreData["forceUpdateEnabled"] as? Bool ?? false
        let storeURL = (firestoreData["appStoreURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        self.init(
            minimumSupportedVersion: minimum.trimmingCharacters(in: .whitespacesAndNewlines),
            forceUpdateEnabled: forceEnabled,
            updateMessage: message,
            appStoreURL: storeURL
        )
    }

    /// Prefer a valid remote App Store URL; otherwise fall back to the in-app constant.
    var resolvedAppStoreURL: URL? {
        if let remote = Self.validHTTPURL(from: appStoreURL) {
            return remote
        }
        return Self.validHTTPURL(from: Constants.getAppLink().absoluteString)
    }

    static func validHTTPURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    /// Returns whether a mandatory update is required for the given installed version string.
    func requiresForceUpdate(installedVersion: String) throws -> Bool {
        guard let installed = SemanticVersion(string: installedVersion) else {
            throw AppVersionCheckError.invalidInstalledVersion
        }
        guard let minimum = SemanticVersion(string: minimumSupportedVersion) else {
            throw ValidationError.invalidMinimumSupportedVersion
        }
        guard forceUpdateEnabled else { return false }
        return installed < minimum
    }
}

enum AppVersionCheckError: Error, Equatable {
    case documentMissing
    case invalidInstalledVersion
    case invalidConfiguration(AppVersionConfig.ValidationError)
    case networkUnavailable
}
