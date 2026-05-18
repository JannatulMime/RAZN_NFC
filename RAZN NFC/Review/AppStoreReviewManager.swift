//
//  AppStoreReviewManager.swift
//  RAZN NFC
//

import Foundation
import StoreKit
import UIKit

/// Drives when to ask for an App Store rating.
///
/// **Apple’s UI only:** eligible triggers call `SKStoreReviewController.requestReview(in:)`.
/// Apple may or may not show the system sheet (rate limits apply). There is no custom review sheet.
@MainActor
final class AppStoreReviewManager {
    static let shared = AppStoreReviewManager()

    var nfcWriteThreshold: Int = 2
    var daysBetweenPrompts: Int = 2

    private let userDefaults: UserDefaults
    private let clock: () -> Date

    init(userDefaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init) {
        self.userDefaults = userDefaults
        self.clock = clock
    }

    func recordNFCWrite() {
        let next = integer(for: .nfcWriteCount) + 1
        set(next, for: .nfcWriteCount)
        evaluateAfterNFCWrite()
    }

    func recordAppLaunch() {
        evaluateAfterAppLaunch()
    }

//    #if DEBUG
//    func resetForTesting() {
//        ReviewDefaultsKey.allCases.forEach { removeValue(for: $0) }
//    }
//
//    /// Presents StoreKit’s in-app review UI immediately (for design/debug on device/simulator).
//    func requestStoreKitReviewForDebug() {
//        requestStoreReview()
//    }
//    #endif

    // MARK: - Private

    private func evaluateAfterNFCWrite() {
        guard !bool(for: .hasReviewed) else { return }

        let count = integer(for: .nfcWriteCount)
        guard count > 0, count.isMultiple(of: max(1, nfcWriteThreshold)) else {
            return
        }

        let last = date(for: .lastPromptDate)
        if last.map({ hasMetDayCadence(since: $0) }) ?? true {
            offerSystemReviewIfNeeded()
        }
    }

    private func evaluateAfterAppLaunch() {
        guard !bool(for: .hasReviewed) else { return }

        guard let last = date(for: .lastPromptDate) else {
            return
        }

        guard hasMetDayCadence(since: last) else {
            return
        }

        offerSystemReviewIfNeeded()
    }

    /// Records that we asked Apple to show the in-app review UI and updates cadence keys.
    private func offerSystemReviewIfNeeded() {
        let shown = integer(for: .promptShownCount) + 1
        set(shown, for: .promptShownCount)
        set(clock(), for: .lastPromptDate)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            requestStoreReview()
        }
    }

    private func hasMetDayCadence(since lastPromptDate: Date) -> Bool {
        let calendar = Calendar.current
        let startLast = calendar.startOfDay(for: lastPromptDate)
        let startNow = calendar.startOfDay(for: clock())
        let days = calendar.dateComponents([.day], from: startLast, to: startNow).day ?? 0
        return days >= max(1, daysBetweenPrompts)
    }

    private func requestStoreReview() {
        FirebaseAnalyticsManager.shared.track(.reviewPopupShown)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene =
            scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first
        if let scene {
            SKStoreReviewController.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview()
        }
    }

    // MARK: - UserDefaults

    private enum ReviewDefaultsKey: String, CaseIterable {
        case nfcWriteCount = "razn.review.nfcWriteCount"
        case lastPromptDate = "razn.review.lastPromptDate"
        case hasReviewed = "razn.review.hasReviewed"
        case promptShownCount = "razn.review.promptShownCount"
    }

    private func removeValue(for key: ReviewDefaultsKey) {
        userDefaults.removeObject(forKey: key.rawValue)
    }

    private func integer(for key: ReviewDefaultsKey) -> Int {
        guard userDefaults.object(forKey: key.rawValue) != nil else { return 0 }
        return userDefaults.integer(forKey: key.rawValue)
    }

    private func set(_ value: Int, for key: ReviewDefaultsKey) {
        userDefaults.set(value, forKey: key.rawValue)
    }

    private func bool(for key: ReviewDefaultsKey) -> Bool {
        userDefaults.bool(forKey: key.rawValue)
    }

    private func set(_ value: Bool, for key: ReviewDefaultsKey) {
        userDefaults.set(value, forKey: key.rawValue)
    }

    private func date(for key: ReviewDefaultsKey) -> Date? {
        userDefaults.object(forKey: key.rawValue) as? Date
    }

    private func set(_ value: Date, for key: ReviewDefaultsKey) {
        userDefaults.set(value, forKey: key.rawValue)
    }
}
