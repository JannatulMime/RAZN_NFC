//
//  AppVersionViewModelTests.swift
//  RAZN NFCTests
//

import XCTest
@testable import RAZN_NFC

@MainActor
final class AppVersionViewModelTests: XCTestCase {
    private final class MockFetcher: AppVersionFetching, @unchecked Sendable {
        var result: Result<AppVersionConfig, Error>
        var fetchCount = 0

        init(result: Result<AppVersionConfig, Error>) {
            self.result = result
        }

        func fetchConfig() async throws -> AppVersionConfig {
            fetchCount += 1
            switch result {
            case .success(let config):
                return config
            case .failure(let error):
                throw error
            }
        }
    }

    private struct MockInstalledVersion: InstalledVersionProviding {
        let shortVersionString: String?
    }

    private func makeConfig(
        minimum: String = "5.0",
        force: Bool = true,
        message: String = "Please update RAZN.",
        storeURL: String = "https://apps.apple.com/app/id6749680572"
    ) -> AppVersionConfig {
        AppVersionConfig(
            minimumSupportedVersion: minimum,
            forceUpdateEnabled: force,
            updateMessage: message,
            appStoreURL: storeURL
        )
    }

    private func waitForState(
        _ viewModel: AppVersionViewModel,
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        matching: (AppVersionCheckState) -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if matching(viewModel.state) { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for expected state. Last state: \(viewModel.state)", file: file, line: line)
    }

    // MARK: - Force update decisions

    func testInstalledBelowMinimumRequiresUpdate() async {
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "5.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "4.9")
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .updateRequired = $0 { return true }
            return false
        }

        guard case .updateRequired(let message, let url) = sut.state else {
            return XCTFail("Expected updateRequired")
        }
        XCTAssertEqual(message, "Please update RAZN.")
        XCTAssertEqual(url?.absoluteString, "https://apps.apple.com/app/id6749680572")
    }

    func testInstalledEqualToMinimumAllowsAccess() async {
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "5.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) { $0 == .allowed }
        XCTAssertEqual(sut.state, .allowed)
    }

