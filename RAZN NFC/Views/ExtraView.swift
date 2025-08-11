//
//  ExtraView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 10/8/25.
//

import SwiftUI

struct ExtraView: View {
    
        @State private var urlText: String = ""

        var body: some View {
            VStack(spacing: 16) {
                
                // Header with icon and title
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.white)
                    Text("URL/URI")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color.black)
                
                // Insert label
                Text("insert l’URL")
                    .font(.custom("AvenirNext-Bold", size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // TextField with "https://" and edit button
                HStack(spacing: 0) {
                    TextField("https://", text: $urlText)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                    
                    Button(action: {
                        print("Edit tapped")
                    }) {
                        Text("edit")
                            .foregroundColor(.white)
                            .frame(width: 60)
                            .padding()
                            .background(Color.gray)
                    }
                }
                .cornerRadius(5)
                .padding(.horizontal)
                
                // Rounded example URL with {...} button
                HStack {
                    Text("www.example.it")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black, lineWidth: 1)
                        )
                    
                    Button(action: {
                        print("More tapped")
                    }) {
                        Text("{ ... }")
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }


#Preview {
    ExtraView()
}
