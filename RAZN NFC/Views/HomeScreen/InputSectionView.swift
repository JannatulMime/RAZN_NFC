//
//  InputSectionView.swift
//  RAZN NFC
//

import SwiftUI

struct InputSectionView: View {
    @Binding var text: String
    let onPaste: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.body.weight(.semibold))
                .foregroundColor(Color.black.opacity(0.28))

            TextField(
                "",
                text: $text,
                prompt: Text("Paste your link")
                    .foregroundColor(Color.black.opacity(0.28))
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(Color.black.opacity(0.82))

            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(width: 1, height: 22)

            Button(action: onPaste) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.black.opacity(0.62))
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
    }
}

struct InputSectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            InputSectionView(text: .constant(""), onPaste: {})
                .padding()
        }
    }
}
