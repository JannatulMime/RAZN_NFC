//
//  AuthNFCTestAuthView.swift
//  RAZN NFC
//
//  Tester-only screen: scan an NTAG215, show UID + master key + derived password.
//  Does not send PWD_AUTH and does not write to the tag.
//

import SwiftUI

struct AuthNFCTestAuthView: View {
    @StateObject private var manager = AuthNFCManager()
    @State private var credentials: AuthNFCDerivedCredentials?
    @State private var masterKeyHex: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    scanButton
                    if let credentials {
                        resultsCard(credentials)
                    }
                    AuthNFCStatusView(status: manager.status)
                }
                .padding(24)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Test Auth")
                    .font(.custom(Constants.Fonts.interBold, size: 16))
                    .foregroundStyle(.white)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            masterKeyHex = (try? AuthNFCMasterKeyProvider.shared.masterKeyHexForDisplay()) ?? ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test Auth")
                .font(.custom(Constants.Fonts.interBold, size: 26))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            Text("Scan an NTAG213 or NTAG215 to preview the UID, master key, and generated password. The tag is not authenticated and nothing is written.")
                .font(.custom(Constants.Fonts.interRegular, size: 15))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var scanButton: some View {
        Button {
            InteractionFeedback.tap()
            Task {
                let result = await manager.previewDerivedCredentials()
                credentials = result
                if masterKeyHex.isEmpty {
                    masterKeyHex = (try? AuthNFCMasterKeyProvider.shared.masterKeyHexForDisplay()) ?? ""
                }
            }
        } label: {
            HStack(spacing: 10) {
                if manager.isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text("Scan Tag")
                    .font(.custom(Constants.Fonts.interBold, size: 17))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                manager.isBusy ? Color.brandBlue.opacity(0.5) : Color.brandBlue,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(manager.isBusy)
        .accessibilityLabel("Scan Tag")
    }

    private func resultsCard(_ credentials: AuthNFCDerivedCredentials) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Derived Credentials")
                .font(.custom(Constants.Fonts.interBold, size: 16))
                .foregroundStyle(.white)

            detailRow(label: "UID", value: credentials.uidDisplayHex)
            detailRow(label: "Master Key", value: masterKeyHex.isEmpty ? "(unavailable)" : masterKeyHex)
            detailRow(label: "Password", value: credentials.passwordHex)
            detailRow(label: "PACK", value: credentials.packHex)

            Text("PWD_AUTH was not sent. Use Add Auth on Tag Manager to write these credentials to the tag.")
                .font(.custom(Constants.Fonts.interRegular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom(Constants.Fonts.interRegular, size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.custom(Constants.Fonts.interBold, size: 15))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .minimumScaleFactor(0.7)
                .lineLimit(3)
        }
    }
}

#Preview {
    NavigationStack {
        AuthNFCTestAuthView()
    }
}
