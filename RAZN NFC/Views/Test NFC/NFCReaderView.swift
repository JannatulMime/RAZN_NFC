//
//  NFCReaderView.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 10/8/25.
//

import SwiftUI

struct NFCReaderView: View {
    
    @StateObject private var nfcReader = NFCReader()
    
    var body: some View {
        Text("Scan")
            .onTapGesture {
                scanTag()
            }
        
        Text("Write")
            .onTapGesture {
                writeTag()
            }
        
    }
    
    
    private func scanTag() {
        nfcReader.scan { payload in
            print("U>> Scaned data \(payload)")
        }
        
        
    }
    
    private func writeTag() {
        nfcReader.write("hello world written", completion: { isSuccess in
            print("U>> write isSuccess \(isSuccess)")
        })
        
        
    }
}

#Preview {
    NFCReaderView()
}
