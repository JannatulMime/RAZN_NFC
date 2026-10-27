//
//  TagManagerView.swift
//  RAZN NFC
//
//  Tester-mode hub for checking, adding, and removing NTAG21x password protection
//  with the fixed Tag Manager password (AuthNFCConstants.tagManagerPasswordHex).
//

import SwiftUI

struct TagManagerView: View {
    @StateObject private var manager = AuthNFCManager()
    @State private var showOverwriteAlert = false
    @State private var showRemoveAlert = false
    @State private var showRemovePasswordPrompt = false
    @State private var removePasswordInput = ""
    /// When true, an auth/PACK failure from Remove Auth opens the manual password prompt.
    @State private var promptPasswordOnRemoveAuthFailure = false

    private let passwordHex = AuthNFCConstants.tagManagerPasswordHex

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    passwordLabel
                    actionButtons
                    if let check = manager.lastAuthCheck {
                        TagAuthDetailsCard(result: check)
                    }
                    AuthNFCStatusView(status: manager.status)
                }
                .padding(24)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Tag Manager")
                    .font(.custom(Constants.Fonts.interBold, size: 16))
                    .foregroundStyle(.white)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Existing Protection Detected", isPresented: $showOverwriteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Overwrite", role: .destructive) {
                Task {
                    await manager.registerPassword(
                        passwordHex: passwordHex,
                        confirmationHex: passwordHex,
                        allowOverwrite: true,
                        currentPasswordHex: passwordHex
                    )
                }
            }
        } message: {
            Text("This tag already has password protection. Overwrite it using the Tag Manager password (\(passwordHex))? The current password must also be \(passwordHex).")
        }
        .alert("Remove Auth?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove Auth", role: .destructive) {
                Task {
                    await removeAuth(using: passwordHex)
                }
            }
        } message: {
            Text("This disables password protection on the tag (AUTH0 → 0xFF) after authenticating with \(passwordHex). Tag content is not erased.")
        }
        .alert("Password Required", isPresented: $showRemovePasswordPrompt) {
            TextField("8 hex characters", text: $removePasswordInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                removePasswordInput = ""
                promptPasswordOnRemoveAuthFailure = false
            }
            Button("Remove Auth", role: .destructive) {
                let entered = removePasswordInput.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    await removeAuth(using: entered)
                }
            }
        } message: {
            Text("The Tag Manager password did not match this tag. Enter the tag’s current 8-character hex password to remove auth.")
        }
        .onChange(of: manager.status) { newStatus in
            if newStatus.kind == .error,
               newStatus.title == AuthNFCError.existingProtectionRequiresConfirmation.title {
                showOverwriteAlert = true
            }

            if promptPasswordOnRemoveAuthFailure,
               newStatus.kind == .error,
               isRemoveAuthPasswordMismatch(newStatus) {
                promptPasswordOnRemoveAuthFailure = false
                removePasswordInput = ""
                showRemovePasswordPrompt = true
            }

            if newStatus.kind == .success {
                promptPasswordOnRemoveAuthFailure = false
            }
        }
    }

    private func removeAuth(using hex: String) async {
        promptPasswordOnRemoveAuthFailure = true
        await manager.removePasswordProtection(passwordHex: hex)
    }

    private func isRemoveAuthPasswordMismatch(_ status: AuthNFCStatusMessage) -> Bool {
        status.title == AuthNFCError.authenticationRejected.title
            || status.title == AuthNFCError.packMismatch.title
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tag Manager")
                .font(.custom(Constants.Fonts.interBold, size: 26))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Text("Check, add, or remove NTAG21x password protection using the shared Tag Manager password. Supported tags: NTAG213, NTAG215, and NTAG216.")
                .font(.custom(Constants.Fonts.interRegular, size: 15))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var passwordLabel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.custom(Constants.Fonts.interRegular, size: 12))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brandBlue)

                Text(passwordHex)
                    .font(.custom(Constants.Fonts.interBold, size: 17))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .accessibilityLabel("Password \(passwordHex)")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            TagManagerActionButton(
                title: "Check Auth",
                systemImage: "checkmark.shield",
                style: .primary,
                isBusy: manager.isBusy
            ) {
                InteractionFeedback.tap()
                Task { await manager.checkAuthStatus(passwordHex: passwordHex) }
            }

            TagManagerActionButton(
                title: "Add Auth",
                systemImage: "lock.shield",
                style: .secondary,
                isBusy: manager.isBusy
            ) {
                InteractionFeedback.tap()
                Task {
                    await manager.registerPassword(
                        passwordHex: passwordHex,
                        confirmationHex: passwordHex,
                        allowOverwrite: false,
                        currentPasswordHex: nil
                    )
                }
            }

            TagManagerActionButton(
                title: "Remove Auth",
                systemImage: "lock.open",
                style: .destructive,
                isBusy: manager.isBusy
            ) {
                InteractionFeedback.tap()
                showRemoveAlert = true
            }
        }
    }

}

// MARK: - Action button

private enum TagManagerButtonStyle {
    case primary
    case secondary
    case destructive
}

private struct TagManagerActionButton: View {
    let title: String
    let systemImage: String
    let style: TagManagerButtonStyle
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .tint(progressTint)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.custom(Constants.Fonts.interBold, size: 17))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(title)
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.brandBlue
        case .destructive: return Color.red.opacity(isBusy ? 0.5 : 1)
        }
    }

    private var background: Color {
        switch style {
        case .primary:
            return isBusy ? Color.brandBlue.opacity(0.5) : Color.brandBlue
        case .secondary:
            return Color.brandBlue.opacity(0.15)
        case .destructive:
            return Color.red.opacity(0.15)
        }
    }

    private var progressTint: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.brandBlue
        case .destructive: return .red
        }
    }
}

// MARK: - Tag details card

private struct TagAuthDetailsCard: View {
    let result: AuthNFCAuthCheckResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)

                Text(result.authStatusTitle)
                    .font(.custom(Constants.Fonts.interBold, size: 16))
                    .foregroundStyle(accent)

                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                detailRow(label: "Tag", value: result.displayName)
                detailRow(label: "AUTH0", value: String(format: "0x%02X", result.auth0))
                detailRow(label: "Protection", value: result.protectionModeLabel)
                detailRow(label: "Config lock", value: result.isConfigLocked ? "Locked (CFGLCK)" : "Not locked")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var accent: Color {
        switch result.passwordMatch {
        case .matched: return .green
        case .rejected: return .orange
        case .skipped: return .gray
        }
    }

    private var statusSymbol: String {
        switch result.passwordMatch {
        case .matched: return "checkmark.seal.fill"
        case .rejected: return "exclamationmark.shield.fill"
        case .skipped: return "shield.slash"
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.custom(Constants.Fonts.interRegular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 12)
            Text(value)
                .font(.custom(Constants.Fonts.interBold, size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        TagManagerView()
    }
}
