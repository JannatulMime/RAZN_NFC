//
//  EditLinkSheet.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

struct EditLinkSheet: View {
    let icon: NFCIcon
    @Binding var inputText: String
    let isSaveEnabled: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .frame(width: 76, height: 76)

                Image(systemName: icon.type.iconSymbolName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white)
            }

            Text("Edit \(icon.type.label)")
                .font(.custom(Constants.Fonts.cgoogla, size: 26))
                .foregroundStyle(.white)

            Text(icon.hasLink ? (icon.savedLink ?? "") : "No link saved")
                .font(.custom(Constants.Fonts.cgoogla, size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            InputSectionView(
                text: $inputText,
                onPaste: {
                    InteractionFeedback.tap()
                    inputText = UIPasteboard.general.string ?? ""
                },
                onClear: {
                    InteractionFeedback.tap()
                    inputText = ""
                },
                showTrailingOverlayClear: true
            )

            HStack(spacing: 12) {
                Button("Cancel") {
                    InteractionFeedback.tap()
                    onCancel()
                }
                    .font(.custom(Constants.Fonts.cgoogla, size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Save") {
                    InteractionFeedback.tap()
                    onSave()
                }
                    .font(.custom(Constants.Fonts.cgoogla, size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSaveEnabled ? Color.brandBlue : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .opacity(isSaveEnabled ? 1.0 : 0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(!isSaveEnabled)
                    .animation(.easeInOut(duration: 0.2), value: isSaveEnabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .background(Color(hex: "#090A12") ?? Color.black)
    }

//    private var iconSymbolName: String {
//        switch icon.type {
//        case .social:
//            return "message.fill"
//        case .chat:
//            return "camera.fill"
//        case .business:
//            return "briefcase.fill"
//        case .review:
//            return "paperplane.fill"
//        case .custom:
//            return "globe"
//        case .pay:
//            return "hand.point.up.left.fill"
//        case .website:
//            return "star.fill"
//        case .link:
//            return "link"
//        }
//    }
}

struct EditLinkSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditLinkSheet(
            icon: NFCIcon(type: .custom, savedLink: nil),
            inputText: .constant("https://example.com"),
            isSaveEnabled: true,
            onSave: {},
            onCancel: {}
        )
        .preferredColorScheme(.dark)
    }
}
