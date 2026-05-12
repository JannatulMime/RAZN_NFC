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
    /// When set (NFCToolsView only): leading icon swaps to share when input is a valid web URL; tap shares the normalized link string.
    var onShareLink: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            leadingIcon

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text("Paste your link")
                        .foregroundColor(Color(red: 0.62, green: 0.66, blue: 0.72))
                        .font(.custom(Constants.Fonts.interRegular, size: 13))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(Color.black.opacity(0.85))
                .font(.custom(Constants.Fonts.interRegular, size: 16))

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
                .font(.custom(Constants.Fonts.interRegular, size: 12))
                .foregroundColor(Color.brandBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .opacity(pasteEnabled ? 1.0 : 0.55)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.95, blue: 1.0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
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

    @ViewBuilder
    private var leadingIcon: some View {
        let iconTint = Color(red: 0.62, green: 0.66, blue: 0.72)
        if onShareLink != nil, isValidWebURLInput(text) {
            Button {
                InteractionFeedback.tap()
                onShareLink?(normalizedWebLinkInput(text))
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.brandBlue)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "link")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconTint)
        }
    }

    /// Mirrors `NFCViewModel.normalizeURLInput` so validation matches write behavior.
    private func normalizedWebLinkInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("http://") ||
            lowercased.hasPrefix("https://") ||
            lowercased.hasPrefix("www.") {
            return trimmed
        }
        return "https://\(trimmed)"
    }

    private func isValidWebURLInput(_ raw: String) -> Bool {
        let n = normalizedWebLinkInput(raw)
        guard !n.isEmpty else { return false }
        guard let url = URL(string: n) else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return true
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
