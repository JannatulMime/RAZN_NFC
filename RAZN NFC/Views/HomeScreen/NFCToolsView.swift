//
//  NFCToolsView.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

/// Captures the input section's natural bottom Y in screen coordinates.
private struct InputBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
    @State private var keyboardHeight: CGFloat = 0
    @State private var inputBottomY: CGFloat = 0

    private let iconSize: CGFloat = 76
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(iconSize), spacing: 12), count: 4)
    }

    /// Negative offset that lifts only the input section just above the keyboard.
    /// 0 when the keyboard is hidden or when the input is already above the keyboard.
    private var inputLift: CGFloat {
        guard keyboardHeight > 0, inputBottomY > 0 else { return 0 }
        let keyboardTopY = UIScreen.main.bounds.height - keyboardHeight
        let overlap = inputBottomY + 12 - keyboardTopY  // 12pt visual margin above keyboard
        return -max(0, overlap)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background — never resizes or shifts when the keyboard appears.
            CustomBG()
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard, edges: .all)

            // Foreground content — keyboard avoidance is disabled so the view does NOT
            // shift as a whole. Only the input section is lifted, via .offset below.
            VStack(spacing: 18) {
                header
                legacyHeroSection
                hintText
                    .padding(.top, 40)
                iconGrid
                inputSection
                    .padding(.horizontal, 20)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: InputBottomKey.self,
                                value: proxy.frame(in: .global).maxY
                            )
                        }
                    )
                    .offset(y: inputLift)
                    .animation(.easeInOut(duration: 0.25), value: inputLift)
                writeButton
                    .padding(.horizontal, 20)
                discoverButton
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .ignoresSafeArea(.keyboard, edges: .all)
            .onPreferenceChange(InputBottomKey.self) { inputBottomY = $0 }

            if let message = vm.toastMessage {
                ToastView(message: message)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let overlap = max(0, UIScreen.main.bounds.height - frame.origin.y)
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardHeight = overlap
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardHeight = 0
            }
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
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            Text("WELCOME")
                .font(.custom(Constants.Fonts.interRegular, size: 16))
                .kerning(1.2)
                .foregroundStyle(.white)

            Spacer()

//            #if DEBUG
//            Button {
//                AppStoreReviewManager.shared.resetForTesting()
//                AppStoreReviewManager.shared.requestStoreKitReviewForDebug()
//            } label: {
//                Image(systemName: "star.bubble")
//                    .foregroundStyle(.white.opacity(0.8))
//                    .frame(width: 44, height: 44)
//                    .background(Color.white.opacity(0.08))
//                    .clipShape(Circle())
//            }
//            #else
//            // Invisible balance for the leading gear button so "WELCOME" stays centered.
//            Color.clear.frame(width: 44, height: 44)
//            #endif
        }
        .padding(.horizontal, 24)
    }

    private var legacyHeroSection: some View {
        VStack(spacing: 0) {
            Image("razuAppIcon")
                .resizable()
                .frame(width: 200, height: 200)
                .padding(.bottom, -60)
        }
    }

    private var hintText: some View {
        Text("Press and hold to edit")
            .font(.custom(Constants.Fonts.interRegular, size: 13))
            .foregroundStyle(.white.opacity(0.6))
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(vm.icons) { icon in
                NFCIconButton(
                    icon: icon,
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
                .frame(width: iconSize)
            }
        }
        .padding(.horizontal, 20)
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
        Button("Discover") {
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
