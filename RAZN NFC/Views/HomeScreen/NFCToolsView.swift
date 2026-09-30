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
    @State private var logoTapCount = 0
    @State private var lastLogoTapTime: Date?
    @State private var testerBadgeTapCount = 0
    @State private var lastTesterBadgeTapTime: Date?
    @State private var testerToastMessage: String?
    @State private var testerToastTask: Task<Void, Never>?
    @State private var isTesterModeEnabled = TesterModeManager.shared.isEnabled

    private let multiTapThreshold = 5
    private let multiTapWindow: TimeInterval = 10.0
    private let iconSize: CGFloat = 64
    private let gridSpacing: CGFloat = 30
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(iconSize), spacing: gridSpacing, alignment: .center), count: 4)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                   // .padding(.horizontal, 12)
                Spacer()
              legacyHeroSection
                    .allowsHitTesting(false)
            
                Spacer(minLength: 0)

                inputSection
                    .padding(.horizontal, 5)
                   
                writeButton
                    .padding(.top,30)
                    .padding(.bottom, 80)
                    .padding(.horizontal, 5)

                iconGrid
                    .padding(.bottom, 70)
                    .padding(.horizontal, 5)
                

                discoverButton
                    .padding(.bottom, 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            //.padding(.bottom, 40)
          //  .background(Color.green)
           

            if let message = vm.toastMessage ?? testerToastMessage {
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
            isTesterModeEnabled = TesterModeManager.shared.isEnabled
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleLogoTap() {
        guard !isTesterModeEnabled else { return }
        guard registerMultiTap(count: &logoTapCount, lastTapTime: &lastLogoTapTime) else { return }
        setTesterModeEnabled(true)
    }

    private func handleTesterBadgeTap() {
        guard isTesterModeEnabled else { return }
        guard registerMultiTap(count: &testerBadgeTapCount, lastTapTime: &lastTesterBadgeTapTime) else { return }
        setTesterModeEnabled(false)
    }

    private func registerMultiTap(count: inout Int, lastTapTime: inout Date?) -> Bool {
        let now = Date()

        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) > multiTapWindow {
            count = 0
        }

        count += 1
        lastTapTime = now

        guard count >= multiTapThreshold else { return false }

        count = 0
        lastTapTime = nil
        return true
    }

    private func setTesterModeEnabled(_ enabled: Bool) {
        TesterModeManager.shared.setEnabled(enabled)
        logoTapCount = 0
        lastLogoTapTime = nil
        testerBadgeTapCount = 0
        lastTesterBadgeTapTime = nil

        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            isTesterModeEnabled = enabled
        }
        showTesterToast(enabled ? "Tester Mode Enabled" : "Tester Mode Disabled")
    }

    private func showTesterToast(_ message: String) {
        testerToastTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            testerToastMessage = message
        }

        testerToastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    testerToastMessage = nil
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
//            Button(action: {
//                InteractionFeedback.tap()
//            }) {
//                Image(systemName: "gearshape.fill")
//                    .resizable()
//                  //  .opacity(0.4)
//                    .foregroundStyle(.white.opacity(0.4))
//                    .frame(width: 20, height: 20)
//                    
//                    .scaledToFit()
//            }.buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Image("razn_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .opacity(0.7)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleLogoTap()
                    }

                if isTesterModeEnabled {
                    TesterModeBadge(onTap: handleTesterBadgeTap)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }

            Spacer()

//            Button(action: {
//                InteractionFeedback.tap()
//                vm.openInstagram()
//            }) {
//                Image("instagram_icon_toolbar")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 20, height: 20)
//                    .opacity(0.4)
//                   // .foregroundStyle(.white.opacity(0.4))
//                   // .frame(width: 44, height: 44)
//            }.buttonStyle(.plain)
        }
        ///.frame(height: 70)
      
    }

    private var legacyHeroSection: some View {
        Image("razn_tag")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 250)
            .clipped()
            .opacity(0.9)
    }

    private var hintText: some View {
        Text("Hold to save your link")
            .font(.custom(Constants.Fonts.interRegular, size: 13))
            .foregroundStyle(.white.opacity(0.6))
    }

    private var iconGrid: some View {
        LazyVGrid(columns: gridColumns, alignment: .center, spacing: gridSpacing) {
            ForEach(vm.icons) { icon in
                NFCIconButton(
                    icon: icon,
                    size: iconSize,
                    hasLink: icon.hasLink,
                    isSelected: vm.selectedIconType == icon.type,
                    onTap: { vm.tap(icon: icon) },
                    onDoubleTap: { vm.doubleTap(icon: icon) },
                    onLongPress: {
                        InteractionFeedback.longPress()
                        vm.longPress(icon: icon)
                    }
                )
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
        .foregroundStyle(.white.opacity(0.3))
    }
}

struct NFCToolsView_Previews: PreviewProvider {
    static var previews: some View {
        NFCToolsView(path: .constant([]))
    }
}

// MARK: - Tester Mode Badge

private struct TesterModeBadge: View {
    let onTap: () -> Void
    @State private var glow = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.brandBlue)
                .frame(width: 5, height: 5)
                .shadow(color: Color.brandBlue.opacity(glow ? 0.9 : 0.35), radius: glow ? 5 : 2)

            Text("TESTER")
                .font(.custom(Constants.Fonts.interBold, size: 9))
                .tracking(1.1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.brandBlue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandBlue.opacity(0.22),
                            Color.brandBlue.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.brandBlue.opacity(0.75),
                                    Color.brandBlue.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.brandBlue.opacity(0.25), radius: 8, y: 2)
        }
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
