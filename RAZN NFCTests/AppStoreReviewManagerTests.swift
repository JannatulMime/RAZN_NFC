//
//  AppStoreReviewManagerTests.swift
//  RAZN NFCTests
//

import XCTest

@testable import RAZN_NFC

@MainActor
final class AppStoreReviewManagerTests: XCTestCase {
    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeSuiteName() -> String {
        "com.razn.review.tests.\(UUID().uuidString)"
    }

    private func makeSUT(
        suiteName: String,
        clock: Clock,
        seed: ((UserDefaults) -> Void)? = nil
    ) -> (AppStoreReviewManager, UserDefaults) {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("UserDefaults suite unavailable")
            fatalError()
        }
        seed?(defaults)
        let sut = AppStoreReviewManager(userDefaults: defaults) { clock.now }
        return (sut, defaults)
    }

    private func promptShownCount(_ defaults: UserDefaults) -> Int {
        defaults.integer(forKey: "razn.review.promptShownCount")
    }

    // MARK: - NFC Write Trigger Tests

    func testShowsPromptAfterThresholdNFCWrites() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock)
        sut.nfcWriteThreshold = 2
        sut.daysBetweenPrompts = 2

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 0)

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)
        XCTAssertNotNil(defaults.object(forKey: "razn.review.lastPromptDate") as? Date)
    }

    func testDoesNotShowPromptBeforeThreshold() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock)
        sut.nfcWriteThreshold = 2

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 0)
    }

    func testShowsPromptAgainAfterAnotherThresholdWrites() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock)
        sut.nfcWriteThreshold = 2
        sut.daysBetweenPrompts = 2

        sut.recordNFCWrite()
        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)

        clock.now = Calendar.current.date(byAdding: .day, value: 3, to: clock.now)!

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 2)
    }

    func testDoesNotShowIfAlreadyReviewed() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock, seed: { defaults in
            defaults.set(true, forKey: "razn.review.hasReviewed")
        })
        sut.nfcWriteThreshold = 2

        sut.recordNFCWrite()
        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 0)
    }

    // MARK: - Date Cadence Tests

    func testDoesNotShowTwiceOnSameDay() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock)
        sut.nfcWriteThreshold = 2
        sut.daysBetweenPrompts = 2

        sut.recordNFCWrite()
        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)
    }

    func testShowsAgainAfterDayThreshold() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock, seed: { defaults in
            defaults.set(3, forKey: "razn.review.nfcWriteCount")
            defaults.set(
                Calendar.current.date(byAdding: .day, value: -3, to: clock.now),
                forKey: "razn.review.lastPromptDate"
            )
        })
        sut.nfcWriteThreshold = 2
        sut.daysBetweenPrompts = 2

        sut.recordNFCWrite()
        XCTAssertEqual(promptShownCount(defaults), 1)
    }

    // MARK: - App Launch Tests

    func testAppLaunchShowsPromptAfterDays() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock, seed: { defaults in
            defaults.set(
                Calendar.current.date(byAdding: .day, value: -3, to: clock.now),
                forKey: "razn.review.lastPromptDate"
            )
        })
        sut.daysBetweenPrompts = 2

        sut.recordAppLaunch()
        XCTAssertEqual(promptShownCount(defaults), 1)
    }

    func testAppLaunchDoesNotShowOnFirstLaunch() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock)

        sut.recordAppLaunch()
        XCTAssertEqual(promptShownCount(defaults), 0)
    }

    // MARK: - Reset Tests

    #if DEBUG
    func testResetClearsAllState() {
        let suite = makeSuiteName()
        let clock = Clock(Date())
        let (sut, defaults) = makeSUT(suiteName: suite, clock: clock, seed: { defaults in
            defaults.set(4, forKey: "razn.review.nfcWriteCount")
            defaults.set(clock.now, forKey: "razn.review.lastPromptDate")
            defaults.set(true, forKey: "razn.review.hasReviewed")
            defaults.set(2, forKey: "razn.review.promptShownCount")
        })
        sut.nfcWriteThreshold = 2

        sut.resetForTesting()

        XCTAssertEqual(defaults.integer(forKey: "razn.review.nfcWriteCount"), 0)
        XCTAssertNil(defaults.object(forKey: "razn.review.lastPromptDate") as? Date)
        XCTAssertFalse(defaults.bool(forKey: "razn.review.hasReviewed"))
        XCTAssertEqual(defaults.integer(forKey: "razn.review.promptShownCount"), 0)
    }
    #endif
}
