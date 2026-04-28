//
//  InputSectionView.swift
//  RAZN NFC
//

import SwiftUI

struct InputSectionView: View {
    @Binding var text: String
    let onPaste: () -> Void
    var onClear: (() -> Void)? = nil
    var pasteEnabled: Bool = true
    var showMiddleClearButton: Bool = false
    var showTrailingOverlayClear: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 0.62, green: 0.66, blue: 0.72))

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text("Paste your link")
                        .foregroundColor(Color(red: 0.62, green: 0.66, blue: 0.72))
                        .font(.custom(Constants.Fonts.cgoogla, size: 13))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(Color.black.opacity(0.85))
                .font(.custom(Constants.Fonts.cgoogla, size: 16))

                if showTrailingOverlayClear, !text.isEmpty {
                    Button(action: { onClear?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.black.opacity(0.95))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showMiddleClearButton, !text.isEmpty {
                Button(action: { onClear?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 12, height: 12)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(width: 1, height: 22)

            Button(action: onPaste) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                }
                .font(.custom(Constants.Fonts.cgoogla, size: 10))
                .foregroundColor(Color(red: 0.34, green: 0.44, blue: 0.88))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .opacity(pasteEnabled ? 1.0 : 0.55)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.95, blue: 1.0))
                )
            }
            .disabled(!pasteEnabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
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
