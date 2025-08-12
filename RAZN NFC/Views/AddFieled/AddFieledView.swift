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
        
            CustomBG()
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
