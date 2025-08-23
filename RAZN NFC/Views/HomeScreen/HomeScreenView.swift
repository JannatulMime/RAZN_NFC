//
//  HomeScreenView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 7/8/25.
//

import SwiftUI


enum Screens: Hashable {
    case Home, Menu, AddField, AddUrl
}

struct RootView: View {
    @State private var path: [Screens] = []
   
    var body: some View {
        NavigationStack(path: $path) {
            HomeScreenView(path: $path)
            .navigationDestination(for: Screens.self) { screen in
                switch screen {
                case .Home: HomeScreenView(path: $path)
                case .Menu: MenuView(path: $path)
                case .AddField: AddFieledView(path: $path)
                case .AddUrl: AddURLFieldView(path: $path)
                }
            }
        } 

    }
    
    
}

struct HomeScreenView: View {
    
    @StateObject var vm = HomeScreenVM()
    @Binding var path: [Screens]
  
    @State private var showShare = false
   
    
    var body: some View {
        ZStack {
            mainSection
        }
        .background{
            CustomBG()
        }.sheet(isPresented: $showShare) {
            ShareActivityView(
                activityItems: [Constants.getAppLink(), "Check this link!"],
                excludedActivityTypes: [.assignToContact, .print],
                onComplete: { completed in
                   // print("Shared:", completed)
                }
            )
        }

    }
}

#Preview {
    HomeScreenView(path: .constant([]))
}

extension HomeScreenView {
    var mainSection: some View {
        VStack {
            TopBarView(leftBtnIcon: "settingIcon", rightBtnIcon: "shareIcon", mainTitle: "NFC TOOLS", rightBtnAction: {
                print("U>> pressed right -- ")
                showShare = true
            })

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
            .offset(y: -10)

            Spacer()

            Button(action: {
                path.append(.Menu)

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
