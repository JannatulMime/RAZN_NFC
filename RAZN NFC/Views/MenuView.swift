//
//  MenuView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct MenuView: View {
    var body: some View {
        ZStack {
            Image("BG")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack {
                TopBarView(mainTitle: "write", leftBtnTitle: "Menu", rightBtnTitle: "edit")

                Button(action: {
                }) {
                    Image("addFieldButton")
                        .resizable()
                        .frame(width: 350, height: 90)
                }

                Button(action: {
                }) {
                    Image("writeButton")
                        .resizable()
                        .frame(width: 350, height: 90)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    MenuView()
}
