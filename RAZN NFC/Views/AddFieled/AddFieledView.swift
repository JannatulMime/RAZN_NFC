//
//  AddFieledView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddFieledView: View {
    @StateObject var vm = AddFieledVM()
    
    var body: some View {
        ZStack {
            
            customBG
            mainSection
           
            
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $vm.gotoURLFieldView, destination: {
            AddURLFieldView()
        })
    }
}

#Preview {
    AddFieledView()
}

extension AddFieledView {
    
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
            TopBarView(mainTitle: "add fieled", leftBtnTitle: "Write")

            Button(action: {
                vm.gotoURLFieldView = true
                
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
