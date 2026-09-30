//
//  FirebaseAnalyticsManager.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 15/5/26.
//

import Foundation
import FirebaseAnalytics

final class FirebaseAnalyticsManager {

    static let shared = FirebaseAnalyticsManager()
    static let testerEventPrefix = "tester_"

    private let testerMode: TesterModeManager

    init(testerMode: TesterModeManager = .shared) {
        self.testerMode = testerMode
    }

    // MARK: - Public API

    func track(_ event: AnalyticsEvent) {
        let resolvedName = resolvedEventName(for: event)

        print("🔥 Analytics Tracked:", resolvedName)
        print("🔥 Parameters:", event.parameters ?? [:])
        Analytics.logEvent(
            resolvedName,
            parameters: event.parameters
        )
    }

    func resolvedEventName(for event: AnalyticsEvent) -> String {
        let baseName = event.eventName
        guard testerMode.isEnabled else { return baseName }
        return "\(Self.testerEventPrefix)\(baseName)"
    }
}

// MARK: - Analytics Events

extension FirebaseAnalyticsManager {

    enum AnalyticsEvent {

        case appOpened
        case successfulNFCWrite
        case selectedQuickButtonCategory(category: String)
        case reviewPopupShown
        case quickButtonOpenedInBrowser(category: String)

        // MARK: Event Name

        var eventName: String {

            switch self {

            case .appOpened:
                return "app_opened"

            case .successfulNFCWrite:
                return "successful_nfc_write"

            case .selectedQuickButtonCategory:
                return "selected_quick_button_category"

            case .reviewPopupShown:
                return "review_popup_shown"

            case .quickButtonOpenedInBrowser:
                return "quick_button_opened_in_browser"
            }
        }

        // MARK: Parameters

        var parameters: [String: Any]? {

            switch self {

            case .selectedQuickButtonCategory(let category):
                return [
                    "category": category
                ]

            case .quickButtonOpenedInBrowser(let category):
                return [
                    "category": category
                ]

            default:
                return nil
            }
        }
    }
}
