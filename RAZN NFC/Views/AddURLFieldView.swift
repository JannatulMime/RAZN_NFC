//
//  AddURLFieldView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct AddURLFieldView: View {
    @EnvironmentObject var nfcWriteInfoVM: NFCWriteInfoVM
    @State var goMenuView: Bool = false

    var body: some View {
        ZStack {
            CustomBG()

            VStack(spacing: 0) {
                TopBarView(mainTitle: "add fieled",
                           leftBtnTitle: "back", rightBtnTitle: "OK")
                // .background(Color(hex: "#292929"))

                urlSection

                textfieldAndButtton

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $goMenuView, destination: {
            MenuView()
        })
    }
}

#Preview {
    AddURLFieldView()
        .environmentObject(NFCWriteInfoVM())
}

extension AddURLFieldView {
    var urlSection: some View {
        HStack(spacing: 0) {
            Image("url_icon")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            Text("URL/URI")
                .foregroundStyle(.white)
                .font(.custom(Constants.Fonts.cgoogla, size: 20))

            Spacer()
        }

        .padding(.leading)
        .padding(.horizontal)
        .background(Color.black.opacity(0.7))
    }

    var textfieldAndButtton: some View {
        VStack {
            HStack(spacing: 10) {
                Text("insert")
                    .font(.custom(Constants.Fonts.cgoogla, size: 15))
                    .kerning(3)
                    // .padding()
                    .padding(.leading)

                Text("l ’ URL")
                    .font(.custom(Constants.Fonts.cgoogla, size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                //  .padding(.horizontal)

            }.padding()

            HStack(spacing: 0) {
                TextField("https://", text: $nfcWriteInfoVM.insertedURLPrefix)
                    .font(.custom(Constants.Fonts.cgoogla, size: 18))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.lightGray)
                    .lineLimit(1)

                Button(action: {
                    goMenuView = true

                }) {
                    Text("edit")
                        .foregroundColor(.white)
                        .font(.custom(Constants.Fonts.cgoogla, size: 15))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(Color.darkGray)
                }
            }
            .cornerRadius(5)

            // Rounded example URL with {...} button
            HStack {
                ZStack(alignment: .center) {
                    TextField(
                        "",
                        text: $nfcWriteInfoVM.insertedURL,
                        prompt: Text(verbatim: "www.razn.it").foregroundColor(.gray)
                    )
                    .font(.custom(Constants.Fonts.cgoogla, size: 20))
                    .kerning(3)
                    .foregroundStyle(.gray)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 25)
                    .multilineTextAlignment(.leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .tint(.gray)
                    .lineLimit(1)
                }

                Spacer()

                Text("{ ... }")
                    .foregroundStyle(.gray)
                    .padding()
            }
            .padding(.horizontal)
        }
        .background(.white.opacity(0.9))
        .padding(.horizontal)
    }
}
