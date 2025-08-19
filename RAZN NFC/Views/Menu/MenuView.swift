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
              //  .background(.black)
            
            VStack{
                
                Button(action: {
                    vm.gotoAddFieled = true
                    
                }) {
                    
                    ZStack {
                        Image("glass_capsule")
                            .resizable()
                            .frame( height: 80)

                        HStack{
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.white)
                                .padding(.leading,30)
                            
                            Spacer()
                           
                                
                            Text("ADD FIELD")
                                .font(.custom(Constants.Fonts.cgoogla, size: 20))
                                .foregroundStyle(.white.opacity(0.8))
                                .offset(x: -30,y: 2)
                            Spacer()
                            
                        }
                    }
                }
                
                Button(action: {
                    writeTag(text: nfcWriteInfoVM.getfullURL())
                }) {
                    ZStack {
                        Image("glass_capsule")
                            .resizable()
                            .frame( height: 80)

                        HStack{
                            Image(systemName: "person.wave.2")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.white)
                                .padding(.leading,30)
                            
                            Spacer()
                           
                                
                            Text("WRITE / " + nfcWriteInfoVM.getfullURL().getBytesString())
                                .font(.custom(Constants.Fonts.cgoogla, size: 20))
                                .foregroundStyle(.white.opacity(0.8))
                                .offset(x: -30,y: 2)
                            Spacer()
                            
                        }
                    }
                    
                }
            }
            .padding(.horizontal,50)
            
            
            
           
            
            Spacer()
        }
        
    }
}
