//
//  ExtraView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 10/8/25.
//

import SwiftUI


    struct ExtraView: View {
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            VStack {
                // Custom Back Button at top-left
                HStack {
                    Button(action: {
                        dismiss() // Go back
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                            Text("Back")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
                Text("Menu View")
                    .foregroundColor(.white)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
        }
    }


   
#Preview {
    ExtraView()
}
