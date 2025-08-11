//
//  AddURLFieldView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddURLFieldView: View {
    @State private var name: String = ""
    @State private var urlText: String = ""
    
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
                
                urlSection
                textfieldAndButtton
               
                Spacer()
               
            }
        }
    }
}

#Preview {
    AddURLFieldView()
}

extension AddURLFieldView {
    
    var urlSection: some View {
        HStack(spacing: 10) {
            Image("url_icon")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
            
            Text("URL/URI")
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .semibold))
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.black.opacity(0.6))
        
    }
    
    var textfieldAndButtton: some View {
        VStack {
            
            HStack (spacing: 0) {
                Text("insert")
                    .font(.system(size: 15))
                    .padding()
                
                Text("l ’ URL")
                    .font(.custom("AvenirNext-Bold", size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                //  .padding(.horizontal)
                
            }
            
            
            HStack(spacing: 0) {
                TextField("https://", text: $urlText)
                    .padding()
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.6))
                
                Button(action: {
                    print("Edit tapped")
                }) {
                    Text("edit")
                        .foregroundColor(.white)
                        .frame(width: 60, height: 20)
                        .padding()
                        .background(Color.gray)
                }
            }
            .cornerRadius(5)
            // .padding(.horizontal)
            
            // Rounded example URL with {...} button
            HStack {
                Text("www.example.it")
                    .font(.system(size: 20))
                 
                    .tint(.gray)
                    .kerning(5)
                
                    .padding(.vertical, 8)
                    .padding(.horizontal, 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.black, lineWidth: 1)
                           
                    )
                Spacer()
                
                
                Text("{ ... }")
                    .foregroundColor(.gray)
                    .padding()
                
            }.padding(.horizontal)
        }
            .background(.white.opacity(0.9))
            .padding(.horizontal)
            
            
            
        
    }
}
