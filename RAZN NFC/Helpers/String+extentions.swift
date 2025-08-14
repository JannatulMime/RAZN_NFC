//
//  String+extentions.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 14/8/25.
//

import Foundation

extension String {
   
    func isValidURLString() -> Bool {
        return self.lowercased().hasPrefix("https://") || self.lowercased().hasPrefix("www.")
    }
    
    func getBytes() -> Int{
        let byteSize = self.utf8.count
        return byteSize
    }
    
    func getBytesString() -> String {
        return "\(self.getBytes()) bytes"
    }
    
    
}
