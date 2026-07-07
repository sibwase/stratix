// StreamReconnectStatusBanner.swift
// Auto-reconnect status chip aligned with the stream launch Cancel row.
//

import SwiftUI

enum StreamStatusChipStyle {
    /// Shared inset for Connected badge, compact stats HUD, and overlay chips.
    static let overlayEdgeInset: CGFloat = 20
    static let fill = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.12)
    static let strokeWidth: CGFloat = 1
    static let statsHUDScrim = Color.black.opacity(0.58)
    static let statsHUDFill = Color.white.opacity(0.10)
    static let statsHUDStroke = Color.white.opacity(0.16)
}

extension View {
    func streamStatusCapsuleBackground() -> some View {
        background(
            Capsule(style: .continuous)
                .fill(StreamStatusChipStyle.fill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(StreamStatusChipStyle.stroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }

    func streamStatusPanelBackground(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(StreamStatusChipStyle.stroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }

    func streamStatusStatsHUDPanelBackground(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.statsHUDScrim)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StreamStatusChipStyle.statsHUDFill)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(StreamStatusChipStyle.statsHUDStroke, lineWidth: StreamStatusChipStyle.strokeWidth)
        )
    }

}

struct StreamReconnectStatusBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(StratixTheme.Colors.textPrimary)
            Text("Reconnecting…")
                .font(.callout.bold())
                .foregroundStyle(StratixTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .streamStatusCapsuleBackground()
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityIdentifier("stream_reconnect_status_banner")
        .accessibilityLabel("Reconnecting")
    }
}