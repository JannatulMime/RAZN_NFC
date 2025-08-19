//
//  DIContainer.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 14/8/25.
//

import Foundation

class NFCWriteInfoVM : ObservableObject{
    @Published var insertedURL: String = ""
    @Published var insertedURLPrefix: String = "https://"

    func getfullURL() -> String {
        let lowercased = insertedURL.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // If it already starts with http, https, or www → return as-is
        if lowercased.hasPrefix("http://") ||
           lowercased.hasPrefix("https://") ||
           lowercased.hasPrefix("www.") {
            return insertedURL
        }

        // Otherwise → add the default prefix
        return insertedURLPrefix + insertedURL
    }

}
