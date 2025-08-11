//
//  MenuView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct MenuView: View {
    @StateObject var vm = MenuVM()
    
    var body: some View {
        ZStack {
            customBG
            mainSection
            
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $vm.gotoAddFieled, destination: {
                AddFieledView()
            })
        }
    }
}

#Preview {
    MenuView()
}


extension MenuView {
    
    var customBG: some View {
        
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


    }
    
    var mainSection: some View {
        
        VStack {
            TopBarView(mainTitle: "write", leftBtnTitle: "Menu", rightBtnTitle: "edit")
            
            Button(action: {
                vm.gotoAddFieled = true
                
            }) {
                Image("addFieldButton")
                    .resizable()
                    .frame(width: 350, height: 90)
            }
            
            Button(action: {
            }) {
                Image("writeButton")
                    .resizable()
                    .frame(width: 350, height: 90)
            }
            
            Spacer()
        }
        
    }
}
