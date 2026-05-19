//
//  NFCIconButton.swift
//  RAZN NFC
//

import SwiftUI

struct NFCIconButton: View {
    let icon: NFCIcon
    /// Saved link exists — tap selects/fills and shows press scaling.
    var hasLink: Bool = true
    /// Input field currently shows this icon’s saved link (after tap).
    var isSelected: Bool = false
    let onTap: () -> Void
    let onLongPress: () -> Void
    /// Immediate feedback only when a saved link exists (single tap / short touch).
    @State private var isTapPressed: Bool = false
    /// After hold threshold when there is no link — long-press feedback only, not tap.
    @State private var isLongPressHeld: Bool = false
    @State private var longPressHighlightTask: Task<Void, Never>?
    @State private var didLongPress: Bool = false
    private let cornerRadius: CGFloat = 22
    private static let longPressMinimumDuration: UInt64 = 400_000_000

    private var accentColor: Color {
        isSelected ? Color.brandBlue : .black
    }

    private var showPressEffect: Bool {
        (hasLink && isTapPressed) || (!hasLink && isLongPressHeld)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Spacer(minLength: 0)

                Image(systemName: icon.type.iconSymbolName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(accentColor)

                Text(icon.type.label)
                    .font(.custom(Constants.Fonts.interRegular, size: 12))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 9)
            .frame(width: 76, height: 76)

//            if icon.hasLink {
//                Circle()
//                    .fill(Color.brandBlue)
//                    .frame(width: 7, height: 7)
//                    .padding(.trailing, 6)
//                    .padding(.bottom, 6)
//            }
        }
        .frame(width: 76, height: 76)
        .contentShape(Rectangle())
        .scaleEffect(showPressEffect ? 0.88 : 1.0)
        .opacity(showPressEffect ? 0.75 : 1.0)
        .animation(.easeIn(duration: 0.08), value: showPressEffect)
        .onTapGesture {
            if didLongPress {
                didLongPress = false
                return
            }
            onTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isTapPressed = false
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    didLongPress = true
                    onLongPress()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
//                        isTapPressed = false
//                        didLongPress = false
                        
                        isTapPressed = false
                        isLongPressHeld = false
                        isLongPressHeld = false
                        didLongPress = false
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    
                    if hasLink {
                        if !isTapPressed {
                            withAnimation(.easeIn(duration: 0.08)) {
                                isTapPressed = true
                            }
                        }
                    } else if longPressHighlightTask == nil {
                        longPressHighlightTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: Self.longPressMinimumDuration)
                            guard !Task.isCancelled else { return }
                            withAnimation(.easeIn(duration: 0.08)) {
                                isLongPressHeld = true
                                
                            }
                        }
                    }
                }
                .onEnded { _ in
                    longPressHighlightTask?.cancel()
                    longPressHighlightTask = nil
                    
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isTapPressed = false
                        isLongPressHeld = false
                        isLongPressHeld = false
                        didLongPress = false
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(icon.type.label)
        .accessibilityHint("Tap to autofill, press and hold to edit")
    }

}

struct NFCIconButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NFCIconButton(icon: NFCIcon(type: .chat), onTap: {}, onLongPress: {})
                .padding()
        }
    }
}
