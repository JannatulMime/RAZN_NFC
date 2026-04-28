//
//  InteractionFeedback.swift
//  RAZN NFC
//

import UIKit
import AudioToolbox

enum InteractionFeedback {
    // Toggle these from one place.
    static var isHapticEnabled: Bool = true
    static var isSoundEnabled: Bool = true

    // Built-in iOS system sound IDs; adjust if you prefer different tones.
    static var tapSoundID: SystemSoundID = 1104
    static var longPressSoundID: SystemSoundID = 1105

    static func tap() {
        play(haptic: .light, soundID: tapSoundID)
    }

    static func longPress() {
        play(haptic: .medium, soundID: longPressSoundID)
    }

    private static func play(haptic: UIImpactFeedbackGenerator.FeedbackStyle, soundID: SystemSoundID) {
        if isHapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: haptic)
            generator.prepare()
            generator.impactOccurred()
        }

        if isSoundEnabled {
            AudioServicesPlaySystemSound(soundID)
        }
    }
}
