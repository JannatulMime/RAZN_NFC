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

    private init() {}

    // MARK: - Public API

    func track(_ event: AnalyticsEvent) {

        print("Analytics Tracked \(event.eventName) ")
        Analytics.logEvent(
            event.eventName,
            parameters: event.parameters
        )
    }
}

// MARK: - Analytics Events

extension FirebaseAnalyticsManager {

    enum AnalyticsEvent {

        case appOpened
        case successfulNFCWrite
        case selectedQuickButtonCategory(category: String)
        case reviewPopupShown

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
            }
        }

        // MARK: Parameters

        var parameters: [String: Any]? {

            switch self {

            case .selectedQuickButtonCategory(let category):
                return [
                    "category": category
                ]

            default:
                return nil
            }
        }
    }
}
