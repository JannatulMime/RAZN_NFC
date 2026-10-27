//
//  AppVersionViewModel.swift
//  RAZN NFC
//

import Foundation
import UIKit

enum AppVersionCheckState: Equatable {
    case loading
    case updateRequired(message: String, appStoreURL: URL?)
    case allowed
    case failed(message: String)
}

@MainActor
final class AppVersionViewModel: ObservableObject {
    @Published private(set) var state: AppVersionCheckState = .loading

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
        performCheck(showLoading: true)
    }

    func retry() {
        performCheck(showLoading: true)
    }

    /// Recheck when returning to foreground. Skips if a check is already in flight.
    /// Keeps the current UI visible (no full-screen loading flash) while refreshing.
    func recheckIfNeededOnBecomeActive() {
        guard checkTask == nil else { return }
        performCheck(showLoading: false)
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

    private func performCheck(showLoading: Bool) {
        checkTask?.cancel()
        if showLoading {
            state = .loading
        }

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
            print("[AppVersion] CFBundleShortVersionString missing or empty")
            state = .failed(message: Self.failureMessage)
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
            print("[AppVersion] check failed: \(error)")
            if Task.isCancelled { return }
            // Initial / blocking checks fail closed. After access was granted, keep the
            // session usable on transient network errors until the next successful fetch.
            if case .allowed = previousState {
                return
            }
            state = .failed(message: Self.failureMessage)
        }
    }

    private static let failureMessage =
        "We couldn’t verify that this version of RAZN is supported. Check your connection and try again."
}
