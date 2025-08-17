//
//  ExtraView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 10/8/25.
//

import SwiftUI

struct ExtraView: View {
    
    
    var body: some View {
        
        
        Button(action: {
            //vm.gotoURLFieldView = true
        }) {
            ZStack {
                Image("glassBG")
                    .resizable()
                    .scaledToFill()
                    .clipped()
                
                HStack(spacing: 16) {
                    // Icon
                    Image("url_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40) // balanced size
                        .foregroundColor(.white)
                    
                    // Title + Subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL/URI")
                            .font(.custom(Constants.Fonts.cgoogla, size: 22))
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        
                        Text("add field URL")
                            .font(.custom(Constants.Fonts.cgoogla, size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity) // full width
            .cornerRadius(12)
        }
        
    }
}


#Preview {
    ExtraView()
}
