//
//  URLFieldButtonView.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 21/8/25.
//

import SwiftUI

struct URLFieldButtonView: View {
    @EnvironmentObject var nfcWriteInfoVM: NFCWriteInfoVM
    var hasGlassBG : Bool = false
    
    var body: some View {
        ZStack {
            HStack {
                Image("url_icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .padding(.leading, 15)

                VStack(alignment: .leading) {
                    Text("URL/URI")
                        .foregroundColor(.white)
                        .font(.custom(Constants.Fonts.cgoogla, size: 25))
                        .lineLimit(1)
                    Text(nfcWriteInfoVM.getfullURL())
                        .foregroundColor(.white)
                        .font(.custom(Constants.Fonts.cgoogla, size: 18))
                        .lineLimit(1)
                }.offset(x: -15)

                Spacer()
            }
            .background {
                if hasGlassBG {
                    Image("glassBG")
                        .resizable()
                        .scaledToFill()
                }else{
                    Color.white.opacity(0.1)
                }

               
            }
        }
    }
}

#Preview {
    URLFieldButtonView()
        .environmentObject(NFCWriteInfoVM())
}
