// CloudLibrarySearchFieldLeadingAlignment.swift
// Implements the native tvOS-styled single-line linear character keyboard.
//

import Foundation
import SwiftUI

extension Notification.Name {
    static let librarySearchRequestKeyboard = Notification.Name("CloudLibraryLibrarySearchRequestKeyboard")
    static let librarySearchResignKeyboard = Notification.Name("CloudLibraryLibrarySearchResignKeyboard")
}

enum CloudLibrarySearchLayout {
    static let leadingOffset: CGFloat = 150
    static let searchFieldMaxWidth: CGFloat = 680
    static let searchFieldCornerRadius: CGFloat = 18
}

/// A native tvOS-styled single-line character strip keyboard with "123" / "ABC" mode toggle,
/// perfectly vertically centered in the row with the Home chip.
struct SingleLineCharacterKeyboard: View {
    @Binding var queryText: String
    var focusedTarget: FocusState<CloudLibraryLibraryScreen.LibraryFocusTarget?>.Binding
    var onRequestSideRailEntry: () -> Void
    var onRequestDownNavigation: () -> Void

    @State private var isNumbersMode: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let alphabet = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z"
    ]

    private static let digitsAndSymbols = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "-", "/", ":", ".", "&", "@", "'", "#"
    ]

    var currentKeys: [String] {
        isNumbersMode ? Self.digitsAndSymbols : Self.alphabet
    }

    var body: some View {
        HStack(spacing: 0) {
            // "123" / "ABC" Mode Toggle Button
            CharacterKeyButton(
                title: isNumbersMode ? "ABC" : "123",
                width: 58
            ) {
                isNumbersMode.toggle()
            }
            .focused(focusedTarget, equals: .letterKey("mode_toggle"))
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    onRequestSideRailEntry()
                case .right:
                    focusedTarget.wrappedValue = .letterKey("space")
                case .down:
                    onRequestDownNavigation()
                default:
                    break
                }
            }

            Spacer(minLength: 4)

            // Space Key (immediately after 123)
            CharacterKeyButton(title: "SPACE", width: 84) {
                if !queryText.isEmpty && !queryText.hasSuffix(" ") {
                    queryText.append(" ")
                }
            }
            .focused(focusedTarget, equals: .letterKey("space"))
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    focusedTarget.wrappedValue = .letterKey("mode_toggle")
                case .right:
                    if let firstChar = currentKeys.first {
                        focusedTarget.wrappedValue = .letterKey(firstChar)
                    }
                case .down:
                    onRequestDownNavigation()
                default:
                    break
                }
            }

            Spacer(minLength: 4)

            // Subtle vertical separator
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 1.5, height: 26)
                .padding(.horizontal, 4)

            Spacer(minLength: 4)

            // Characters Row (A-Z or 1-0 / symbols)
            ForEach(currentKeys, id: \.self) { char in
                CharacterKeyButton(title: char, width: 42) {
                    queryText.append(char)
                }
                .focused(focusedTarget, equals: .letterKey(char))
                .onMoveCommand { direction in
                    switch direction {
                    case .left where (!isNumbersMode && char == "A"):
                        focusedTarget.wrappedValue = .letterKey("space")
                    case .left where (isNumbersMode && char == currentKeys.first):
                        focusedTarget.wrappedValue = .letterKey("space")
                    case .down:
                        onRequestDownNavigation()
                    default:
                        break
                    }
                }

                if char != currentKeys.last {
                    Spacer(minLength: 4)
                }
            }

            Spacer(minLength: 4)

            // Clear & Backspace Key (with CLEAR text + icon, reaching right boundary)
            CharacterKeyButton(title: "CLEAR", icon: "delete.left.fill", width: 110) {
                if !queryText.isEmpty {
                    queryText.removeLast()
                }
            }
            .focused(focusedTarget, equals: .letterKey("backspace"))
            .onMoveCommand { direction in
                if direction == .down {
                    onRequestDownNavigation()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: StratixTheme.SideRail.collapsedBadgeHeight, alignment: .leading)
        .offset(y: -16)
        .animation(.easeInOut(duration: 0.18), value: isNumbersMode)
    }
}

/// A native tvOS-styled character key button with pure typographical focus (bold + scale, no background box, no underline).
struct CharacterKeyButton: View {
    let title: String
    var icon: String? = nil
    var width: CGFloat = 42
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            FocusAwareView { isFocused in
                HStack(spacing: 6) {
                    if !title.isEmpty {
                        Text(title)
                            .font(
                                StratixTypography.rounded(
                                    title.count > 1 ? 18 : 26,
                                    weight: isFocused ? .heavy : .semibold,
                                    dynamicTypeSize: dynamicTypeSize
                                )
                            )
                    }
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: isFocused ? .bold : .semibold))
                    }
                }
                .foregroundStyle(isFocused ? Color.white : Color.white.opacity(0.45))
                .frame(width: width, height: 46)
                .scaleEffect(isFocused ? 1.25 : 1.0)
                .shadow(
                    color: isFocused ? Color.white.opacity(0.65) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }
}