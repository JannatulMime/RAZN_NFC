//
//  AddFieledView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddFieledView: View {
    @StateObject var vm = AddFieledVM()

    @EnvironmentObject var nfcWriteInfoVM: NFCWriteInfoVM

    var body: some View {
        ZStack {
            CustomBG()
            mainSection
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $vm.gotoURLFieldView, destination: {
            AddURLFieldView()
        })
    }
}

#Preview {
    AddFieledView()
        .environmentObject(NFCWriteInfoVM())
}

extension AddFieledView {
    var mainSection: some View {
        VStack {
            TopBarView(mainTitle: "add fieled", leftBtnTitle: "Write")

            Button(action: {
                vm.gotoURLFieldView = true
            }) {
                ZStack {
                    Image("glassBG")
                        .resizable()
                    // .scaledToFill()
                    HStack {
                        Image("url_icon")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .padding(.leading, 30)

                        VStack(alignment: .leading) {
                            Text("URL/URI")
                                .foregroundColor(.white)
                                .font(.custom(Constants.Fonts.cgoogla, size: 25))
                            Text(nfcWriteInfoVM.getfullURL())
                                .foregroundColor(.white)
                                .font(.custom(Constants.Fonts.cgoogla, size: 18))
                        }

                        Spacer()
                    }

                }.frame(height: 120)
                    .frame(maxWidth: .infinity)
            }

            Spacer()
        }
    }
}
