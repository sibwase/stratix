// StreamCompactStatsHUD.swift
// Defines stream compact stats hud for the Streaming / Diagnostics surface.
//

import SwiftUI
import StratixModels
import StreamingCore

/// Shows compact runtime, network, and renderer stats over the active stream.
struct StreamCompactStatsHUD: View {
    let session: any StreamingSessionFacade
    let surfaceModel: StreamSurfaceModel
    let showStatsHUD: Bool
    let statsHUDPosition: String
    let overlayVisible: Bool
    let runtimeProbeValue: String
    let showRuntimeStatusProbe: Bool

    /// Renders the HUD only when stream state or diagnostics require it.
    var body: some View {
        if shouldShowHUD {
            hudContainer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    /// Determines whether the compact HUD should be visible for the current stream state.
    private var shouldShowHUD: Bool {
        !overlayVisible &&
        showStatsHUD &&
        session.lifecycle == .connected
    }

    /// Mirrors the Connected badge layout so the panel's trailing edge lines up exactly.
    @ViewBuilder
    private var hudContainer: some View {
        switch statsHUDPosition {
        case "bottomLeft":
            VStack {
                Spacer(minLength: 0)
                HStack {
                    hudStrip
                    Spacer(minLength: 0)
                }
                .padding(.leading, StreamStatusChipStyle.overlayEdgeInset)
                .padding(.bottom, StreamStatusChipStyle.overlayEdgeInset)
            }
        case "topLeft":
            VStack {
                HStack {
                    hudStrip
                    Spacer(minLength: 0)
                }
                .padding(.leading, StreamStatusChipStyle.overlayEdgeInset)
                .padding(.top, StreamStatusChipStyle.overlayEdgeInset)
                Spacer(minLength: 0)
            }
        case "bottomRight":
            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    hudStrip
                }
                .padding(.trailing, StreamStatusChipStyle.overlayEdgeInset)
                .padding(.bottom, StreamStatusChipStyle.overlayEdgeInset)
            }
        case "topRight", _:
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    hudStrip
                }
                .padding(.trailing, StreamStatusChipStyle.overlayEdgeInset)
                .padding(.top, StreamStatusChipStyle.overlayEdgeInset)
                Spacer(minLength: 0)
            }
        }
    }

    /// Builds the compact multi-row stats strip shown in the HUD.
    private var hudStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            hudMetricsRow(
                ("Frame Rate", formattedFrameRate),
                ("Bitrate", formattedBitrate),
                ("RTT", formattedRTT),
                ("Packet Loss", formattedPacketLoss)
            )
            hudMetricsRow(
                ("Input", rendererInputResolutionText),
                ("Output", rendererOutputResolutionText),
                ("Upscaler", surfaceModel.activeRendererMode),
                ("Render Delay", formattedRenderDelay)
            )
            if !rendererDiagnosticsItems.isEmpty {
                hudDynamicRow(rendererDiagnosticsItems)
            }
            if let rungSummary = surfaceModel.rendererRungSummaryText {
                Text(rungSummary)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let lastError = surfaceModel.lastError {
                Text("Last renderer error: \(shortenedError(lastError))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showRuntimeStatusProbe {
                Text(runtimeProbeValue)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(StratixTheme.Colors.textPrimary.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityValue(runtimeProbeValue)
                    .accessibilityIdentifier("stream_runtime_probe")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .streamStatusStatsHUDPanelBackground(cornerRadius: 12)
        .foregroundStyle(StratixTheme.Colors.textPrimary)
    }

    /// Renders one fixed row of key/value diagnostics cells without per-render array allocation.
    private func hudMetricsRow(
        _ first: (String, String),
        _ second: (String, String),
        _ third: (String, String),
        _ fourth: (String, String)
    ) -> some View {
        HStack(spacing: 12) {
            hudItem(first.0, first.1)
            hudItem(second.0, second.1)
            hudItem(third.0, third.1)
            hudItem(fourth.0, fourth.1)
        }
    }

    /// Renders a variable-length diagnostics row keyed by stable metric labels.
    private func hudDynamicRow(_ items: [(String, String)]) -> some View {
        HStack(spacing: 12) {
            ForEach(items, id: \.0) { item in
                hudItem(item.0, item.1)
            }
        }
    }

    private var formattedFrameRate: String {
        session.stats.framesPerSecond.map { String(format: "%.0f fps", $0) } ?? "—"
    }

    private var formattedBitrate: String {
        session.stats.bitrateKbps.map { "\($0 / 1000) Mbps" } ?? "—"
    }

    private var formattedRTT: String {
        session.stats.roundTripTimeMs.map { String(format: "%.0f ms", $0) } ?? "—"
    }

    private var formattedPacketLoss: String {
        session.stats.packetsLost.map(String.init) ?? "—"
    }

    private var formattedRenderDelay: String {
        surfaceModel.renderLatencyMs.map { String(format: "%.1f ms", $0) } ?? "—"
    }

    /// Renders a single HUD metric cell.
    private func hudItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit()
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textSecondary)
        }
    }

    /// Collects additional renderer diagnostics when the current stream exposes them.
    private var rendererDiagnosticsItems: [(String, String)] {
        var items: [(String, String)] = []
        if let status = surfaceModel.processingStatus {
            items.append(("Status", status))
        }
        if let inputRate = session.stats.inputFlushHz {
            items.append(("Input Rate", String(format: "%.0f Hz", inputRate)))
        }
        if let dropped = surfaceModel.framesDroppedByCoalescing {
            items.append(("Video Drops", "\(dropped)"))
        }
        if let failed = surfaceModel.framesFailed {
            items.append(("Failures", "\(failed)"))
        }
        if let framesLost = session.stats.framesLost {
            items.append(("Frame Loss", "\(framesLost)"))
        }
        return items
    }

    /// Formats the current input resolution for diagnostics display.
    private var rendererInputResolutionText: String {
        if let width = surfaceModel.processingInputWidth,
           let height = surfaceModel.processingInputHeight {
            return "\(width)x\(height)"
        }
        if let width = session.stats.negotiatedWidth,
           let height = session.stats.negotiatedHeight {
            return "\(width)x\(height)"
        }
        if let width = session.stats.controlPreferredWidth,
           let height = session.stats.controlPreferredHeight {
            return "\(width)x\(height)"
        }
        return "—"
    }

    /// Formats the current output resolution for diagnostics display.
    private var rendererOutputResolutionText: String {
        if let width = surfaceModel.processingOutputWidth,
           let height = surfaceModel.processingOutputHeight {
            return "\(width)x\(height)"
        }
        if let width = session.stats.messagePreferredWidth,
           let height = session.stats.messagePreferredHeight {
            return "\(width)x\(height)"
        }
        return rendererInputResolutionText
    }

    /// Truncates long renderer errors so the compact HUD remains readable.
    private func shortenedError(_ value: String) -> String {
        let compact = value.replacingOccurrences(of: "\n", with: " ")
        if compact.count <= 36 {
            return compact
        }
        return String(compact.prefix(33)) + "..."
    }
}