    func testInstalledAboveMinimumAllowsAccess() async {
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "5.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.1")
        )

        sut.checkOnLaunch()
        await waitForState(sut) { $0 == .allowed }
        XCTAssertEqual(sut.state, .allowed)
    }

    func testForceUpdateDisabledAllowsEvenWhenBelowMinimum() async {
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "9.0", force: false)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) { $0 == .allowed }
        XCTAssertEqual(sut.state, .allowed)
    }

    func testNumericComparisonOneTenVersusOneTwo() async {
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "1.10.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "1.2.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .updateRequired = $0 { return true }
            return false
        }
    }

    // MARK: - Config / network failures

    func testMissingInstalledVersionFailsClosed() async {
        let fetcher = MockFetcher(result: .success(makeConfig()))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: nil)
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .failed = $0 { return true }
            return false
        }
        XCTAssertEqual(fetcher.fetchCount, 0)
    }

    func testInvalidRemoteConfigurationFailsClosed() async {
        let fetcher = MockFetcher(result: .failure(
            AppVersionCheckError.invalidConfiguration(.invalidMinimumSupportedVersion)
        ))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .failed = $0 { return true }
            return false
        }
    }

    func testNetworkFailureFailsClosedOnInitialCheck() async {
        let fetcher = MockFetcher(result: .failure(AppVersionCheckError.networkUnavailable))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .failed = $0 { return true }
            return false
        }
    }

    func testRetryAfterFailureSucceeds() async {
        let fetcher = MockFetcher(result: .failure(AppVersionCheckError.networkUnavailable))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .failed = $0 { return true }
            return false
        }

        fetcher.result = .success(makeConfig(force: false))
        sut.retry()
        await waitForState(sut) { $0 == .allowed }
        XCTAssertEqual(sut.state, .allowed)
        XCTAssertEqual(fetcher.fetchCount, 2)
    }

    func testAllowedStateSurvivesTransientForegroundNetworkFailure() async {
        let fetcher = MockFetcher(result: .success(makeConfig(force: false)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) { $0 == .allowed }

        fetcher.result = .failure(AppVersionCheckError.networkUnavailable)
        sut.recheckIfNeededOnBecomeActive()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(sut.state, .allowed)
    }

    // MARK: - App Store URL

    func testFallsBackToConstantsWhenRemoteURLInvalid() async {
        let fetcher = MockFetcher(result: .success(makeConfig(storeURL: "not-a-url")))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "1.0"),
            urlOpener: { _ in }
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .updateRequired = $0 { return true }
            return false
        }

        guard case .updateRequired(_, let url) = sut.state else {
            return XCTFail("Expected updateRequired")
        }
        XCTAssertEqual(url, Constants.getAppLink())
    }

    func testOpenAppStoreInvokesOpenerWithResolvedURL() async {
        var opened: URL?
        let expected = URL(string: "https://apps.apple.com/app/id6749680572")!
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "9.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0"),
            urlOpener: { opened = $0 }
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .updateRequired = $0 { return true }
            return false
        }

        sut.openAppStore()
        XCTAssertEqual(opened, expected)
    }

    func testReturningFromStoreWithoutUpdateKeepsBlocked() async {
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "9.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: MockInstalledVersion(shortVersionString: "5.0")
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .updateRequired = $0 { return true }
            return false
        }
        XCTAssertEqual(fetcher.fetchCount, 1)

        sut.recheckIfNeededOnBecomeActive()
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline, fetcher.fetchCount < 2 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertGreaterThanOrEqual(fetcher.fetchCount, 2)
        guard case .updateRequired = sut.state else {
            return XCTFail("Expected to remain updateRequired after recheck without updating")
        }
    }

    func testReturningFromStoreAfterUpdateAllowsAccess() async {
        let installed = MockInstalledVersionBox(version: "5.0")
        let fetcher = MockFetcher(result: .success(makeConfig(minimum: "9.0", force: true)))
        let sut = AppVersionViewModel(
            fetcher: fetcher,
            installedVersionProvider: installed
        )

        sut.checkOnLaunch()
        await waitForState(sut) {
            if case .updateRequired = $0 { return true }
            return false
        }

        installed.version = "9.0"
        fetcher.result = .success(makeConfig(minimum: "9.0", force: true))
        sut.recheckIfNeededOnBecomeActive()
        await waitForState(sut) { $0 == .allowed }
        XCTAssertEqual(sut.state, .allowed)
    }

    // MARK: - Config decoding helpers

    func testConfigParsingFromFirestoreData() throws {
        let config = try AppVersionConfig(firestoreData: [
            "minimumSupportedVersion": "5.0",
            "forceUpdateEnabled": true,
            "updateMessage": "Update now",
            "appStoreURL": "https://apps.apple.com/app/id6749680572"
        ])
        XCTAssertEqual(config.minimumSupportedVersion, "5.0")
        XCTAssertTrue(config.forceUpdateEnabled)
        XCTAssertTrue(try config.requiresForceUpdate(installedVersion: "4.0"))
        XCTAssertFalse(try config.requiresForceUpdate(installedVersion: "5.0"))
    }

    func testValidHTTPURLHelper() {
        XCTAssertNotNil(AppVersionConfig.validHTTPURL(from: "https://apps.apple.com/app/id1"))
        XCTAssertNotNil(AppVersionConfig.validHTTPURL(from: "http://example.com"))
        XCTAssertNil(AppVersionConfig.validHTTPURL(from: "ftp://example.com"))
        XCTAssertNil(AppVersionConfig.validHTTPURL(from: ""))
        XCTAssertNil(AppVersionConfig.validHTTPURL(from: "not a url"))
    }

    func testAppStoreOpenURLUsesItmsAppsScheme() {
        let https = URL(string: "https://apps.apple.com/app/id6749680572")!
        let opened = AppVersionViewModel.appStoreOpenURL(from: https)
        XCTAssertEqual(opened.scheme, "itms-apps")
        XCTAssertEqual(opened.host, "apps.apple.com")
        XCTAssertEqual(opened.path, "/app/id6749680572")
    }
}

private final class MockInstalledVersionBox: InstalledVersionProviding, @unchecked Sendable {
    var version: String?
    var shortVersionString: String? { version }

    init(version: String?) {
        self.version = version
    }
}
