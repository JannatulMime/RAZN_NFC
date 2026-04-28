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
                .font(.body.weight(.semibold))
                .foregroundColor(Color.black.opacity(0.28))

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text("Paste your link")
                        .foregroundColor(Color.black.opacity(0.28))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(Color.black.opacity(0.82))
                .font(.system(size: 13))

                if showTrailingOverlayClear, !text.isEmpty {
                    Button(action: { onClear?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.black.opacity(0.85))
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
                        .frame(width: 18, height: 18)
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
                .font(.subheadline.weight(.semibold))
                .foregroundColor(pasteEnabled ? .white : .gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .opacity(pasteEnabled ? 1.0 : 0.4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
            }
            .disabled(!pasteEnabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
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
