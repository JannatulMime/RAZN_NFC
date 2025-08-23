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
    
    @Binding var path: [Screens]
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            mainSection
            
        }.background {
            CustomBG()
        }
        .alert("Alert",
               isPresented: $showAlert) {
            Button("Close", role: .cancel) { }
        } message: {
            Text("Please add a valid link!")
        }
        .navigationBarBackButtonHidden(true)
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
    
    func getWriteBytesText() -> String {
        if nfcWriteInfoVM.isUrlInserted() == false {
            return "WRITE"
        }
        
       return "WRITE / " + nfcWriteInfoVM.getfullURL().getBytesString()
    }
}

#Preview {
    MenuView(path: .constant([]))
        .environmentObject(NFCWriteInfoVM())
}


extension MenuView {
    
      
    var mainSection: some View {
        
        VStack {
            TopBarView(mainTitle: "write", leftBtnTitle: "Menu", rightBtnTitle: "edit")
              //  .background(.black)
            
            VStack{
                
                Button(action: {
                   // vm.gotoAddFieled = true
                    path.append(.AddField)
                    
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
                    
                    if nfcWriteInfoVM.isUrlInserted() == false {
                        showAlert = true
                    }else{
                        writeTag(text: nfcWriteInfoVM.getfullURL())
                    }
                    
                   
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
                           
                                
                            Text(getWriteBytesText())
                                .font(.custom(Constants.Fonts.cgoogla, size: 20))
                                .foregroundStyle(.white.opacity(0.8))
                                .offset(x: -30,y: 2)
                            Spacer()
                            
                        }
                    }
                    
                }
                
               
            }
            .padding(.horizontal,30)
            
            if nfcWriteInfoVM.isUrlInserted(){
                URLFieldButtonView()
                    .frame(height: 100)
                   // .padding(.horizontal,20)
            }
           
           
            
            Spacer()
        }
        
    }
}
