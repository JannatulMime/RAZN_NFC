//
//  AuthNFCInfoSheet.swift
//  RAZN NFC
//

import SwiftUI

struct AuthNFCInfoSheet: View {
    let topic: AuthNFCHelpTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.custom(Constants.Fonts.interRegular, size: 15))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
