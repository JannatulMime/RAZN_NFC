//
//  AuthNFCDemoView.swift
//  RAZN NFC
//
//  Entry wrapper for the isolated NTAG213/215/216 password demo.
//

import SwiftUI

struct AuthNFCDemoView: View {
    var body: some View {
        AuthNFCHomeView()
    }
}

#Preview {
    NavigationStack {
        AuthNFCDemoView()
    }
}
