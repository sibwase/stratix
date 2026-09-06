// StreamOverlayDisconnectControls.swift
// Defines stream overlay disconnect controls for the Streaming / Overlay surface.
//

import SwiftUI

extension StreamOverlayDetailsPanel {
    /// Lists the controller shortcuts shown in the overlay help card.
    var shortcutRow: some View {
        infoCard(title: "Controller Shortcuts", systemImage: "button.horizontal.top.press") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("B: Close Overlay")
                    Text("L3 + R3 hold: Toggle Overlay")
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textPrimary)

                disconnectRow
            }
        }
    }

    /// Renders the disconnect affordance and attaches test-only focus when needed.
    var disconnectRow: some View {
        Button(action: onDisconnect) {
            FocusAwareView { isFocused in
                disconnectButtonLabel
                    .gamePassFocusRing(isFocused: isFocused, cornerRadius: 16)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .focused($focusedTarget, equals: StreamOverlayState.FocusTarget.disconnect)
        .defaultFocus($focusedTarget, StreamOverlayState.FocusTarget.disconnect)
        .accessibilityIdentifier("stream_disconnect_button")
    }

    /// Builds the visible label for the disconnect action button.
    var disconnectButtonLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 18, weight: .bold))
            Text("Disconnect Stream")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Spacer(minLength: 8)
            Text("A")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.red.opacity(0.16)))
                .overlay(Capsule().stroke(Color.red.opacity(0.45), lineWidth: 1))
        }
        .foregroundStyle(StratixTheme.Colors.textPrimary)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
