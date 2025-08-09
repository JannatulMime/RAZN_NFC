//
//  AddFieledView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddFieledView: View {
    var body: some View {
        ZStack {
            // Background
            Image("BG")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack {
                
                TopBarView(mainTitle: "add fieled", leftBtnTitle: "Write")
                
                Button(action: {
                   
                }) {

                    Image("add_url_field")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 120)
                    
                }
                
                
                
                Spacer()
            }
        }

    }
}

#Preview {
    AddFieledView()
}
