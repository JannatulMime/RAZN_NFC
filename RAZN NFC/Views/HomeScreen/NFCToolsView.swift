//
//  NFCToolsView.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

/// Reports the input section bottom edge in the key window's coordinate space.
private struct InputBottomReader: UIViewRepresentable {
    var keyboardTopY: CGFloat?
    var onBottomYChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> FrameReportingView {
        let view = FrameReportingView()
        view.onFrameInWindow = { frame in
            onBottomYChange(frame.maxY)
        }
        return view
    }

    func updateUIView(_ uiView: FrameReportingView, context: Context) {
        uiView.onFrameInWindow = { frame in
            onBottomYChange(frame.maxY)
        }
        // Re-measure when the keyboard frame changes.
        _ = keyboardTopY
        uiView.reportFrameInWindow()
    }
}

private final class FrameReportingView: UIView {
    var onFrameInWindow: ((CGRect) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        reportFrameInWindow()
    }

    func reportFrameInWindow() {
        guard let window else { return }
        onFrameInWindow?(convert(bounds, to: window))
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
    @State private var keyboardTopY: CGFloat?
    /// Input bottom Y in window space while the keyboard is hidden (not affected by `.offset`).
    @State private var inputBottomYAtRest: CGFloat = 0
    @State private var latestInputBottomY: CGFloat = 0

    private let iconSize: CGFloat = 76
    /// Space between the input section bottom and the top of the keyboard.
    private let keyboardGapAboveKeyboard: CGFloat = 0
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(iconSize), spacing: 12), count: 4)
    }

    /// Negative offset that places the input section `keyboardGapAboveKeyboard` above the keyboard.
    private var inputLift: CGFloat {
        guard let keyboardTop = keyboardTopY, inputBottomYAtRest > 0 else { return 0 }
        let targetBottomY = keyboardTop - keyboardGapAboveKeyboard
        return min(0, targetBottomY - inputBottomYAtRest)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background — never resizes or shifts when the keyboard appears.
            CustomBG()
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard, edges: .all)

            // Foreground content — keyboard avoidance is disabled so the view does NOT
            // shift as a whole. Everything above Explore lifts together via .offset below.
            VStack(spacing: 18) {
                VStack(spacing: 18) {
                    header
                    legacyHeroSection
                    hintText
                        .padding(.top, 40)
                    iconGrid
                    VStack(spacing: 18) {
                        inputSection
                            .background(
                                InputBottomReader(keyboardTopY: keyboardTopY) { bottomY in
                                    latestInputBottomY = bottomY
                                    // Only track the resting position; measuring after `.offset` would cancel the lift.
                                    guard keyboardTopY == nil else { return }
                                    if abs(bottomY - inputBottomYAtRest) > 0.5 {
                                        inputBottomYAtRest = bottomY
                                    }
                                }
                            )
                        writeButton
                    }
                    .padding(.horizontal, 20)
                }
                .offset(y: inputLift)
                .animation(.easeInOut(duration: 0.25), value: inputLift)

                discoverButton
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 40)
            .ignoresSafeArea(.keyboard, edges: .all)

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
            let topY = Self.keyboardTopInKeyWindow(from: notification)
            withAnimation(.easeInOut(duration: 0.25)) {
                if topY != nil, inputBottomYAtRest <= 0, latestInputBottomY > 0 {
                    inputBottomYAtRest = latestInputBottomY
                }
                keyboardTopY = topY
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                keyboardTopY = nil
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

    /// Converts the keyboard's end frame into the key window coordinate space (matches `InputBottomReader`).
    private static func keyboardTopInKeyWindow(from notification: Notification) -> CGFloat? {
        guard let screenFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return nil
        }
        let screenHeight = UIScreen.main.bounds.height
        guard screenFrame.minY < screenHeight - 1 else { return nil }

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow
        else {
            return screenFrame.minY
        }

        return window.convert(
            CGPoint(x: 0, y: screenFrame.minY),
            from: window.screen.coordinateSpace
        ).y
    }

    private var header: some View {
        ZStack {
            Text("WELCOME")
                .font(.custom(Constants.Fonts.interRegular, size: 12))
                .kerning(1.2)
                .foregroundStyle(.white)

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

                Button(action: {
                    InteractionFeedback.tap()
                    vm.openInstagram()
                }) {
                    Image("instagram_icon_toolbar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var legacyHeroSection: some View {
        Image("Razn_logo_home")
            .resizable()
            .scaledToFit()
            .frame(width: 130, height: 130)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .padding(.top,40)
    }

    private var hintText: some View {
        Text("Hold to save your link")
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
