//
//  SplashScreenView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 11/8/25.
//

import SwiftUI

struct SplashScreenView: View {
    
    @State private var showSplash = true
    @State private var splashOpacity = 1.0

    var body: some View {
        ZStack {
            if showSplash {
                logoView
                    .opacity(splashOpacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeOut(duration: 1.0)) {
                                splashOpacity = 0
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                HomeScreenView()
            }
        }
    }
}

#Preview {
    SplashScreenView()
}

extension SplashScreenView {
    var logoView: some View {
        ZStack {
            Color.black.opacity(0.8)
            VStack {
                Image("razuAppIcon")
                    .resizable()
                    .frame(width: 200, height: 180)
            }
        }
        .ignoresSafeArea()
    }
}



