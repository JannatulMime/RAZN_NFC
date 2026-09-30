//
//  TesterModeManagerTests.swift
//  RAZN NFCTests
//

import XCTest

@testable import RAZN_NFC

final class TesterModeManagerTests: XCTestCase {

    private let defaultsKey = "razn.testerMode.isEnabled"

    private func makeSuiteName() -> String {
        "com.razn.testerMode.tests.\(UUID().uuidString)"
    }

    private func makeSUT(suiteName: String) -> (TesterModeManager, UserDefaults) {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("UserDefaults suite unavailable")
            fatalError()
        }
        return (TesterModeManager(userDefaults: defaults), defaults)
    }

    func testIsEnabledDefaultsToFalse() {
        let suite = makeSuiteName()
        let (sut, _) = makeSUT(suiteName: suite)

        XCTAssertFalse(sut.isEnabled)
    }

    func testSetEnabledPersistsValue() {
        let suite = makeSuiteName()
        let (sut, defaults) = makeSUT(suiteName: suite)

        sut.setEnabled(true)
        XCTAssertTrue(defaults.bool(forKey: defaultsKey))
        XCTAssertTrue(sut.isEnabled)

        sut.setEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: defaultsKey))
        XCTAssertFalse(sut.isEnabled)
    }

    func testToggleFlipsPersistedValue() {
        let suite = makeSuiteName()
        let (sut, defaults) = makeSUT(suiteName: suite)

        XCTAssertTrue(sut.toggle())
        XCTAssertTrue(defaults.bool(forKey: defaultsKey))

        XCTAssertFalse(sut.toggle())
        XCTAssertFalse(defaults.bool(forKey: defaultsKey))
    }

    func testRestoreOnLaunchDoesNotCrashWhenDisabled() {
        let suite = makeSuiteName()
        let (sut, _) = makeSUT(suiteName: suite)

        sut.restoreOnLaunch()
    }

    func testRestoreOnLaunchDoesNotCrashWhenEnabled() {
        let suite = makeSuiteName()
        let (sut, _) = makeSUT(suiteName: suite)

        sut.setEnabled(true)
        sut.restoreOnLaunch()
    }
}
