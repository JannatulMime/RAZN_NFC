//
//  KeyboardLayoutLock.swift
//  RAZN NFC
//

import SwiftUI
import UIKit

private protocol HostingKeyboardSafeAreaDisabling {
    func disableHostingKeyboardSafeArea()
}

extension UIHostingController: HostingKeyboardSafeAreaDisabling {
    func disableHostingKeyboardSafeArea() {
        if #available(iOS 16.4, *) {
            safeAreaRegions.remove(.keyboard)
        }
    }
}

private final class KeyboardLayoutLockView: UIView {
    private var observers: [NSObjectProtocol] = []

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            apply()
            installObservers()
        } else {
            removeObservers()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        apply()
    }

    private func installObservers() {
        removeObservers()
        let names: [Notification.Name] = [
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification
        ]
        for name in names {
            observers.append(
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.apply()
                }
            )
        }
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func apply() {
        guard let root = window?.rootViewController else { return }
        visit(root)
    }

    private func visit(_ viewController: UIViewController) {
        (viewController as? HostingKeyboardSafeAreaDisabling)?.disableHostingKeyboardSafeArea()

        if let navigationController = viewController as? UINavigationController {
            navigationController.viewControllers.forEach { visit($0) }
        }

        viewController.children.forEach { visit($0) }

        if let presented = viewController.presentedViewController {
            visit(presented)
        }
    }

    deinit {
        removeObservers()
    }
}

private struct KeyboardLayoutLockViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardLayoutLockView {
        let view = KeyboardLayoutLockView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: KeyboardLayoutLockView, context: Context) {}
}

extension View {
    /// Prevents UIHostingController from shifting layout when the keyboard appears.
    func keyboardLayoutLocked() -> some View {
        background(KeyboardLayoutLockViewRepresentable())
    }
}
