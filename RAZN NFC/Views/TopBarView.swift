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

    @Environment(\.dismiss) var dismiss

    var body: some View {
        HStack {
            if let leftIcon = leftBtnIcon {
                Image(leftIcon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
            }

            HStack {
                if let leftBtnTitle = leftBtnTitle {
                    Button(action: {
                        dismiss()

                    }) {
//                        Image(systemName: "chevron.left")
                        Image("back_icon")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .foregroundColor(.white)
                    }

                    Text(leftBtnTitle)
                       // .font(.caption)
                        .font(.custom(Constants.Fonts.cgoogla, size: 18))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            Text(mainTitle)
                .font(.custom(Constants.Fonts.cgoogla, size: 15))
                .foregroundStyle(.white)
                .fontWeight(.bold)

            Spacer()

            if let rightIcon = rightBtnIcon {
                Image(rightIcon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
            }

            if let rightBtnTitle = rightBtnTitle {
                Text(rightBtnTitle)
                    .font(.custom(Constants.Fonts.cgoogla, size: 18))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

        }.padding()
            .padding(.horizontal)
            .background(.clear)
         // .background(Color.cyan)
    }
}

#Preview {
    TopBarView(mainTitle: "NFC TOOLS", leftBtnTitle: "settingIcon", rightBtnTitle: "test")
//    TopBarView(leftIcon: "settingIcon", rightIcon: "shareIcon", title: "NFC TOOLS")
}
