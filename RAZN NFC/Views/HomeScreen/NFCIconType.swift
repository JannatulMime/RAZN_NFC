//
//  NFCIconType.swift
//  RAZN NFC
//

import SwiftUI

enum NFCIconType: String, CaseIterable, Identifiable, Codable {
    case whatsapp
    case instagram
    case linkedIn
    case telegram
    case website
    case pay
    case review
    case link

    var id: String { rawValue }

    static let displayOrder: [NFCIconType] = [
        .whatsapp, .instagram, .linkedIn, .review,
        .website, .telegram, .pay, .link
    ]

    var label: String {
        switch self {
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .linkedIn: return "LinkedIn"
        case .telegram: return "Revolut"
        case .website: return "Website"
        case .pay: return "PayPal"
        case .review: return "Review"
        case .link: return "Link"
        }
    }

    var systemIcon: String {
        switch self {
        case .whatsapp: return "message.fill"
        case .instagram: return "camera.fill"
        case .linkedIn: return "person.2.fill"
        case .telegram: return "paperplane.fill"
        case .website: return "globe"
        case .pay: return "creditcard.fill"
        case .review: return "star.bubble.fill"
        case .link: return "link"
        }
    }

    var placeholderURL: String {
        switch self {
        case .whatsapp: return "https://wa.me/1234567890"
        case .instagram: return "https://instagram.com/username"
        case .linkedIn: return "https://linkedin.com/in/username"
        case .telegram: return "https://revolut.me/username"
        case .website: return "https://example.com"
        case .pay: return "https://paypal.me/username"
        case .review: return "https://g.page/r/example/review"
        case .link: return "https://linktr.ee/username"
        }
    }

    var brandColor: Color {
        switch self {
        case .whatsapp: return Color(hex: "#25D366") ?? .green
        case .instagram: return Color(hex: "#E1306C") ?? .pink
        case .linkedIn: return Color(hex: "#0A66C2") ?? .blue
        case .telegram: return Color(hex: "#229ED9") ?? .cyan
        case .website: return Color(hex: "#8E8E93") ?? .gray
        case .pay: return Color(hex: "#34C759") ?? .mint
        case .review: return Color(hex: "#FF9F0A") ?? .orange
        case .link: return Color(hex: "#AF52DE") ?? .purple
        }
    }

    var iconAssetName: String? {
        switch self {
        case .whatsapp:
            return "Whatsapp img 3"
        case .instagram:
            return "insta img"
        case .linkedIn:
            return "Linkin img"
        case .telegram:
            return "R img"
        case .website, .link:
            return "url_icon"
        case .pay:
            return "Paypal img 2"
        case .review:
            return "urlIMG"
        }
    }
}

struct NFCIconType_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ForEach(NFCIconType.allCases) { type in
                HStack {
                    Image(systemName: type.systemIcon)
                    Text(type.label)
                    Spacer()
                }
                .foregroundColor(type.brandColor)
            }
        }
        .padding()
        .background(Color.black)
    }
}
