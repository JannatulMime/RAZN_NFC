//
//  NFCIconButton.swift
//  RAZN NFC
//

import SwiftUI

struct NFCIconButton: View {
    let icon: NFCIcon
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(icon.type.brandColor.opacity(0.7), lineWidth: 1)
                    )

                Image(systemName: icon.type.systemIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(icon.type.brandColor)
            }
            .frame(height: 68)

            Text(icon.type.label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(icon.type.label)
        .accessibilityHint("Tap to autofill, press and hold to edit")
    }
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
