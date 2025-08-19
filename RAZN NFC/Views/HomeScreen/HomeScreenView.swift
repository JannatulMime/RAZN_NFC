//
//  HomeScreenView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI

struct HomeScreenView: View {
    @StateObject var vm = HomeScreenVM()

    var body: some View {
        NavigationStack {
            ZStack {
                CustomBG()
                mainSection

                    .navigationDestination(isPresented: $vm.gotoWriteView, destination: {
                        MenuView()
                    })
            }
        }
    }
}

#Preview {
    HomeScreenView()
}

extension HomeScreenView {
    var mainSection: some View {
        VStack {
            TopBarView(leftBtnIcon: "settingIcon", rightBtnIcon: "shareIcon", mainTitle: "NFC TOOLS")

            Spacer()

            // Logo
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 160, height: 160)

                //  Text("razn")
                Image("razuAppIcon")
                    .resizable()
                    .frame(width: 150, height: 150)
            }

            Spacer()

            VStack(spacing: 0) {
//                Image("welcomeImgDesign")
//                    .resizable()
//                    .frame(width: 350, height: 200)

                Text("WELCOME")
                    .font(.custom(Constants.Fonts.cgoogla, size: 50))
                    .foregroundStyle(.white)
                    .kerning(2)

                Rectangle()
                    .fill(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 2)
                    .padding(.horizontal, 50)

                Text("IN  razn  NFC  Tools")
                    .font(.custom(Constants.Fonts.cgoogla, size: 20))
                    .foregroundStyle(.white)
                    .kerning(6)
                    .padding()
            }

            Spacer()

            Button(action: {
                vm.gotoWriteView = true

            }) {
                ZStack {
                    Image("glass_capsule")
                        .resizable()
                        .frame(width: 300, height: 80)

                    Text("W  R  I  T  E")
                        .font(.custom(Constants.Fonts.cgoogla, size: 20))
                        .foregroundStyle(.white.opacity(0.8))
                        .offset(y: 5)
                }
            }

            // Down Arrow
            Image("upArrow")
                .resizable()
                .frame(width: 80, height: 80)
        }
    }
}
