// StreamOverlayComposition.swift
// Defines stream overlay composition for the Streaming / Overlay surface.
//

import SwiftUI
import StratixModels
import StreamingCore

/// Renders the backdrop artwork and motion treatment behind the streaming overlay.
struct StreamLaunchArtworkView: View {
    let imageURL: URL?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var driftForward = false

    /// Renders the animated artwork layer and its darkening gradient overlay.
    var body: some View {
        ZStack {
            artwork
                .scaleEffect(reduceMotion ? 1.02 : (driftForward ? 1.08 : 1.03))
                .offset(
                    x: reduceMotion ? 0 : (driftForward ? -34 : 26),
                    y: reduceMotion ? 0 : (driftForward ? -18 : 20)
                )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .clipped()
        .accessibilityIdentifier("stream_launch_artwork")
        .task(id: animationIdentity) {
            guard !reduceMotion else {
                driftForward = false
                return
            }
            driftForward = false
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                driftForward = true
            }
        }
    }

    /// Keeps the subtle drift animation in sync with image selection and motion preferences.
    private var animationIdentity: String {
        "\(imageURL?.absoluteString ?? "none")|\(reduceMotion)"
    }

    @ViewBuilder
    /// Chooses the remote artwork when available and falls back to a gradient.
    private var artwork: some View {
        if let imageURL {
            CachedRemoteImage(url: imageURL, kind: .hero, priority: .high, maxPixelSize: 1_920) {
                backgroundFallback
            }
        } else {
            backgroundFallback
        }
    }

    /// Fallback artwork treatment used when no image URL is available.
    private var backgroundFallback: some View {
        LinearGradient(
            colors: [
                StratixTheme.Colors.focusTint.opacity(0.88),
                StratixTheme.Colors.accent.opacity(0.72),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Full-screen disconnect overlay with launch chrome and a bottom-center Reconnect action.
struct StreamDisconnectedOverlay: View {
    let overlayInfo: StreamOverlayInfo
    let statusTitle: String
    let summary: String
    let onReconnect: () -> Void

    var body: some View {
        ZStack {
            StreamLaunchArtworkView(imageURL: overlayInfo.imageURL)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            StreamLaunchOverlayLayout(
                gameTitle: overlayInfo.title,
                gameSubtitle: overlayInfo.subtitle,
                statusTitle: statusTitle,
                progress: 1.0,
                summary: summary,
                leadingAction: { EmptyView() }
            )

            StreamLaunchReconnectButton(onReconnect: onReconnect)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StreamLaunchReconnectButton: View {
    let onReconnect: () -> Void
    @FocusState private var isReconnectFocused: Bool

    var body: some View {
        Button(action: onReconnect) {
            FocusAwareView { isFocused in
                StreamLaunchChipButton(
                    title: "Reconnect",
                    systemImage: "arrow.clockwise",
                    isFocused: isFocused
                )
            }
        }
        .focused($isReconnectFocused)
        .prefersDefaultFocus(true, in: reconnectFocusNamespace)
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .accessibilityIdentifier("stream_reconnect_button")
        .accessibilityLabel("Reconnect stream")
        .onAppear {
            isReconnectFocused = true
        }
    }

    @Namespace private var reconnectFocusNamespace
}

private struct StreamLaunchChipButton: View {
    let title: String
    let systemImage: String
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
        }
        .foregroundStyle(StratixTheme.Colors.textPrimary)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Capsule(style: .continuous).fill(
                Color.white.opacity(isFocused ? 0.14 : 0.07)
            )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    Color.white.opacity(isFocused ? 0.55 : 0.12),
                    lineWidth: isFocused ? 2 : 1
                )
        )
    }
}

private struct StreamLaunchCancelButton: View {
    let onCancel: () -> Void
    @FocusState private var isCancelFocused: Bool

    var body: some View {
        Button(action: onCancel) {
            FocusAwareView { isFocused in
                CloudLibraryActionButton(
                    action: .init(id: "cancel", title: "Cancel", systemImage: "xmark", style: .primary),
                    isFocused: isFocused
                )
            }
        }
        .focused($isCancelFocused)
        .prefersDefaultFocus(true, in: cancelFocusNamespace)
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .accessibilityIdentifier("stream_launch_cancel_button")
        .accessibilityLabel("Cancel stream launch")
        .onAppear {
            isCancelFocused = true
        }
    }

    @Namespace private var cancelFocusNamespace
}

private struct StreamLaunchBottomProgressBar: View {
    let progress: Double

    @State private var displayedProgress: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                Rectangle()
                    .fill(StratixTheme.Colors.focusTint.opacity(0.72))
                    .frame(width: max(0, proxy.size.width * displayedProgress))
            }
        }
        .frame(height: 5)
        .frame(maxWidth: .infinity)
        .onAppear {
            displayedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.75)) {
                displayedProgress = newValue
            }
        }
    }
}

