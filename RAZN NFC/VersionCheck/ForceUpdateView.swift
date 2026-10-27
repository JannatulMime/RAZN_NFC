//
//  ForceUpdateView.swift
//  RAZN NFC
//

import SwiftUI

struct ForceUpdateView: View {
    let message: String
    let canOpenAppStore: Bool
    let onUpdateNow: () -> Void

    var body: some View {
        ZStack {
            CustomBG()

            VStack(spacing: 28) {
                Spacer()

                Image("razuAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Update Required")
                        .font(.custom(Constants.Fonts.interBold, size: 28))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.custom(Constants.Fonts.interRegular, size: 16))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Text("Updating is required to continue using RAZN.")
                        .font(.custom(Constants.Fonts.interRegular, size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                Button(action: onUpdateNow) {
                    Text("Update Now")
                        .font(.custom(Constants.Fonts.interBold, size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canOpenAppStore)
                .opacity(canOpenAppStore ? 1 : 0.5)
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer()
                Spacer()
            }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    ForceUpdateView(
        message: "A new version of RAZN is required. Please update to continue.",
        canOpenAppStore: true,
        onUpdateNow: {}
    )
}
