//
//  NFCViewModel.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

final class NFCViewModel: ObservableObject {
    @Published var icons: [NFCIcon] = NFCIconType.displayOrder.map { NFCIcon(type: $0) }
    @Published var mainInputText: String = ""
    @Published var selectedSheet: NFCIcon?
    @Published var sheetInputText: String = ""
    @Published var toastMessage: String?

    private let savedLinksKey = "nfc_tools_saved_links_v1"
    private var toastTask: Task<Void, Never>?

    init() {
        loadSavedLinks()
    }

    var byteCount: Int {
        mainInputText.utf8.count
    }

    func tap(icon: NFCIcon) {
        let value = icon.savedLink?.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkToFill = (value?.isEmpty == false) ? value : icon.type.placeholderURL
        mainInputText = linkToFill ?? ""
    }

    func longPress(icon: NFCIcon) {
        selectedSheet = icon
        sheetInputText = icon.savedLink ?? icon.type.placeholderURL
    }

    func saveLink() {
        guard let selectedSheet else { return }
        let link = sheetInputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let index = icons.firstIndex(where: { $0.id == selectedSheet.id }) else {
            self.selectedSheet = nil
            return
        }

        icons[index].savedLink = link.isEmpty ? nil : link
        persistSavedLinks()
        // Keep link persisted per icon, but do not force it
        // into the main input after saving from sheet.
        mainInputText = ""
        self.selectedSheet = nil
        showToast("Saved \(icons[index].type.label) link")
    }

    func writeNFC() {
        let payload = mainInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            showToast("Paste or choose a link first")
            return
        }

        // Simulated NFC write action for UI flow testing.
        showToast("NFC write complete (\(payload.utf8.count) bytes)")
    }

    func openDiscover() {
        guard let url = URL(string: "https://www.nfcforum.org/") else {
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

    private func persistSavedLinks() {
        let links = icons.reduce(into: [String: String]()) { result, icon in
            guard let value = icon.savedLink?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return }
            result[icon.type.rawValue] = value
        }

        UserDefaults.standard.set(links, forKey: savedLinksKey)
    }

    private func loadSavedLinks() {
        guard let links = UserDefaults.standard.dictionary(forKey: savedLinksKey) as? [String: String] else {
            return
        }

        icons = icons.map { icon in
            var updatedIcon = icon
            updatedIcon.savedLink = links[icon.type.rawValue]
            return updatedIcon
        }
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
