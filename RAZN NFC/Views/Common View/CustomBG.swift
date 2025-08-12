//
//  CustomBG.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 12/8/25.
//

import SwiftUI

struct CustomBG: View {
    var body: some View {
        Image("BG")
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.8), location: 0.0), // Dark at very top
                        .init(color: Color.black.opacity(0.0), location: 0.2), // Quickly fade to transparent
                        .init(color: Color.black.opacity(0.0), location: 0.5), // Stay transparent for most of the middle
                        .init(color: Color.black.opacity(0.9), location: 1.0), // Dark again at bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

#Preview {
    CustomBG()
}
