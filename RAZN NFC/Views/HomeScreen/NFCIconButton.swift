//
//  NFCIconButton.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

struct NFCIconButton: View {
    let icon: NFCIcon
    let onTap: () -> Void
    let onLongPress: () -> Void
    private let cornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.22), radius: 7, x: 0, y: 3)

            iconVisual
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous))
                .padding(3.5)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(icon.type.label)
        .accessibilityHint("Tap to autofill, press and hold to edit")
    }

    @ViewBuilder
    private var iconVisual: some View {
        if let assetName = icon.type.iconAssetName, UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .padding(6)
        }
//        else {
//            platformFallback
//        }
    }
//
//    @ViewBuilder
//    private var platformFallback: some View {
//        switch icon.type {
//        case .whatsapp:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color(hex: "#38D95E") ?? .green)
//                Image(systemName: "phone.fill")
//                    .font(.system(size: 29, weight: .heavy))
//                    .foregroundColor(.white)
//            }
//        case .instagram:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(
//                        LinearGradient(
//                            colors: [
//                                Color(hex: "#FEDA77") ?? .yellow,
//                                Color(hex: "#F58529") ?? .orange,
//                                Color(hex: "#DD2A7B") ?? .pink,
//                                Color(hex: "#8134AF") ?? .purple,
//                                Color(hex: "#515BD4") ?? .blue
//                            ],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                Image(systemName: "camera")
//                    .font(.system(size: 27, weight: .bold))
//                    .foregroundColor(.white)
//            }
//        case .linkedIn:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color(hex: "#0A66C2") ?? .blue)
//                Text("in")
//                    .font(.system(size: 34, weight: .black))
//                    .foregroundColor(.white)
//                    .offset(y: 1)
//            }
//        case .review:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color(hex: "#E6E8EE") ?? .gray.opacity(0.2))
//                VStack(spacing: 2) {
//                    Image(systemName: "person.crop.circle.fill")
//                        .font(.system(size: 26, weight: .semibold))
//                    Image(systemName: "star.square.on.square")
//                        .font(.system(size: 18, weight: .bold))
//                }
//                .foregroundColor(Color(hex: "#E54EA1") ?? .pink)
//            }
//        case .telegram:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color(hex: "#EEF0F5") ?? .gray.opacity(0.18))
//                VStack(spacing: -2) {
//                    Text("R")
//                        .font(.system(size: 36, weight: .heavy))
//                        .foregroundColor(Color(hex: "#C2C7D2") ?? .gray)
//                    Text("Revolut")
//                        .font(.system(size: 10, weight: .medium))
//                        .foregroundColor(Color(hex: "#A6ABB5") ?? .gray)
//                }
//            }
//        case .pay:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color(hex: "#EDEFF4") ?? .gray.opacity(0.18))
//                Text("PP")
//                    .font(.system(size: 30, weight: .black))
//                    .foregroundColor(Color(hex: "#0070BA") ?? .blue)
//                    .tracking(-1.5)
//            }
//        case .website, .link:
//            ZStack {
//                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                    .fill(Color(hex: "#ECEEF3") ?? .gray.opacity(0.18))
//                Image(systemName: "link")
//                    .font(.system(size: 24, weight: .bold))
//                    .foregroundColor(Color(hex: "#6E7480") ?? .gray)
//            }
//        }
//    }
}

struct NFCIconButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NFCIconButton(icon: NFCIcon(type: .instagram), onTap: {}, onLongPress: {})
                .padding()
        }
    }
}
