//
//  NFCViewModel.swift
//  RAZN NFC
//

import SwiftUI
import UIKit
import Combine

final class NFCViewModel: ObservableObject {
    @Published var icons: [NFCIcon]
    @Published var mainInputText: String = ""
    /// Which grid icon’s saved link is reflected in the input field (set on tap when that slot has a link).
    @Published var selectedIconType: NFCIconType?
    @Published var selectedSheet: NFCIcon?
    @Published var sheetInputText: String = ""
    @Published var toastMessage: String?
    @Published var nfcAlertMessage: String = ""
    @Published var showNFCAlert: Bool = false

    private var toastTask: Task<Void, Never>?
    private let nfcReader = NFCReader()
    private var cancellables = Set<AnyCancellable>()

    init() {
        icons = NFCIconType.displayOrder.map { type in
            let key = "nfc_link_\(type.rawValue)"
            let saved = UserDefaults.standard.string(forKey: key)
            return NFCIcon(type: type, savedLink: saved)
        }
        bindNFCAlerts()
        bindSelectionToInput()
    }

    var byteCount: Int {
        mainInputText.utf8.count
    }

    var isWriteEnabled: Bool {
        let t = mainInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty
    }

    var isSheetSaveEnabled: Bool {
        let t = sheetInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty
    }

    func tap(icon: NFCIcon) {
        let latestIcon = icons.first(where: { $0.id == icon.id })
            ?? icons.first(where: { $0.type == icon.type })
            ?? icon
        guard latestIcon.hasLink else { return }

        InteractionFeedback.tap()
        let value = latestIcon.savedLink?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalized = normalizeURLInput(value)
        selectedIconType = latestIcon.type
        mainInputText = normalized
        if !normalized.isEmpty {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    func longPress(icon: NFCIcon) {
        selectedSheet = icon
        sheetInputText = icon.savedLink ?? ""
    }

    func saveLink() {
        guard let type = selectedSheet?.type else { return }
        let trimmed = sheetInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "nfc_link_\(type.rawValue)"

        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }

        let savedLink = trimmed.isEmpty ? nil : trimmed
        icons = icons.map { icon in
            guard icon.type == type else { return icon }
            var updated = icon
            updated.savedLink = savedLink
            return updated
        }

        if savedLink == nil, selectedIconType == type {
            selectedIconType = nil
        }

        showToast("Link saved!")
        // Delay sheet dismissal slightly so the same tap cannot pass through
        // and accidentally trigger controls in the underlying view.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            self?.selectedSheet = nil
        }
    }

    func pasteFromClipboard() {
        let pasted = UIPasteboard.general.string ?? ""
        mainInputText = pasted
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    func writeNFC() {
        let payload = normalizeURLInput(mainInputText)
        guard !payload.isEmpty else {
            showToast("Paste or choose a link first")
            return
        }

        nfcReader.write(payload) { [weak self] isSuccess in
            guard let self else { return }
            if isSuccess {
                self.showToast("NFC write complete (\(payload.utf8.count) bytes)")
            } else {
                self.showToast("NFC write failed")
            }
        }
    }

    func openDiscover() {
        guard let url = URL(string: "https://razn.it/") else {
            showToast("Unable to open discover link")
            return
        }
        UIApplication.shared.open(url)
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation {
            toastMessage = nil
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = message
        }

        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.toastMessage = nil
                }
            }
        }
    }

    private func bindSelectionToInput() {
        $mainInputText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                guard let self, let sel = self.selectedIconType else { return }
                guard let icon = self.icons.first(where: { $0.type == sel }) else {
                    self.selectedIconType = nil
                    return
                }
                let a = self.normalizeURLInput(text)
                let b = self.normalizeURLInput(icon.savedLink)
                if a != b {
                    self.selectedIconType = nil
                }
            }
            .store(in: &cancellables)
    }

    private func bindNFCAlerts() {
        nfcReader.$alertMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.nfcAlertMessage = message
            }
            .store(in: &cancellables)

        nfcReader.$showAlert
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow in
                self?.showNFCAlert = shouldShow
            }
            .store(in: &cancellables)
    }

    private func normalizeURLInput(_ input: String?) -> String {
        let trimmed = input?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return ""
        }

        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("http://") ||
            lowercased.hasPrefix("https://") ||
            lowercased.hasPrefix("www.") {
            return trimmed
        }

        return "https://\(trimmed)"
    }
}

struct NFCViewModel_Previews: PreviewProvider {
    static var previews: some View {
        let vm = NFCViewModel()
        vm.mainInputText = "https://example.com"
        return VStack(alignment: .leading, spacing: 8) {
            Text("Icons: \(vm.icons.count)")
            Text("Bytes: \(vm.byteCount)")
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
}
