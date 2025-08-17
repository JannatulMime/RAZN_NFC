//
//  MenuView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct MenuView: View {
    @StateObject var vm = MenuVM()
    @EnvironmentObject var nfcWriteInfoVM : NFCWriteInfoVM
    @StateObject private var nfcReader = NFCReader()
    
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
    
    private func scanTag() {
        nfcReader.scan { payload in
            print("U>> Scaned data \(payload)")
        }
        
        
    }
    
    private func writeTag(text : String) {
        nfcReader.write(text, completion: { isSuccess in
            print("U>> write isSuccess \(isSuccess)")
            
            if text.isValidURLString(){
                print("Valid Url")
                writeTag(text: nfcWriteInfoVM.getfullURL())
            }else{
                print("inValid Url")
            }
            
        })
 
    }
}

#Preview {
    MenuView()
        .environmentObject(NFCWriteInfoVM())
}


extension MenuView {
    
      
    var mainSection: some View {
        
        VStack {
            TopBarView(mainTitle: "write", leftBtnTitle: "Menu", rightBtnTitle: "edit")
               // .padding(.horizontal)
                .background(.black)
            
            Button(action: {
                vm.gotoAddFieled = true
                
            }) {
                Image("addFieldButton")
                    .resizable()
                    .frame(width: 350, height: 90)
            }
            
            Button(action: {
                writeTag(text: nfcWriteInfoVM.getfullURL())
            }) {
                ZStack{
                    Image("writeButton")
                        .resizable()
                        .frame(width: 350, height: 90)
                    
                    HStack{
                        Text(nfcWriteInfoVM.getfullURL().getBytesString())
                            .font(.custom(Constants.Fonts.cgoogla, size: 20))
                            .foregroundStyle(Color.white)
                    }
                   
                }
                
            }
            
            Spacer()
        }
        
    }
}
