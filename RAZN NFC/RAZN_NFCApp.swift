//
//  RAZN_NFCApp.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI
import FirebaseCore

@main
struct RAZN_NFCApp: App {
    init() {
        FirebaseApp.configure()
        print("Firebase App configured")
        FirebaseAnalyticsManager.shared.track(.appOpened)
//        for family in UIFont.familyNames {
//            print("Family: \(family)")
//            for name in UIFont.fontNames(forFamilyName: family) {
//                print("  Font: \(name)")
//            }
//        }
    }

    var body: some Scene {
        @StateObject var nfcWriteInfoVM : NFCWriteInfoVM = NFCWriteInfoVM()
       
        WindowGroup {
            RootView()
                .environmentObject(nfcWriteInfoVM)
            //ContentView()
        }
    }
}
