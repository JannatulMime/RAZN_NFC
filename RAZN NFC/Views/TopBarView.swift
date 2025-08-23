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

    var leftBtnTitle: String?
    var rightBtnTitle: String?
    
    var rightBtnAction: (() -> Void)?

    @Environment(\.dismiss) var dismiss

    var body: some View {
        
        ZStack {
            HStack {
                // Left side
                if let leftIcon = leftBtnIcon {
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(leftIcon)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                    
                }

                if let leftBtnTitle = leftBtnTitle {
                    Button(action: {
                        dismiss()
                    }) {
                        Image("back_icon")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)

                        Text(leftBtnTitle)
                            .font(.custom(Constants.Fonts.cgoogla, size: 18))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                // Right side
                if let rightIcon = rightBtnIcon {
                    
                    Button(action: {
                        if let rightBtnAction = rightBtnAction {
                            rightBtnAction()
                        }else{
                            dismiss()
                        }
                      
                    }) {
                        Image(rightIcon)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    }
                   
                }

                if let rightBtnTitle = rightBtnTitle {
                    Text(rightBtnTitle)
                        .font(.custom(Constants.Fonts.cgoogla, size: 18))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(Color.clear)
            .background(.clear)
            Text(mainTitle)
                .font(.custom(Constants.Fonts.cgoogla, size: 15))
                .foregroundStyle(.white)
                .fontWeight(.bold)
                .kerning(2)
        }
        
    }
}

#Preview {
    TopBarView( mainTitle: "NFC TOOLS",
                leftBtnTitle: "Back",
                rightBtnTitle: "Test")

}
