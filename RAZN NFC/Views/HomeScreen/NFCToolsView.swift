//
//  NFCToolsView.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

struct NFCToolsView: View {
    @Binding var path: [Screens]
    @StateObject private var vm = NFCViewModel()
    @State private var showShare = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    legacyHeroSection
                    hintText
                    iconGrid
                    inputSection
                    writeButton
                    discoverButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 90)
            }

            if let message = vm.toastMessage {
                ToastView(message: message)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $vm.selectedSheet) { icon in
            EditLinkSheet(
                icon: icon,
                inputText: $vm.sheetInputText,
                onSave: vm.saveLink,
                onCancel: { vm.selectedSheet = nil }
            )
        }
        .sheet(isPresented: $showShare) {
            ShareActivityView(
                activityItems: [Constants.getAppLink(), "Check this link!"],
                excludedActivityTypes: [.assignToContact, .print],
                onComplete: { _ in }
            )
        }
    }

    private var backgroundView: some View {
        CustomBG()
    }

    private var header: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            Text("NFC TOOLS")
                .font(.headline.weight(.bold))
                .kerning(1.2)
                .foregroundStyle(.white)

            Spacer()

            Button(action: { showShare = true }) {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    private var legacyHeroSection: some View {
        VStack(spacing: 0) {
            Image("razuAppIcon")
                .resizable()
                .frame(width: 300, height: 300)
                .offset(y: -70)
                .padding(.bottom, -60)
        }
    }

    private var hintText: some View {
        Text("Press and hold to edit")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(vm.icons) { icon in
                NFCIconButton(
                    icon: icon,
                    onTap: { vm.tap(icon: icon) },
                    onLongPress: { vm.longPress(icon: icon) }
                )
            }
        }
    }

    private var inputSection: some View {
        InputSectionView(text: $vm.mainInputText) {
            vm.mainInputText = UIPasteboard.general.string ?? ""
        }
        .padding(.top, 8)
    }

    private var writeButton: some View {
        Button(action: vm.writeNFC) {
            Text("Write / \(vm.byteCount) bytes")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "#367CFF") ?? .blue)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 2)
    }

    private var discoverButton: some View {
        Button("Discover more about NFC", action: vm.openDiscover)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
    }
}

struct NFCToolsView_Previews: PreviewProvider {
    static var previews: some View {
        NFCToolsView(path: .constant([]))
    }
}
