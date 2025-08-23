//
//  SwipeListDemo.swift
//  RAZN NFC
//
//  Created by Habibur_Periscope on 23/8/25.
//

import SwiftUI


struct SwipeListDemo: View {
    @State private var items = ["Alpha", "Beta", "Gamma", "Delta"]

    var body: some View {
        ZStack {
            // Whole-screen background (behind the list)
            Color.black.ignoresSafeArea()

            List {
                ForEach(items.indices, id: \.self) { i in
                    HStack {
                        Text(items[i])
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    // Per-row background
                    .listRowBackground(Color(white:0.1)) // dark gray row
                    // Optional: control row insets for “card” look
                    // .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .listStyle(.plain)
           // .scrollContentBackground(.hidden) // hide List’s default white bg
            .background(Color.red)          // keep our ZStack color visible
            .navigationTitle("Items")
        }
    }
}


#Preview {
    SwipeListDemo()
}
