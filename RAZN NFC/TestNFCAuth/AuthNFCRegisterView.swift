//
//  AuthNFCRegisterView.swift
//  RAZN NFC
//

import SwiftUI

struct AuthNFCRegisterView: View {
    @StateObject private var manager = AuthNFCManager()
    @State private var password = ""
    @State private var confirmation = ""
    @State private var currentPassword = ""
    @State private var showOverwriteFields = false
    @State private var showOverwriteAlert = false
    @State private var helpTopic: AuthNFCHelpTopic?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    passwordFields

                    if showOverwriteFields {
                        overwriteSection
                    }

                    Button {
                        Task { await startRegister(allowOverwrite: showOverwriteFields) }
                    } label: {
                        HStack {
                            if manager.isBusy {
                                ProgressView().tint(.white)
                            }
                            Text("Register Password")
                                .font(.custom(Constants.Fonts.interBold, size: 17))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(manager.isBusy ? Color.brandBlue.opacity(0.5) : Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(manager.isBusy)
                    .accessibilityLabel("Register Password")

                    Button {
                        helpTopic = .registration
                    } label: {
                        Label("Registration instructions", systemImage: "info.circle")
                            .font(.custom(Constants.Fonts.interRegular, size: 14))
                            .foregroundStyle(Color.brandBlue)
                    }

                    AuthNFCStatusView(status: manager.status)
                }
                .padding(24)
            }
        }
        .navigationTitle("Register Tag Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $helpTopic) { topic in
            AuthNFCInfoSheet(topic: topic)
        }
        .alert("Existing Protection Detected", isPresented: $showOverwriteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showOverwriteFields = true
                manager.status = .warning(
                    "Confirm Overwrite",
                    message: "Enter the tag’s current password below, then tap Register Password again. This overwrites PWD, PACK, and AUTH0/ACCESS. Irreversible lock bits are still not set.",
                    nextStep: "Use a spare tag if you are unsure."
                )
            }
        } message: {
            Text(AuthNFCError.existingProtectionRequiresConfirmation.explanation)
        }
        .onChange(of: manager.status) { newStatus in
            if newStatus.kind == .error,
               newStatus.title == AuthNFCError.existingProtectionRequiresConfirmation.title {
                showOverwriteAlert = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set a four-byte password on NTAG213, NTAG215, or NTAG216 using the variant’s configuration pages (not user memory).")
                .font(.custom(Constants.Fonts.interRegular, size: 14))
                .foregroundStyle(.white.opacity(0.7))

            Text("Enter exactly 8 hex characters (e.g. AABBCCDD). PACK is derived for acknowledgement and is not the password.")
                .font(.custom(Constants.Fonts.interRegular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var passwordFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("Password (8 hex chars)", text: $password)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
                .disabled(manager.isBusy)
                .accessibilityLabel("Password")

            SecureField("Confirm password", text: $confirmation)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
                .disabled(manager.isBusy)
                .accessibilityLabel("Confirm password")
        }
    }

    private var overwriteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current tag password")
                .font(.custom(Constants.Fonts.interBold, size: 14))
                .foregroundStyle(.orange)

            Text("Required because this tag already has protection enabled. If this tag was registered with this demo, use that password. Otherwise use a fresh test tag.")
                .font(.custom(Constants.Fonts.interRegular, size: 12))
                .foregroundStyle(.white.opacity(0.6))

            SecureField("Current password (8 hex chars)", text: $currentPassword)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(.white)
                .disabled(manager.isBusy)
                .accessibilityLabel("Current password")
        }
    }

    private func startRegister(allowOverwrite: Bool) async {
        manager.clearStatus()
        await manager.registerPassword(
            passwordHex: password,
            confirmationHex: confirmation,
            allowOverwrite: allowOverwrite,
            currentPasswordHex: allowOverwrite ? currentPassword : nil
        )
    }
}

#Preview {
    NavigationStack {
        AuthNFCRegisterView()
    }
}
