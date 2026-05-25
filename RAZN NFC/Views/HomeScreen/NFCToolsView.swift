//
//  NFCToolsView.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

/// Identifiable wrapper so the share sheet is driven by `.sheet(item:)`.
/// This guarantees SwiftUI evaluates the sheet body with the items already
/// in place, avoiding the first-tap "empty share sheet" race that occurs
/// when using `.sheet(isPresented:)` together with a separate items state.
private struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct NFCToolsView: View {
    @Binding var path: [Screens]
    @StateObject private var vm = NFCViewModel()
    @State private var shareItems: ShareItems?

    private let iconSize: CGFloat = 64
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
//            CustomBG()
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                legacyHeroSection

                Spacer()
                inputSection
                    .padding(.horizontal, 20)
                writeButton
                    .padding(.horizontal, 20)
                    .padding(.bottom,40)

                iconGrid
                    .padding(.horizontal, 20)
                    .padding(.bottom,40)

                discoverButton
                    .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 40)

            if let message = vm.toastMessage {
                ToastView(message: message)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardLayoutLocked()
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .sheet(item: $vm.selectedSheet) { icon in
            EditLinkSheet(
                icon: icon,
                inputText: $vm.sheetInputText,
                isSaveEnabled: vm.isSheetSaveEnabled,
                onSave: vm.saveLink
            )
            .presentationDetents([.height(360)])
        }
        .sheet(item: $shareItems) { share in
            ShareActivityView(
                activityItems: share.items,
                excludedActivityTypes: [.assignToContact, .print],
                onComplete: { _ in }
            )
        }
        .alert("NFC", isPresented: $vm.showNFCAlert) {
            Button("OK") {
                vm.showNFCAlert = false
            }
        } message: {
            Text(vm.nfcAlertMessage)
        }
        .onAppear {
            AppStoreReviewManager.shared.recordAppLaunch()
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var header: some View {

            HStack {
                Button(action: {
                    InteractionFeedback.tap()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 44, height: 44)
                       // .background(Color.white.opacity(0.08))
                       // .clipShape(Circle())
                }

                Spacer()
              
                Image("razn_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                   .frame(width: 44, height: 44)
                
                Spacer()
                
                Button(action: {
                    InteractionFeedback.tap()
                    vm.openInstagram()
                }) {
                    Image("instagram_icon_toolbar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .opacity(0.4)
                       .frame(width: 44, height: 44)
//                        .background(Color.white.opacity(0.08))
//                        .clipShape(Circle())
                        
                }
                
            }

    }

    private var legacyHeroSection: some View {
        Image("razn_tag")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipped()
            .opacity(0.7)
    }

    private var hintText: some View {
        Text("Hold to save your link")
            .font(.custom(Constants.Fonts.interRegular, size: 13))
            .foregroundStyle(.white.opacity(0.6))
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(vm.icons) { icon in
                NFCIconButton(
                    icon: icon,
                    size: iconSize,
                    hasLink: icon.hasLink,
                    isSelected: vm.selectedIconType == icon.type,
                    onTap: {
                        vm.tap(icon: icon)
                    },
                    onLongPress: {
                        InteractionFeedback.longPress()
                        vm.longPress(icon: icon)
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inputSection: some View {
        InputSectionView(
            text: $vm.mainInputText,
            onPaste: {
                InteractionFeedback.tap()
                vm.pasteFromClipboard()
            },
            onClear: {
                InteractionFeedback.tap()
                vm.mainInputText = ""
            },
            pasteEnabled: true,
            showTrailingOverlayClear: true,
            onShareLink: { normalized in
                shareItems = ShareItems(items: [normalized])
            }
        )
        .animation(.easeInOut(duration: 0.2), value: vm.mainInputText)
        .padding(.top, 8)
    }

    private var writeButton: some View {
        Button(action: {
            guard vm.isWriteEnabled else { return }
            InteractionFeedback.tap()
            vm.writeNFC()
        }) {
            Text("Write")
                .font(.custom(Constants.Fonts.interBold, size: 20))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    vm.isWriteEnabled ? Color.brandBlue : Color(red: 0.46, green: 0.46, blue: 0.48),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(vm.isWriteEnabled)
        .animation(.easeInOut(duration: 0.2), value: vm.isWriteEnabled)
        .padding(.top, 2)
    }

    private var discoverButton: some View {
        Button("Explore") {
            InteractionFeedback.tap()
            vm.openDiscover()
        }
        .font(.custom(Constants.Fonts.interRegular, size: 14))
        .foregroundStyle(.white.opacity(0.7))
    }
}

struct NFCToolsView_Previews: PreviewProvider {
    static var previews: some View {
        NFCToolsView(path: .constant([]))
    }
}
