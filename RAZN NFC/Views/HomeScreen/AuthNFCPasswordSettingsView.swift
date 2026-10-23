//
//  AuthNFCPasswordSettingsView.swift
//  RAZN NFC
//
//  Production sheet for storing the local NTAG21x write password and
//  unregistering password-based protection from a physical tag.
//

import SwiftUI

struct AuthNFCPasswordSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var unregisterController = AuthNFCUnregisterController()
    @State private var passwordText: String = ""
    @State private var currentPassword: String?
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var showInfo = false
    @State private var showUnregisterConfirmation = false

    private let store: AuthNFCPasswordStore

    init(store: AuthNFCPasswordStore = AuthNFCPasswordStore()) {
        self.store = store
        _currentPassword = State(initialValue: store.retrieve())
        _unregisterController = StateObject(wrappedValue: AuthNFCUnregisterController(passwordStore: store))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 42, height: 5)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)

                        Text("Store NFC Password")
                            .font(.custom(Constants.Fonts.interBold, size: 22))
                            .foregroundStyle(.white)

                        Text("Enter the 8-character hexadecimal password used on your password-protected NTAG21x tags. This only saves the password on this iPhone for later write authentication — it does not change any physical tag.")
                            .font(.custom(Constants.Fonts.interRegular, size: 13))
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(currentPasswordLabel)
                            .font(.custom(Constants.Fonts.interRegular, size: 14))
                            .foregroundStyle(currentPassword == nil ? .white.opacity(0.45) : Color.brandBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .accessibilityLabel(currentPasswordLabel)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password (8 hex characters)")
                                .font(.custom(Constants.Fonts.interRegular, size: 12))
                                .foregroundStyle(.white.opacity(0.5))

                            SecureField("e.g. A1B2C3D4", text: $passwordText)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.custom(Constants.Fonts.interRegular, size: 17))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                        }

                        Text("Accepted format: exactly eight hexadecimal characters (0–9, A–F), representing four bytes. Example: A1B2C3D4.")
                            .font(.custom(Constants.Fonts.interRegular, size: 12))
                            .foregroundStyle(.white.opacity(0.45))

                        Button {
                            InteractionFeedback.tap()
                            savePassword()
                        } label: {
                            Text("Save Password")
                                .font(.custom(Constants.Fonts.interBold, size: 17))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Color.brandBlue,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(unregisterController.isBusy)

                        Button {
                            InteractionFeedback.tap()
                            showUnregisterConfirmation = true
                        } label: {
                            HStack {
                                if unregisterController.isBusy {
                                    ProgressView().tint(.white)
                                }
                                Text("Unregister")
                                    .font(.custom(Constants.Fonts.interBold, size: 17))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                unregisterController.isBusy
                                    ? Color.red.opacity(0.45)
                                    : Color.red.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(unregisterController.isBusy)
                        .accessibilityLabel("Unregister NFC tag password protection")

                        Text("Unregister authenticates with the stored password, then disables password-based protection on the scanned NTAG213/NTAG215 (AUTH0 → 0xFF). It does not erase tag content.")
                            .font(.custom(Constants.Fonts.interRegular, size: 12))
                            .foregroundStyle(.white.opacity(0.45))

                        AuthNFCStatusView(status: unregisterController.status)

                        Button {
                            InteractionFeedback.tap()
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.custom(Constants.Fonts.interRegular, size: 16))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .disabled(unregisterController.isBusy)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(hex: "#090A12") ?? Color.black)

                if let toastMessage {
                    ToastView(message: toastMessage)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.brandBlue)
                    }
                    .accessibilityLabel("Password usage information")
                }
            }
            .sheet(isPresented: $showInfo) {
                AuthNFCPasswordInfoSheet()
                    .presentationDetents([.medium, .large])
            }
            .alert("Unregister NFC Tag?", isPresented: $showUnregisterConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Unregister", role: .destructive) {
                    Task {
                        await unregisterController.unregister()
                        currentPassword = store.retrieve()
                    }
                }
            } message: {
                Text("This disables password-based write protection on the scanned tag (AUTH0 set to 0xFF). It does not erase NDEF or other user content. After successful verification, the password stored on this iPhone will be cleared.")
            }
            .onAppear {
                currentPassword = store.retrieve()
            }
            .onChange(of: unregisterController.status) { newStatus in
                if newStatus.kind == .success {
                    currentPassword = store.retrieve()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currentPasswordLabel: String {
        if let currentPassword {
            return "Current password: \(currentPassword)"
        }
        return "Current password: none stored"
    }

    private func savePassword() {
        do {
            try store.save(hexPassword: passwordText)
            currentPassword = store.retrieve()
            passwordText = ""
            unregisterController.clearStatus()
            showToast("Password saved successfully")
        } catch {
            showToast("Password save failed")
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }
}

// MARK: - Info sheet

private struct AuthNFCPasswordInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let paragraphs = [
        "This password is used when writing to password-protected NTAG21x tags.",
        "Reading accessible tag content does not require this stored password.",
        "The password must match the password previously configured on the tag.",
        "Changing this setting does not change the password on any physical tag.",
        "Unregister disables password-based protection on a scanned tag after authenticating with this stored password. It does not erase tag content.",
        "If the password is incorrect, protected writing and unregister will fail.",
        "The demo and production flow use the same password format: exactly eight hexadecimal characters representing four bytes (for example A1B2C3D4).",
        "Storage note: the password is kept in UserDefaults on this device. UserDefaults is not encrypted secure storage; Keychain is preferable if stronger confidentiality is required."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.custom(Constants.Fonts.interRegular, size: 15))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .navigationTitle("About NFC Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AuthNFCPasswordSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AuthNFCPasswordSettingsView()
            .preferredColorScheme(.dark)
    }
}
