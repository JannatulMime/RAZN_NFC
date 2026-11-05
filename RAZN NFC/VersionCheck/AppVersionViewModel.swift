//
//  AppVersionViewModel.swift
//  RAZN NFC
//

import Foundation
import UIKit

enum AppVersionCheckState: Equatable {
    case updateRequired(message: String, appStoreURL: URL?)
    case allowed
}

@MainActor
final class AppVersionViewModel: ObservableObject {
    @Published private(set) var state: AppVersionCheckState = .allowed

    private let fetcher: AppVersionFetching
    private let installedVersionProvider: InstalledVersionProviding
    private let urlOpener: (URL) -> Void

    private var checkTask: Task<Void, Never>?

    init(
        fetcher: AppVersionFetching = AppVersionService(),
        installedVersionProvider: InstalledVersionProviding = BundleInstalledVersionProvider(),
        urlOpener: @escaping (URL) -> Void = { UIApplication.shared.open($0) }
    ) {
        self.fetcher = fetcher
        self.installedVersionProvider = installedVersionProvider
        self.urlOpener = urlOpener
    }

    func checkOnLaunch() {
        // Non-blocking: main UI stays up while the check runs in the background.
        performCheck()
    }

    /// Recheck when returning to foreground. Skips if a check is already in flight.
    func recheckIfNeededOnBecomeActive() {
        guard checkTask == nil else { return }
        performCheck()
    }

    func openAppStore() {
        let url: URL
        if case .updateRequired(_, let resolved) = state, let resolved {
            url = Self.appStoreOpenURL(from: resolved)
        } else {
            url = Self.appStoreOpenURL(from: Constants.getAppLink())
        }
        print("[AppVersion] Opening App Store: \(url.absoluteString)")
        urlOpener(url)
    }

    /// Prefer the App Store app (`itms-apps://`) over Safari for the listing URL.
    static func appStoreOpenURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let scheme = components.scheme?.lowercased()
        if scheme == "http" || scheme == "https" {
            components.scheme = "itms-apps"
            return components.url ?? url
        }
        return url
    }

    // MARK: - Private

    private func performCheck() {
        checkTask?.cancel()

        checkTask = Task { [weak self] in
            guard let self else { return }
            await self.runCheck()
        }
    }

    private func runCheck() async {
        defer { checkTask = nil }

        let previousState = state

        guard let installed = installedVersionProvider.shortVersionString?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !installed.isEmpty else {
            print("[AppVersion] CFBundleShortVersionString missing or empty — fail open")
            // Fail open so the main UI is not blocked by a bad local version string.
            if case .updateRequired = previousState { return }
            state = .allowed
            return
        }

        print("[AppVersion] CFBundleShortVersionString=\(installed)")

        do {
            let config = try await fetcher.fetchConfig()
            if Task.isCancelled { return }

            print("[AppVersion] minimumSupportedVersion=\(config.minimumSupportedVersion) forceUpdateEnabled=\(config.forceUpdateEnabled)")

            let requiresUpdate = try config.requiresForceUpdate(installedVersion: installed)
            if Task.isCancelled { return }

            print("[AppVersion] requiresForceUpdate=\(requiresUpdate)")

            if requiresUpdate {
                state = .updateRequired(
                    message: config.updateMessage,
                    appStoreURL: config.resolvedAppStoreURL
                )
            } else {
                state = .allowed
            }
        } catch {
            print("[AppVersion] check failed (fail open): \(error)")
            if Task.isCancelled { return }
            // Fail open: keep the app usable unless a prior check already required an update.
            if case .updateRequired = previousState { return }
            state = .allowed
        }
    }
}
