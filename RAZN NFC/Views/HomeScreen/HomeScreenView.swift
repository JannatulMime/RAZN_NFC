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

            
            Image("razuAppIcon")
                .resizable()
                .frame(width: 300, height: 300)
                .offset(y: -70)

           

            VStack(spacing: 0) {

                Text("WELCOME")
                    .font(.custom(Constants.Fonts.cgoogla, size: 40))
                    .foregroundStyle(.white)
                    .kerning(4)

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
            .offset(y: 20)

            Spacer()

            Button(action: {
                vm.gotoWriteView = true

            }) {
                ZStack {
                    Image("glass_capsule")
                        .resizable()
                        .frame(width: 300, height: 80)

                    Text("WRITE")
                        .font(.custom(Constants.Fonts.cgoogla, size: 20))
                        .foregroundStyle(.white.opacity(0.8))
                        .offset(y: 5)
                        .kerning(10)
                }
            }

            // Down Arrow
            Image("upArrow")
                .resizable()
                .frame(width: 80, height: 80)
        }
    }
}
