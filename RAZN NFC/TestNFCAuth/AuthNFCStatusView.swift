//
//  AuthNFCStatusView.swift
//  RAZN NFC
//

import SwiftUI

struct AuthNFCStatusView: View {
    let status: AuthNFCStatusMessage
    @State private var showTech = false

    var body: some View {
        if status.kind != .idle {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if status.kind == .progress {
                        ProgressView()
                            .tint(color)
                    }
                    Text(status.title)
                        .font(.custom(Constants.Fonts.interBold, size: 16))
                        .foregroundStyle(color)
                        .accessibilityAddTraits(.isHeader)
                }

                if !status.message.isEmpty {
                    Text(status.message)
                        .font(.custom(Constants.Fonts.interRegular, size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .textSelection(.enabled)
                }

                if let next = status.nextStep, !next.isEmpty {
                    Text("Next: \(next)")
                        .font(.custom(Constants.Fonts.interRegular, size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                }

                if let tech = status.technicalDetails, !tech.isEmpty {
                    Button {
                        showTech.toggle()
                    } label: {
                        Label(
                            showTech ? "Hide technical details" : "Technical details",
                            systemImage: "info.circle"
                        )
                        .font(.custom(Constants.Fonts.interRegular, size: 13))
                        .foregroundStyle(Color.brandBlue)
                    }
                    .accessibilityLabel("Technical details")

                    if showTech {
                        Text(tech)
                            .font(.custom(Constants.Fonts.interRegular, size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .contain)
        }
    }

    private var color: Color {
        switch status.kind {
        case .idle: return .clear
        case .progress: return Color.brandBlue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
