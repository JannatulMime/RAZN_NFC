//
//  HomeScreenView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI


enum Screens: Hashable {
    case Home, Menu, AddField, AddUrl
}

struct RootView: View {
    @State private var path: [Screens] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreenView(path: $path)
                .navigationDestination(for: Screens.self) { screen in
                    switch screen {
                    case .Home: HomeScreenView(path: $path)
                    case .Menu: MenuView(path: $path)
                    case .AddField: AddFieledView(path: $path)
                    case .AddUrl: AddURLFieldView(path: $path)
                    }
                }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardLayoutLocked()
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
