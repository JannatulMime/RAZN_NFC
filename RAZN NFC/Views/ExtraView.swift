//
//  ExtraView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 10/8/25.
//

import SwiftUI

    struct ExtraView: View {
        
    @State private var urlText = ""
                    
                    var body: some View {
                        HStack {
                            TextField("www.example.it", text: $urlText)
                                .font(.system(size: 20))
                                .kerning(5)
                                .foregroundStyle(.gray) // placeholder & typed text color
                                .padding(.vertical, 8)
                                .padding(.horizontal, 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .disableAutocorrection(true) // cleaner URL typing
                                .textInputAutocapitalization(.never)
                            
                            Spacer()
                            
                            Text("{ ... }")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        .padding(.horizontal)
                    }
                }

//
//HStack {
//    Text("www.example.it")
//        .font(.system(size: 20))
//     
//        .tint(.gray)
//        .kerning(5)
//    
//        .padding(.vertical, 8)
//        .padding(.horizontal, 40)
//        .overlay(
//            RoundedRectangle(cornerRadius: 25)
//                .stroke(Color.black, lineWidth: 1)
//               
//        )
//    Spacer()
//    
//    
//    Text("{ ... }")
//        .foregroundColor(.gray)
//        .padding()
//    
//}.padding(.horizontal)
//


#Preview {
    ExtraView()
}
