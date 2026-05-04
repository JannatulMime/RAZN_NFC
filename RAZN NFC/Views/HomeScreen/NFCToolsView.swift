//
//  NFCToolsView.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

private enum NFCToolsScrollMetrics {
    /// SwiftUI layout variance — treat as overflow only when clearly taller than viewport.
    static let scrollThresholdPadding: CGFloat = 2
}

private struct NFCToolsScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct NFCToolsView: View {
    @Binding var path: [Screens]
    @StateObject private var vm = NFCViewModel()
    @State private var showShare = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollContentHeight: CGFloat = 0

    private let iconSize: CGFloat = 76
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(iconSize), spacing: 12), count: 4)
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .bottom) {
                backgroundView

                GeometryReader { geometry in
                    let viewportHeight = max(0, geometry.size.height - keyboardHeight)
                    let contentOverflows = scrollContentHeight > viewportHeight + NFCToolsScrollMetrics.scrollThresholdPadding
                    /// `scrollDisabled` also blocks `ScrollViewReader.scrollTo`; keep scrolling enabled while the keyboard is up.
                    let userScrollEnabled = contentOverflows || keyboardHeight > 0

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            header
                            legacyHeroSection
                            hintText
                                .padding(.top,40)
                            iconGrid
                            inputSection
                                .id("main-input-section")
                                .padding(.horizontal, 20)
                            writeButton
                                .padding(.horizontal, 20)
                            discoverButton
                                .padding(.top,20)
                        }
                        .frame(minHeight: viewportHeight, alignment: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 40)
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear.preference(
                                    key: NFCToolsScrollContentHeightKey.self,
                                    value: contentGeo.size.height
                                )
                            }
                        )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDisabled(!userScrollEnabled)
                    .onPreferenceChange(NFCToolsScrollContentHeightKey.self) { scrollContentHeight = $0 }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: keyboardHeight)
                }

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
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return
                }

                let screenHeight = UIScreen.main.bounds.height
                let overlap = max(0, screenHeight - frame.origin.y)
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = overlap
                }

                if overlap > 0 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo("main-input-section", anchor: .bottom)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
        }
        .sheet(item: $vm.selectedSheet) { icon in
            EditLinkSheet(
                icon: icon,
                inputText: $vm.sheetInputText,
                isSaveEnabled: vm.isSheetSaveEnabled,
                onSave: vm.saveLink,
                onCancel: { vm.selectedSheet = nil }
            )
            .presentationDetents([.height(360)])
        }
        .sheet(isPresented: $showShare) {
            ShareActivityView(
                activityItems: [Constants.getAppLink(), "Check this link!"],
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
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var backgroundView: some View {
        CustomBG()
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

            Button(action: {
                InteractionFeedback.tap()
                showShare = true
            }) {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
    }

    private var legacyHeroSection: some View {
        VStack(spacing: 0) {
            Image("razuAppIcon")
                .resizable()
                .frame(width: 200, height: 200)
                //.offset(y: -70)
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
                    onTap: {
                        InteractionFeedback.tap()
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
            showTrailingOverlayClear: true
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
            Text("Write / \(vm.byteCount) bytes")
                .font(.custom(Constants.Fonts.interBold, size: 20))
                .foregroundStyle( Color.white )
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
