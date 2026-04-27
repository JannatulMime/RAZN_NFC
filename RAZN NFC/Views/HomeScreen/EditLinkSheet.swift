//
//  EditLinkSheet.swift
//  RAZN NFC
//

import SwiftUI

struct EditLinkSheet: View {
    let icon: NFCIcon
    @Binding var inputText: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            ZStack {
                Circle()
                    .fill(icon.type.brandColor.opacity(0.22))
                    .frame(width: 76, height: 76)

                Image(systemName: icon.type.systemIcon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(icon.type.brandColor)
            }

            Text("Edit \(icon.type.label)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(icon.hasLink ? (icon.savedLink ?? "") : "No link saved")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            TextField(icon.type.placeholderURL, text: $inputText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Save", action: onSave)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(icon.type.brandColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .font(.headline)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
        .background(Color(hex: "#090A12") ?? Color.black)
    }
}

struct EditLinkSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditLinkSheet(
            icon: NFCIcon(type: .website, savedLink: nil),
            inputText: .constant("https://example.com"),
            onSave: {},
            onCancel: {}
        )
        .preferredColorScheme(.dark)
    }
}
