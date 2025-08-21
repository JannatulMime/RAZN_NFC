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
    @Binding var path: [Screens]

    var body: some View {
        ZStack {
            CustomBG()

            mainSection
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    AddFieledView(path: .constant([]))
        .environmentObject(NFCWriteInfoVM())
}

extension AddFieledView {
    var mainSection: some View {
        VStack(spacing: 0) {
            TopBarView(mainTitle: "add fieled", leftBtnTitle: "write")

            Button(action: {
                path.append(.AddUrl)
            }) {
                URLFieldButtonView()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            }

            Spacer()
        }
    }
}
