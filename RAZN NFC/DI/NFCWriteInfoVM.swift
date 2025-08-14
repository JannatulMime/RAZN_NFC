//
//  DIContainer.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 14/8/25.
//

import Foundation

class NFCWriteInfoVM : ObservableObject{
    @Published var insertedURL : String = ""
    @Published var insertedURLPrefix : String = "https://"
    
    
    func getfullURL() -> String{
        return insertedURLPrefix + insertedURL
    }
}
