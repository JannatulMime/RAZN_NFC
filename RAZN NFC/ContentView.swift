//
//  ContentView.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 20/8/25.
//

import Foundation


import SwiftUI

struct ContentView: View {
    @State private var path: [Screen] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            View1(path: $path)
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .view1: View1(path: $path)
                    case .view2: View2(path: $path)
                    case .view3: View3(path: $path)
                    case .view4: View4(path: $path)
                    }
                }
        }
    }
}

enum Screen: Hashable {
    case view1, view2, view3, view4
}

// MARK: - Screens

struct View1: View {
    @Binding var path: [Screen]
    
    var body: some View {
        VStack {
            Text("View 1")
            Button("Go to View 2") {
                path.append(.view2)
            }
        }
        .navigationTitle("View 1")
    }
}

struct View2: View {
    @Binding var path: [Screen]
    
    var body: some View {
        VStack {
            Text("View 2")
            Button("Go to View 3") {
                path.append(.view3)
            }
        }
        .navigationTitle("View 2")
    }
}

struct View3: View {
    @Binding var path: [Screen]
    
    var body: some View {
        VStack {
            Text("View 3")
            Button("Go to View 4") {
                path.append(.view4)
            }
        }
        .navigationTitle("View 3")
    }
}

struct View4: View {
    @Binding var path: [Screen]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("View 4")
            
            Button("Back to View 1") {
                path = [.view1]
            }
            Button("Back to View 2") {
                path = [.view1, .view2]
            }
            Button("Back to View 3") {
                path = [.view1, .view2, .view3]
            }
        }
        .navigationTitle("View 4")
    }
}
