//
//  NFCIcon.swift
//  RAZN NFC
//

import Foundation
import SwiftUI

struct NFCIcon: Identifiable, Equatable {
    let id: UUID
    let type: NFCIconType
    var savedLink: String?

    init(id: UUID = UUID(), type: NFCIconType, savedLink: String? = nil) {
        self.id = id
        self.type = type
        self.savedLink = savedLink
    }

    var hasLink: Bool {
        guard let savedLink else { return false }
        return !savedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct NFCIcon_Previews: PreviewProvider {
    static var previews: some View {
        let icon = NFCIcon(type: .website, savedLink: "https://example.com")
        return Text("\(icon.type.label) - Has Link: \(icon.hasLink ? "Yes" : "No")")
            .padding()
    }
}
