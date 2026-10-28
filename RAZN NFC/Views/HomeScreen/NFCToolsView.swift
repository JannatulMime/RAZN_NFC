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
    @State private var testerToggleTapCount = 0
    /// Start of the current multi-tap attempt. All taps must land within `multiTapWindow` of this.
    @State private var testerToggleWindowStart: Date?
    @State private var testerToastMessage: String?
    @State private var testerToastTask: Task<Void, Never>?
    @State private var isTesterModeEnabled = TesterModeManager.shared.isEnabled

    private let multiTapThreshold = 10
    private let multiTapWindow: TimeInterval = 5.0
    private let iconSize: CGFloat = 64
    private let gridSpacing: CGFloat = 30
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(iconSize), spacing: gridSpacing, alignment: .center), count: 4)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .ignoresSafeArea()
                .onTapGesture { dismissKeyboard() }

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
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            //.padding(.bottom, 40)
          //  .background(Color.green)
           

            if let message = vm.toastMessage ?? testerToastMessage {
                ToastView(message: message)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        // FAB must not sit in a full-screen ZStack layer — that steals taps from the
        // TESTER badge (and other controls) after tester mode is enabled mid-session.
        .overlay(alignment: .bottomTrailing) {
            if isTesterModeEnabled {
                TagManagerFloatingButton {
                    InteractionFeedback.tap()
                    path.append(.TagManager)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 72)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardLayoutLocked()
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
        .authNFCProductionWriteAlert($vm.writeAlert, onDismiss: vm.dismissWriteAlert)
        .onAppear {
            AppStoreReviewManager.shared.recordAppLaunch()
            isTesterModeEnabled = TesterModeManager.shared.isEnabled
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 10 taps within 5 seconds (from the first tap) toggles tester mode on or off.
    /// Used by both the logo and the TESTER badge so either control can deactivate.
    private func handleTesterToggleTap() {
        let now = Date()

        // Count only while still inside the window that started on the first tap.
        // If the window expired, start a fresh attempt from this tap.
        if let windowStart = testerToggleWindowStart,
           now.timeIntervalSince(windowStart) <= multiTapWindow {
            testerToggleTapCount += 1
        } else {
            testerToggleWindowStart = now
            testerToggleTapCount = 1
        }

        InteractionFeedback.tap()

        guard testerToggleTapCount >= multiTapThreshold else { return }

        testerToggleTapCount = 0
        testerToggleWindowStart = nil
        setTesterModeEnabled(!isTesterModeEnabled)
    }

    private func setTesterModeEnabled(_ enabled: Bool) {
        TesterModeManager.shared.setEnabled(enabled)
        testerToggleTapCount = 0
        testerToggleWindowStart = nil

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
                Button(action: handleTesterToggleTap) {
                    Image("razn_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .opacity(0.7)
                        .contentShape(Rectangle())
                        // Larger hit target — logo alone is easy to miss while tapping quickly.
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if isTesterModeEnabled {
                    Button(action: handleTesterToggleTap) {
                        TesterModeBadgeLabel()
                    }
                    .buttonStyle(.plain)
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

extension View {
    /// Titled production-write failure dialog. Dismiss does not retry the write.
    func authNFCProductionWriteAlert(
        _ alert: Binding<AuthNFCProductionWriteAlert?>,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        alert.wrappedValue = nil
                        onDismiss()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alert.wrappedValue?.message ?? "")
        }
    }
}

struct NFCToolsView_Previews: PreviewProvider {
    static var previews: some View {
        NFCToolsView(path: .constant([]))
    }
}

// MARK: - Tag Manager FAB

private struct TagManagerFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Tag Manager")
                    .font(.custom(Constants.Fonts.interBold, size: 14))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Color.brandBlue,
                in: Capsule(style: .continuous)
            )
            .shadow(color: Color.brandBlue.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tag Manager")
    }
}

// MARK: - Tester Mode Badge

private struct TesterModeBadgeLabel: View {
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
        // Generous hit target for fast multi-taps.
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
