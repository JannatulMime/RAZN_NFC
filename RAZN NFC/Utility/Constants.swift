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
    }
    
   static func getAppLink() -> URL {
        let appleId = "6749680572"
        let appURL = URL(string: "https://apps.apple.com/app/id\(appleId)")!
        return appURL
    }
}
