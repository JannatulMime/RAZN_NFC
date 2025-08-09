//
//  UpperView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI

struct UpperView: View {
    var body: some View {
        
        
        HStack {
                                   // Settings Icon
                                   Image("settingIcon")
                                       .resizable()
                                       .frame(width: 40, height: 40)
                                       .foregroundColor(.white)
                                       .padding()
       
                                   Spacer()
       
                                   // Share Icon
                                   Image("shareIcon")
                                       .resizable()
                                       .frame(width: 30, height: 40)
                                       .foregroundColor(.white)
                                       .padding()
        }.background(.black)
                       
    }
}

#Preview {
    UpperView()
}
