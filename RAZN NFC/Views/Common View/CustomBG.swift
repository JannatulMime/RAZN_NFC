//
//  CustomBG.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 12/8/25.
//

import SwiftUI

struct CustomBG: View {
  
    let bgColor : Color = Color(hex: "#292929")!
   
    var body: some View {
        
       
        
        Image("BG")
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
            .overlay(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: bgColor.opacity(1.0), location: 0.0), // Dark at very top
                        .init(color: bgColor.opacity(0.0), location: 0.2), // Quickly fade to transparent
                        .init(color: bgColor.opacity(0.0), location: 0.5), // Stay transparent for most of the middle
                        .init(color: bgColor.opacity(0.0), location: 0.8), // Quickly fade to
                        .init(color:bgColor.opacity(1.0), location: 1.0), // Dark again at bottom
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
