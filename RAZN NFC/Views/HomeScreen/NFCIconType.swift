//
//  NFCIconType.swift
//  RAZN NFC
//

import SwiftUI

enum NFCIconType: String, CaseIterable, Identifiable, Codable {
    case social
    case chat
    case business
    case review
    case custom
    case pay
    case website
    case link

    var id: String { rawValue }

    static let displayOrder: [NFCIconType] = [
        .social, .chat, .business, .review,
        .custom, .pay, .website, .link
    ]

    var label: String {
        switch self {
        case .social: return "Social"
        case .chat: return "Chat"
        case .business: return "Business"
        case .review: return "Review"
        case .custom: return "Custom"
        case .pay: return "Pay"
        case .website: return "Website"
        case .link: return "Link"
        }
    }

    var brandColor: Color {
        switch self {
        case .social: return Color(hex: "#25D366") ?? .green
        case .chat: return Color(hex: "#E1306C") ?? .pink
        case .business: return Color(hex: "#0A66C2") ?? .blue
        case .review: return Color(hex: "#229ED9") ?? .cyan
        case .custom: return Color(hex: "#8E8E93") ?? .gray
        case .pay: return Color(hex: "#34C759") ?? .mint
        case .website: return Color(hex: "#FF9F0A") ?? .orange
        case .link: return Color(hex: "#AF52DE") ?? .purple
        }
    }

    var iconAssetName: String? {
        switch self {
        case .social:
            return "whatsApp"
        case .chat:
            return "instagram"
        case .business:
            return "linkedin"
        case .review:
            return "telegram"
        case .custom, .link:
            return "link_icon"
        case .pay:
            return "paypal"
        case .website:
            return "globe"
        }
    }
    
    
    var iconSymbolName: String {
        switch self {
        case .social:
            return "hand.thumbsup"
        case .chat:
            return "message"
        case .business:
            return "briefcase"
        case .review:
            return "star"
        case .custom:
            return "link"
        case .pay:
            return "creditcard"
        case .website:
            return "globe"
        case .link:
            return "link"
        }
    }
}

struct NFCIconType_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ForEach(NFCIconType.allCases) { type in
                HStack {
                    Image(type.iconAssetName!)
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
