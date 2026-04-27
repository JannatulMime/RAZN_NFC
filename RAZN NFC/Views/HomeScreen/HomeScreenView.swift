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

    }
    
    
}

struct HomeScreenView: View {
    @Binding var path: [Screens]

    var body: some View {
        NFCToolsView(path: $path)
    }
}

#Preview {
    HomeScreenView(path: .constant([]))
}
