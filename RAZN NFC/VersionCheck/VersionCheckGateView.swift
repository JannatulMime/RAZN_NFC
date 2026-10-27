//
//  VersionCheckGateView.swift
//  RAZN NFC
//

import SwiftUI

struct VersionCheckGateView<Content: View>: View {
    @StateObject private var viewModel = AppVersionViewModel()
    @Environment(\.scenePhase) private var scenePhase
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                versionCheckLoadingView
            case .failed(let message):
                versionCheckFailedView(message: message)
            case .updateRequired(let message, _):
                ForceUpdateView(
                    message: message,
                    canOpenAppStore: true,
                    onUpdateNow: { viewModel.openAppStore() }
                )
            case .allowed:
                content
            }
        }
        .onAppear {
            if case .loading = viewModel.state {
                viewModel.checkOnLaunch()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.recheckIfNeededOnBecomeActive()
            }
        }
    }

    private var versionCheckLoadingView: some View {
        ZStack {
            CustomBG()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.2)
        }
    }

    private func versionCheckFailedView(message: String) -> some View {
        ZStack {
            CustomBG()

            VStack(spacing: 24) {
                Image("razuAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("Unable to Verify")
                    .font(.custom(Constants.Fonts.interBold, size: 26))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.custom(Constants.Fonts.interRegular, size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Button {
                    viewModel.retry()
                } label: {
                    Text("Retry")
                        .font(.custom(Constants.Fonts.interBold, size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
            }
        }
    }
}
