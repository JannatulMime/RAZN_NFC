//
//  AddURLFieldView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddURLFieldView: View {
    var body: some View {
        ZStack {
            
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
                
                TopBarView(mainTitle: "add fieled", leftBtnTitle: "back", rightBtnTitle: "OK")
                    .background(.black)
                
                HStack(spacing: 5) {
                    
                    Image("url_icon")
                        .resizable()
                        .frame(width: 100, height: 100)
                    
                    Text("URL/URI")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                }.padding(.leading)
                Spacer()
            }
        }
    }
}

#Preview {
    AddURLFieldView()
}
