// StreamOverlayDisconnectControls.swift
// Defines stream overlay disconnect controls for the Streaming / Overlay surface.
//

import SwiftUI

extension StreamOverlayDetailsPanel {
    /// Lists the controller shortcuts shown in the overlay help card.
    var shortcutRow: some View {
        infoCard(title: "Controller Shortcuts", systemImage: "button.horizontal.top.press") {
            VStack(alignment: .leading, spacing: 6) {
                Text("A: Disconnect")
                Text("B: Close Overlay")
                Text("L3 + R3 hold: Toggle Overlay")
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(StratixTheme.Colors.textPrimary)
        }
    }

    /// Renders the disconnect affordance and attaches test-only focus when needed.
    var disconnectRow: some View {
        Button(action: onDisconnect) {
            FocusAwareView { isFocused in
                disconnectButtonLabel
                    .gamePassFocusRing(isFocused: isFocused, cornerRadius: 20)
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
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .foregroundStyle(StratixTheme.Colors.textPrimary)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .streamStatusPanelBackground(cornerRadius: 20)
    }

    /// Renders the small close-key hint shown alongside the shortcut row.
    var closeGlyph: some View {
        HStack(spacing: 8) {
            keycap("B")
            keycap("⏯")
            Text("Close")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textMuted)
        }
    }

    /// Renders a tiny capsule keycap used in shortcut and close hints.
    func keycap(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(StratixTheme.Colors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}
