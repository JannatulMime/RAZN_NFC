//
//  ExtraView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 10/8/25.
//

import SwiftUI

struct ExtraView: View {
    
    
    @State private var urlText = "www.example.it"
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button("< back") { }
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("add field")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Button("OK") { }
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.black)
            
            // Header section
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text("URL/URI")
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Insert label
            HStack {
                Text("insert  l’URL")
                    .font(.system(size: 18, weight: .medium))
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color.white)
            
            // HTTPS + Edit
            HStack(spacing: 0) {
                Text("https://")
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("edit") { }
                    .foregroundColor(.white)
                    .frame(width: 80)
                    .padding(.vertical, 12)
                    .background(Color.gray)
            }
            
            
            
            
            // URL box + curly bracket button
            HStack(spacing: 8) {
                TextField("", text: $urlText)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .kerning(5)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.black, lineWidth: 1)
                    )
                
                Button("{ ... }") { }
                    .foregroundColor(.black)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            
            Spacer()
            
            
            Spacer()
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        
      
    }

    
    
    
    }



   
#Preview {
    ExtraView()
}
