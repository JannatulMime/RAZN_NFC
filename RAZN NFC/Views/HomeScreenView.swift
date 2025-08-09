//
//  HomeScreenView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI

struct HomeScreenView: View {
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
//                        HStack {
//                            // Settings Icon
//                            Image("settingIcon")
//                                .resizable()
//                                .frame(width: 40, height: 40)
//                                .foregroundColor(.white)
//                                .padding()
//
//                            Spacer()
//
//                            // Share Icon
//                            Image("shareIcon")
//                                .resizable()
//                                .frame(width: 40, height: 40)
//                                .foregroundColor(.white)
//                                .padding()
//                        }
                
                Spacer()
                
                // Logo
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 160, height: 160)
                    
                  //  Text("razn")
                    Image("razuAppIcon")
                        .resizable()
                        .frame(width: 150, height: 150)
                       
                      
                }
                
                Spacer()
                
                // Welcome Text
                VStack(spacing: 10) {
                    
                    Image("welcomeImgDesign")
                        .resizable()
                        .frame(width: 350, height: 200)
                  
                }
                
                Spacer()
                
                // Write Button
                Button(action: {
                   
                }) {

                    
                    
                    Image("writeWithText")
                        .resizable()
                        .frame(width: 300, height: 80)
                }
                
                // Down Arrow
                Image("upArrow")
                    .resizable()
                    .frame(width: 80, height: 80)
            }
        }
    }
}

#Preview {
    HomeScreenView()
}
