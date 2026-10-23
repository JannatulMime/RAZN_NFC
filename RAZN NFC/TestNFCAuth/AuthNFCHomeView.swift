//
//  AuthNFCHomeView.swift
//  RAZN NFC
//

import SwiftUI

struct AuthNFCHomeView: View {
    @State private var helpTopic: AuthNFCHelpTopic?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NTAG21x Password Demo")
                        .font(.custom(Constants.Fonts.interBold, size: 26))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)

                    Text("Register a password on NTAG213, NTAG215, or NTAG216, authenticate before writing protected pages, and read accessible content with or without authentication.")
                        .font(.custom(Constants.Fonts.interRegular, size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 12) {
                    NavigationLink {
                        AuthNFCRegisterView()
                    } label: {
                        Text("Register Tag")
                            .font(.custom(Constants.Fonts.interBold, size: 17))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(Color.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Register Tag")

                    NavigationLink {
                        AuthNFCWriteView()
                    } label: {
                        Text("Write / Read")
                            .font(.custom(Constants.Fonts.interBold, size: 17))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.brandBlue)
                            .background(Color.brandBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("Write or Read")
                }

                Button {
                    helpTopic = .demoOverview
                } label: {
                    Label("How this demo works", systemImage: "info.circle")
                        .font(.custom(Constants.Fonts.interRegular, size: 15))
                        .foregroundStyle(Color.brandBlue)
                }
                .accessibilityLabel("Demo information")

                Spacer()
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("AuthNFC")
                    .font(.custom(Constants.Fonts.interBold, size: 16))
                    .foregroundStyle(.white)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $helpTopic) { topic in
            AuthNFCInfoSheet(topic: topic)
        }
    }
}

#Preview {
    NavigationStack {
        AuthNFCHomeView()
    }
}
