//
//  Constants.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 12/8/25.
//

import Foundation

class Constants {
    class Fonts {
        static let cgoogla = "Croogla4F"
        static let interRegular = "Inter-Regular"
        // Font file `Inter_Bold.ttf` internal/PostScript name is `Inter18pt-Bold`.
        // Using the wrong name causes SwiftUI to fall back to a non-bold font.
        static let interBold = "Inter18pt-Bold"
    }
    
   static func getAppLink() -> URL {
        let appleId = "6749680572"
        let appURL = URL(string: "https://apps.apple.com/app/id\(appleId)")!
        return appURL
    }
}
