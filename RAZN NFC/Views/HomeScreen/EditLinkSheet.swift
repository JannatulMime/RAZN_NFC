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
                .font(.custom(Constants.Fonts.interRegular, size: 26))
                .foregroundStyle(.white)

            Text(icon.hasLink ? (icon.savedLink ?? "") : "No link saved")
                .font(.custom(Constants.Fonts.interRegular, size: 14))
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
            ).padding(.horizontal,20)

            HStack(spacing: 12) {
                Button(action: {
                    InteractionFeedback.tap()
                    onCancel()
                }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                    .font(.custom(Constants.Fonts.interRegular, size: 18))
                    .foregroundStyle(.blue)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
                    .buttonStyle(.plain)

                Button(action: {
                    InteractionFeedback.tap()
                    onSave()
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                    .font(.custom(Constants.Fonts.interRegular, size: 18))
                    .foregroundStyle(isSaveEnabled ? Color.white : Color.white.opacity(0.55))
                    .background(
                        isSaveEnabled ? Color.brandBlue.opacity(0.50) : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSaveEnabled ? Color.white.opacity(0.18) : Color.white.opacity(0.10), lineWidth: 0.8)
                    )
                    .disabled(!isSaveEnabled)
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: isSaveEnabled)
            }
            .padding(.horizontal,20)

            Spacer(minLength: 0)
        }
       // .padding(.horizontal, 20)
        .presentationDragIndicator(.hidden)
        .background(Color(hex: "#090A12") ?? Color.black)
       // .modifier(SheetFullWidthSizingModifier())
    }

/// iOS 18+ sheets default to an inset "card" width; `.page` uses the full screen width.
private struct SheetFullWidthSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
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
