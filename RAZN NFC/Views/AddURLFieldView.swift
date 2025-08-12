//
//  AddURLFieldView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddURLFieldView: View {
  
    @State private var urlText: String = ""
    @StateObject private var nfcReader = NFCReader()
    
    var body: some View {
        ZStack {
            
            CustomBG()
            
            VStack (spacing: 0) {
                
                TopBarView(mainTitle: "add fieled",
                           leftBtnTitle: "back", rightBtnTitle: "OK")
                    .background(.black)
                
                urlSection
                textfieldAndButtton
               
                Spacer()
               
            }
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
        })
        
        
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
                 //.font(.custom("AvenirNext-Bold", size: 20))
                    .font(.custom(Constants.Fonts.cgoogla, size: 15))
                    .padding()
                
                Text("l ’ URL")
                   // .font(.custom("AvenirNext-Bold", size: 20))
                    .font(.custom(Constants.Fonts.cgoogla, size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                //  .padding(.horizontal)
                
            }
            
            
            HStack(spacing: 0) {
                TextField("https://", text: $urlText)
                    .padding()
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.6))
                
                Button(action: {
                    
                    if isValidURL(urlText){
                        print("Valid Url")
                        writeTag(text: urlText)
                    }else{
                        print("inValid Url")
                    }
                    
                    
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
    
    func isValidURL(_ urlString: String) -> Bool {
        return urlString.lowercased().hasPrefix("https://") || urlString.lowercased().hasPrefix("www.")
    }
}
