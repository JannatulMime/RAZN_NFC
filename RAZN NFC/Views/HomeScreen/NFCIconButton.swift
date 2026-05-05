//
//  NFCIconButton.swift
//  RAZN NFC
//

import SwiftUI

struct NFCIconButton: View {
    let icon: NFCIcon
    let onTap: () -> Void
    let onLongPress: () -> Void
    @State private var isPressed: Bool = false
    @State private var didLongPress: Bool = false
    private let cornerRadius: CGFloat = 22

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Spacer(minLength: 0)

                Image(systemName: icon.type.iconSymbolName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.black)

                Text(icon.type.label)
                    .font(.custom(Constants.Fonts.interRegular, size: 12))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 9)
            .frame(width: 76, height: 76)

//            if icon.hasLink {
//                Circle()
//                    .fill(Color.brandBlue)
//                    .frame(width: 7, height: 7)
//                    .padding(.trailing, 6)
//                    .padding(.bottom, 6)
//            }
        }
        .frame(width: 76, height: 76)
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .opacity(isPressed ? 0.75 : 1.0)
        .animation(.easeIn(duration: 0.08), value: isPressed)
        .onTapGesture {
            if didLongPress {
                didLongPress = false
                return
            }
            onTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = false
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    didLongPress = true
                    onLongPress()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                        didLongPress = false
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeIn(duration: 0.08)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(icon.type.label)
        .accessibilityHint("Tap to autofill, press and hold to edit")
    }

}

struct NFCIconButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NFCIconButton(icon: NFCIcon(type: .chat), onTap: {}, onLongPress: {})
                .padding()
        }
    }
}
