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

            CustomBG()
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
