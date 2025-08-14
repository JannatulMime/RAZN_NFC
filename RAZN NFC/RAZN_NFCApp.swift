//
//  RAZN_NFCApp.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI

@main
struct RAZN_NFCApp: App {
    init() {
        for family in UIFont.familyNames {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  Font: \(name)")
            }
        }
    }

    var body: some Scene {
        @StateObject var nfcWriteInfoVM : NFCWriteInfoVM = NFCWriteInfoVM()
       
        WindowGroup {
            SplashScreenView()
                .environmentObject(nfcWriteInfoVM)
            // HomeScreenView()
            //            NFCReaderView()
        }
    }
}
