//
//  TopBarView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI

struct TopBarView: View {
    var leftBtnIcon: String?
    var rightBtnIcon: String?
    
    var mainTitle: String
    
    var leftBtnTitle : String?
    var rightBtnTitle : String?
    
    
    
    var body: some View {
        
        
        HStack {
            
            if let leftIcon = leftBtnIcon {
                Image(leftIcon)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.white)
       
            }
            
            if let leftBtnTitle = leftBtnTitle{
                Text(leftBtnTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        
                    Spacer()
            
            Text(mainTitle)
                .font(.caption)
                .foregroundStyle(.white)
                .fontWeight(.bold)
            
            Spacer()
              
            if let rightIcon = rightBtnIcon {
                Image(rightIcon)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.white)
            }
            
            
            if let rightBtnTitle = rightBtnTitle{
                Text(rightBtnTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
                                   
        }   .padding()
            .padding(.horizontal)
            .background(.clear)
           // .background(Color.cyan)
                       
    }
}

#Preview {
    TopBarView(mainTitle: "NFC TOOLS", leftBtnTitle: "settingIcon", rightBtnTitle: "test")
//    TopBarView(leftIcon: "settingIcon", rightIcon: "shareIcon", title: "NFC TOOLS")
}
