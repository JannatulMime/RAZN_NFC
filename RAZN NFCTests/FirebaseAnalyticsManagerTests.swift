//
//  FirebaseAnalyticsManagerTests.swift
//  RAZN NFCTests
//

import XCTest

@testable import RAZN_NFC

final class FirebaseAnalyticsManagerTests: XCTestCase {

    private func makeSuiteName() -> String {
        "com.razn.analytics.tests.\(UUID().uuidString)"
    }

    private func makeSUT(
        suiteName: String,
        testerModeEnabled: Bool = false
    ) -> FirebaseAnalyticsManager {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("UserDefaults suite unavailable")
            fatalError()
        }

        if testerModeEnabled {
            defaults.set(true, forKey: "razn.testerMode.isEnabled")
        }

        let testerMode = TesterModeManager(userDefaults: defaults)
        return FirebaseAnalyticsManager(testerMode: testerMode)
    }

    func testResolvedEventNameWithoutTesterMode() {
        let suite = makeSuiteName()
        let sut = makeSUT(suiteName: suite)

        XCTAssertEqual(sut.resolvedEventName(for: .appOpened), "app_opened")
        XCTAssertEqual(sut.resolvedEventName(for: .successfulNFCWrite), "successful_nfc_write")
        XCTAssertEqual(
            sut.resolvedEventName(for: .selectedQuickButtonCategory(category: "Social")),
            "selected_quick_button_category"
        )
        XCTAssertEqual(sut.resolvedEventName(for: .reviewPopupShown), "review_popup_shown")
    }

    func testResolvedEventNameWithTesterMode() {
        let suite = makeSuiteName()
        let sut = makeSUT(suiteName: suite, testerModeEnabled: true)

        XCTAssertEqual(sut.resolvedEventName(for: .appOpened), "tester_app_opened")
        XCTAssertEqual(sut.resolvedEventName(for: .successfulNFCWrite), "tester_successful_nfc_write")
        XCTAssertEqual(
            sut.resolvedEventName(for: .selectedQuickButtonCategory(category: "Social")),
            "tester_selected_quick_button_category"
        )
        XCTAssertEqual(sut.resolvedEventName(for: .reviewPopupShown), "tester_review_popup_shown")
    }
}
