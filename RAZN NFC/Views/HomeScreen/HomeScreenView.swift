//
//  HomeScreenView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI


enum Screens: Hashable {
    case Home, Menu, AddField, AddUrl, TagManager
}

struct RootView: View {
    @State private var path: [Screens] = []
    @StateObject private var versionViewModel = AppVersionViewModel()
    @State private var showForceUpdate = false
    @State private var forceUpdateMessage = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreenView(path: $path)
                .navigationDestination(for: Screens.self) { screen in
                    switch screen {
                    case .Home: HomeScreenView(path: $path)
                    case .Menu: MenuView(path: $path)
                    case .AddField: AddFieledView(path: $path)
                    case .AddUrl: AddURLFieldView(path: $path)
                    case .TagManager: TagManagerView()
                    }
                }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardLayoutLocked()
        .onAppear {
            versionViewModel.checkOnLaunch()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                versionViewModel.recheckIfNeededOnBecomeActive()
            }
        }
        .onChange(of: versionViewModel.state) { newState in
            switch newState {
            case .updateRequired(let message, _):
                forceUpdateMessage = message
                showForceUpdate = true
            case .allowed:
                showForceUpdate = false
            }
        }
        .fullScreenCover(isPresented: forceUpdateCoverBinding) {
            ForceUpdateView(
                message: forceUpdateMessage,
                canOpenAppStore: true,
                onUpdateNow: { versionViewModel.openAppStore() }
            )
            .interactiveDismissDisabled()
        }
    }

    /// Ignores dismiss attempts while an update is still required.
    private var forceUpdateCoverBinding: Binding<Bool> {
        Binding(
            get: { showForceUpdate },
            set: { newValue in
                if !newValue, case .updateRequired = versionViewModel.state {
                    return
                }
                showForceUpdate = newValue
            }
        )
    }
}

struct HomeScreenView: View {
    @Binding var path: [Screens]

    var body: some View {
        NFCToolsView(path: $path)
            .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    HomeScreenView(path: .constant([]))
}