private struct StreamLaunchOverlayLayout<LeadingAction: View>: View {
    let gameTitle: String
    let gameSubtitle: String?
    let statusTitle: String
    let progress: Double
    let summary: String
    var waitLine: String? = nil
    @ViewBuilder let leadingAction: () -> LeadingAction

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()

                HStack(alignment: .bottom, spacing: 0) {
                    leadingAction()
                        .padding(.leading, 56)
                        .padding(.bottom, 28)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 10) {
                        Text(gameTitle)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)

                        if let gameSubtitle, !gameSubtitle.isEmpty {
                            Text(gameSubtitle)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }

                        Text(statusTitle)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.trailing)

                        Text(summary)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 620, alignment: .trailing)

                        if let waitLine, !waitLine.isEmpty {
                            Text(waitLine)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.trailing, 56)
                    .padding(.bottom, 28)
                }

                StreamLaunchBottomProgressBar(progress: progress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusSection()
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Displays the temporary overlay shown while a stream session is being prepared.
struct StreamPreparingOverlay: View {
    let overlayInfo: StreamOverlayInfo
    let onCancel: () -> Void

    /// Renders the pre-session preparation message and cancel affordance.
    var body: some View {
        ZStack {
            StreamLaunchOverlayLayout(
                gameTitle: overlayInfo.title,
                gameSubtitle: overlayInfo.subtitle,
                statusTitle: "Preparing Stream",
                progress: 0.08,
                summary: "Loading stream details and reserving a session.",
                leadingAction: {
                    StreamLaunchCancelButton(onCancel: onCancel)
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusSection()
    }
}

/// Composes the runtime overlay around connection status, lifecycle badge, and details panel.
struct StreamStatusOverlay: View {
    let overlayState: StreamOverlayState
    let session: (any StreamingSessionFacade)?
    let surfaceModel: StreamSurfaceModel
    let showStatsHUD: Bool
    let onCloseOverlay: () -> Void
    let onDisconnect: () -> Void

    /// Renders the connection overlay or details panel based on the current stream state.
    var body: some View {
        ZStack {
            if overlayState.showsConnectionOverlay {
                connectingOverlay
                    .transition(.opacity)
            } else if showStatsHUD, overlayState.hasSession {
                VStack {
                    HStack {
                        Spacer()
                        StreamLifecycleBadge(
                            lifecycle: overlayState.lifecycle,
                            isReconnecting: overlayState.isReconnecting
                        )
                        .padding(20)
                    }
                    Spacer()
                }
            }

            if overlayState.showsDetailsPanel, let session {
                StreamOverlayDetailsPanel(
                    session: session,
                    surfaceModel: surfaceModel,
                    overlayState: overlayState,
                    onCloseOverlay: onCloseOverlay,
                    onDisconnect: onDisconnect
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: overlayState.overlayVisible)
    }

    /// Renders the full-screen connection overlay shown before the stream is ready.
    private var connectingOverlay: some View {
        ZStack {
            StreamLaunchArtworkView(imageURL: overlayState.overlayInfo.imageURL)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            StreamLaunchOverlayLayout(
                gameTitle: overlayState.overlayInfo.title,
                gameSubtitle: overlayState.overlayInfo.subtitle,
                statusTitle: overlayState.lifecycle.overlayStateLabel,
                progress: overlayState.lifecycle.overlayConnectionProgress,
                summary: overlayState.lifecycle.overlayConnectionSummary,
                waitLine: estimatedWaitLine,
                leadingAction: {
                    StreamLaunchCancelButton(onCancel: onDisconnect)
                }
            )
        }
    }

    private var estimatedWaitLine: String? {
        if case .waitingForResources(let secs) = overlayState.lifecycle, let secs, secs > 0 {
            return "Estimated wait: ~\(secs) seconds"
        }
        return nil
    }
}

/// Compact lifecycle badge shown above the stream when the overlay is not open.
private struct StreamLifecycleBadge: View {
    let lifecycle: StreamLifecycleState
    var isReconnecting: Bool = false

    /// Renders the small colored lifecycle badge.
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(StratixTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .streamStatusCapsuleBackground()
    }

    private var statusLabel: String {
        isReconnecting ? "Reconnecting…" : lifecycle.overlayStateLabel
    }

    private var statusColor: Color {
        isReconnecting ? .orange : lifecycle.overlayStateColor
    }
}

extension StreamLifecycleState {
    /// Maps lifecycle state into the overlay's traffic-light badge color.
    var overlayStateColor: Color {
        switch self {
        case .connected: return .green
        case .failed: return .red
        case .disconnected: return .gray
        default: return .yellow
        }
    }

    /// Maps lifecycle state into the short overlay label shown in the badge and details panel.
    var overlayStateLabel: String {
        switch self {
        case .idle: return "Idle"
        case .startingSession: return "Starting..."
        case .provisioning: return "Provisioning..."
        case .waitingForResources(let secs):
            if let secs, secs > 0 { return "Queue: ~\(secs)s" }
            return "Waiting for server..."
        case .readyToConnect: return "Connecting..."
        case .connectingWebRTC: return "WebRTC..."
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        case .disconnected: return "Disconnected"
        case .failed(let error): return "Error: \(error.code.rawValue)"
        }
    }

    /// Converts lifecycle state into a normalized connection progress fraction.
    var overlayConnectionProgress: Double {
        switch self {
        case .idle:
            return 0.0
        case .startingSession:
            return 0.08
        case .provisioning:
            return 0.24
        case .waitingForResources:
            return 0.42
        case .readyToConnect:
            return 0.64
        case .connectingWebRTC:
            return 0.84
        case .connected:
            return 1.0
        case .disconnecting:
            return 0.96
        case .disconnected, .failed:
            return 1.0
        }
    }

    /// Builds the line of copy used below the connection progress bar.
    var overlayConnectionSummary: String {
        switch self {
        case .idle:
            return "Waiting to begin."
        case .startingSession:
            return "Step 1 of 5: Creating the stream session."
        case .provisioning:
            return "Step 2 of 5: Reserving server resources."
        case .waitingForResources:
            return "Step 3 of 5: Waiting for a server slot."
        case .readyToConnect:
            return "Step 4 of 5: Finalizing the transport."
        case .connectingWebRTC:
            return "Step 5 of 5: Negotiating WebRTC and media channels."
        case .connected:
            return "Stream connected."
        case .disconnecting:
            return "Ending the stream."
        case .disconnected:
            return "Stream disconnected."
        case .failed(let error):
            return error.description
        }
    }

    /// Returns true while the stream is still progressing toward an interactive overlay.
    var isAwaitingOverlayConnection: Bool {
        switch self {
        case .connected, .disconnecting, .disconnected, .failed:
            return false
        default:
            return true
        }
    }
}
