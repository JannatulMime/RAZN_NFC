//
//  TesterModeManager.swift
//  RAZN NFC
//

import Foundation
import FirebaseAnalytics

/// Persists and syncs internal tester identification to Firebase Analytics.
final class TesterModeManager {

    static let shared = TesterModeManager()

    static let userPropertyName = "user_type"
    static let testerValue = "tester"

    private let userDefaults: UserDefaults
    private let defaultsKey = "razn.testerMode.isEnabled"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isEnabled: Bool {
        userDefaults.bool(forKey: defaultsKey)
    }

    @discardableResult
    func toggle() -> Bool {
        setEnabled(!isEnabled)
        return isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: defaultsKey)
        syncAnalyticsUserProperty()
    }

    /// Re-applies the Firebase Analytics user property from persisted state.
    /// Call once after `FirebaseApp.configure()` on app launch.
    func restoreOnLaunch() {
        syncAnalyticsUserProperty()
    }

    private func syncAnalyticsUserProperty() {
        if isEnabled {
            Analytics.setUserProperty(Self.testerValue, forName: Self.userPropertyName)
            print("🔥 Analytics User Property set: \(Self.userPropertyName) = \(Self.testerValue)")
        } else {
            Analytics.setUserProperty(nil, forName: Self.userPropertyName)
            print("🔥 Analytics User Property cleared: \(Self.userPropertyName)")
        }
    }
}
