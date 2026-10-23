//
//  AuthNFCWriteView.swift
//  RAZN NFC
//

import SwiftUI

struct AuthNFCWriteView: View {
    @StateObject private var manager = AuthNFCManager()
    @State private var password = ""
    @State private var content = ""
    @State private var readDisplay = ""
    @State private var helpTopic: AuthNFCHelpTopic?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Authenticate before writing when the tag protects user memory. Unprotected tags can be written without a password. Use Read Tag (No Authentication) to inspect accessible content without sending PWD_AUTH.")
                        .font(.custom(Constants.Fonts.interRegular, size: 14))
                        .foregroundStyle(.white.opacity(0.7))

                    SecureField("Password (8 hex chars, optional if unprotected)", text: $password)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.white)
                        .disabled(manager.isBusy)
                        .accessibilityLabel("Password")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Content to Write")
                            .font(.custom(Constants.Fonts.interBold, size: 14))
                            .foregroundStyle(.white.opacity(0.8))

                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(.white)
                            .disabled(manager.isBusy)
                            .accessibilityLabel("Content to Write")
                    }

                    Button {
                        Task { await write() }
                    } label: {
                        HStack {
                            if manager.isBusy {
                                ProgressView().tint(.white)
                            }
                            Text("Authenticate & Write")
                                .font(.custom(Constants.Fonts.interBold, size: 17))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(manager.isBusy ? Color.brandBlue.opacity(0.5) : Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(manager.isBusy)
                    .accessibilityLabel("Authenticate and Write")

                    Button {
                        Task { await read() }
                    } label: {
                        Text("Read Content")
                            .font(.custom(Constants.Fonts.interBold, size: 17))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.brandBlue)
                            .background(Color.brandBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(manager.isBusy)
                    .accessibilityLabel("Read Content")

                    HStack(spacing: 10) {
                        Button {
                            Task { await readWithoutAuth() }
                        } label: {
                            Text("Read Tag (No Authentication)")
                                .font(.custom(Constants.Fonts.interBold, size: 17))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.white)
                                .background(manager.isBusy ? Color.green.opacity(0.35) : Color.green.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(manager.isBusy)
                        .accessibilityLabel("Read Tag No Authentication")

                        Button {
                            helpTopic = .unauthenticatedRead
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.brandBlue)
                                .frame(width: 44, height: 44)
                                .background(Color.brandBlue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(manager.isBusy)
                        .accessibilityLabel("About Read Tag No Authentication")
                    }

                    HStack(spacing: 16) {
                        Button {
                            helpTopic = .authenticateWrite
                        } label: {
                            Label("Write help", systemImage: "info.circle")
                                .font(.custom(Constants.Fonts.interRegular, size: 14))
                                .foregroundStyle(Color.brandBlue)
                        }

                        Button {
                            helpTopic = .reading
                        } label: {
                            Label("Read help", systemImage: "info.circle")
                                .font(.custom(Constants.Fonts.interRegular, size: 14))
                                .foregroundStyle(Color.brandBlue)
                        }
                    }

                    AuthNFCStatusView(status: manager.status)

                    if !readDisplay.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stored content")
                                .font(.custom(Constants.Fonts.interBold, size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                            Text(readDisplay)
                                .font(.custom(Constants.Fonts.interRegular, size: 15))
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Stored content")
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Authenticated Tag Operations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $helpTopic) { topic in
            AuthNFCInfoSheet(topic: topic)
        }
        .onChange(of: manager.status) { newStatus in
            if newStatus.kind == .success, newStatus.title == "Read Successful" {
                // Extract content after the protection note blank line.
                let parts = newStatus.message.components(separatedBy: "\n\n")
                if parts.count >= 2 {
                    readDisplay = parts.dropFirst().joined(separator: "\n\n")
                } else {
                    readDisplay = newStatus.message
                }
            }
        }
    }

    private func write() async {
        manager.clearStatus()
        await manager.authenticateAndWrite(passwordHex: password, content: content)
    }

    private func read() async {
        manager.clearStatus()
        await manager.readContent(passwordHex: password)
    }

    private func readWithoutAuth() async {
        manager.clearStatus()
        await manager.readTagWithoutAuthentication()
    }
}

#Preview {
    NavigationStack {
        AuthNFCWriteView()
    }
}
