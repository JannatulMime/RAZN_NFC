//
//  AddURLFieldView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddURLFieldView: View {
    @State private var name: String = ""
    
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
            
            VStack (spacing: 0){
                
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
                    .background(.black.opacity(0.8))
               // Spacer()
                
                
                ZStack {
                    Image("whiteBG")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 400, height: 150)
                    
                    VStack {
                        HStack() {
                            Text("insert      I ' URL")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding()
                            Spacer()
                        }
                        
                        TextField("Type here...", text: $name) // Bind text to state
                            .textFieldStyle(RoundedBorderTextFieldStyle()) // Nice rounded look
                            .padding()
                        
                        Image("urlIMG")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 400, height: 50)
                           
                        
                    }
                    
                    
                  
                 //   .padding()
                    
                  
                        
                }
                
                Spacer()
                
                
            }
        }
    }
}

#Preview {
    AddURLFieldView()
}
