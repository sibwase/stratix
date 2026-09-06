// MediaTileView.swift
// Defines the media tile view used in the Shared / Components surface.
//

import GameController
import SwiftUI
import StratixCore

/// Shared game/media tile used across library, home, and search surfaces with custom artwork,
/// badge, and focus rendering.
struct MediaTileView: View, Equatable {
    let state: MediaTileViewState
    let onSelect: () -> Void
    var onPlay: (() -> Void)? = nil
    var onViewDetails: (() -> Void)? = nil
    var onRemoveFromMRU: (() -> Void)? = nil
    /// Allows specific callers to override the environment focus state when they need a
    /// deterministic visual focus treatment during routing or restoration.
    var forcedFocus: Bool? = nil
    var presentation: MediaTilePresentation = .standard
    var artworkOverrideSize: CGSize? = nil
    private let subtitleBlockHeight: CGFloat = 20
    @State private var analogTilt = CGSize.zero

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { buttonFocused in
                let activeFocus = forcedFocus ?? buttonFocused
                let scale = activeFocus
                    ? StratixTheme.Home.tileFocusAppliedScale
                    : StratixTheme.Home.tileUnfocusedScale
                let hoverExpansion = activeFocus ? focusedPosterHoverExpansion : .zero
                let titleHoverScale = activeFocus ? focusedPosterHoverScale : 1
                VStack(alignment: .leading, spacing: StratixTheme.Home.tileTitleSpacing) {
                    artworkView(activeFocus: activeFocus)
                    if presentation == .standard {
                        titleBlock(activeFocus: activeFocus)
                            .scaleEffect(titleHoverScale, anchor: .topLeading)
                            .offset(x: -hoverExpansion.width, y: hoverExpansion.height)
                    }
                }
                .scaleEffect(scale)
                .offset(x: analogTilt.width * 18, y: -analogTilt.height * 18)
                .animation(.easeOut(duration: 0.2), value: activeFocus)
                .modifier(MediaTileAnalogTiltModifier(isActive: activeFocus, tilt: $analogTilt))
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .modifier(MediaTileFocusRaiseModifier())
        .modifier(MediaTileContextMenuModifier(onPlay: onPlay, onSelect: onSelect, onViewDetails: onViewDetails, onRemoveFromMRU: onRemoveFromMRU))
        .accessibilityIdentifier("game_tile_\(state.titleID.rawValue)")
        .accessibilityLabel(Text(state.title))
        .accessibilityValue(Text(state.badgeText ?? state.caption ?? ""))
    }

    nonisolated static func == (lhs: MediaTileView, rhs: MediaTileView) -> Bool {
        lhs.state == rhs.state
            && lhs.presentation == rhs.presentation
            && lhs.artworkOverrideSize == rhs.artworkOverrideSize
            && lhs.forcedFocus == rhs.forcedFocus
    }

    /// Selects the standard portrait tile sizing or wider landscape presentation based on tile aspect.
    private var artworkSize: CGSize {
        if let artworkOverrideSize {
            return artworkOverrideSize
        }
        switch state.aspect {
        case .portrait:
            return CGSize(width: StratixTheme.Layout.tileWidth, height: StratixTheme.Layout.tileHeight)
        case .landscape:
            return CGSize(width: 360, height: 202)
        }
    }

    private var tileArtworkKind: ArtworkKind {
        state.aspect == .portrait ? .poster : .hero
    }

    private var tileArtworkMaxPixelSize: CGFloat {
        let longestEdge = max(artworkSize.width, artworkSize.height)
        let retinaCap: CGFloat = state.aspect == .portrait ? 640 : 960
        return min((longestEdge * 2).rounded(), retinaCap)
    }

    /// Same extra scale `.highlight` applies to the poster, so title/studio grow by that percentage too.
    private var focusedPosterHoverScale: CGFloat {
        1 + (2 * StratixTheme.Home.tileTitleFocusSpacing / StratixTheme.Layout.tileHeight)
    }

    /// How far `.highlight` grows this poster from its center (18pt down at default tile height).
    private var focusedPosterHoverExpansion: CGSize {
        let extra = focusedPosterHoverScale - 1
        return CGSize(
            width: artworkSize.width * extra / 2,
            height: artworkSize.height * extra / 2
        )
    }

    /// Builds the artwork surface and the shared badge overlay.
    /// Badge lives in the same hover/scale container as the poster so it zooms and tilts with the card.
    private func artworkView(activeFocus: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedRemoteImage(
                url: state.artworkURL,
                kind: tileArtworkKind,
                maxPixelSize: tileArtworkMaxPixelSize,
                contentMode: .fit,
                cornerRadius: StratixTheme.Radius.md
            ) {
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.28))
                }
            }
            .frame(width: artworkSize.width, height: artworkSize.height, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: StratixTheme.Radius.md, style: .continuous))

            if presentation == .standard, let badge = state.badgeText {
                MetadataChip(chip: ChipViewState(id: "tile-badge", label: badge, style: .accent))
                    .padding(10)
                    .accessibilityLabel(Text(badge))
                    .accessibilityIdentifier("game_tile_badge_\(state.titleID.rawValue)")
            }
        }
        .frame(width: artworkSize.width, height: artworkSize.height)
        .hoverEffect(.highlight)
        .shadow(color: Color.white.opacity(activeFocus ? 0.16 : 0), radius: activeFocus ? 10 : 0)
        .shadow(
            color: Color.black.opacity(activeFocus ? 0.42 : 0.08),
            radius: activeFocus ? 20 : 3,
            y: activeFocus ? 12 : 1
        )
    }

    /// Keeps title, subtitle, and caption heights stable so rows do not jump as focus changes.
    private func titleBlock(activeFocus: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    activeFocus ? StratixTheme.Colors.focusTint : Color.white.opacity(0.90)
                )
                .lineLimit(2)
                .frame(width: artworkSize.width, alignment: .topLeading)

            if let subtitle = state.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .lineLimit(1)
                    .frame(width: artworkSize.width, height: subtitleBlockHeight, alignment: .topLeading)
                    .padding(.top, 1)
            }

            if let caption = state.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.36))
                    .lineLimit(1)
                    .frame(width: artworkSize.width, alignment: .leading)
            }
        }
        .frame(width: artworkSize.width, height: StratixTheme.Home.tileTitleBlockHeight, alignment: .topLeading)
        .clipped()
    }
}

#if DEBUG
#Preview("MediaTileView", traits: .fixedLayout(width: 920, height: 620)) {
    ZStack {
        Color.black
        HStack(spacing: 24) {
            MediaTileView(state: CloudLibraryPreviewData.tileStates[0], onSelect: {})
            MediaTileView(state: CloudLibraryPreviewData.tileStates[1], onSelect: {}, forcedFocus: true)
        }
        .padding(60)
    }
}
#endif

private struct MediaTileFocusRaiseModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    @State private var isRaised = false

    func body(content: Content) -> some View {
        content
            .zIndex(isRaised ? 10 : 0)
            .onAppear {
                isRaised = isFocused
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    isRaised = true
                    return
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    if !isFocused {
                        isRaised = false
                    }
                }
            }
    }
}

/// Tilts the whole game card (poster + titles) from Siri Remote touch / gamepad stick.
struct MediaTileAnalogTiltModifier: ViewModifier {
    let isActive: Bool
    @Binding var tilt: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .task(id: isActive && !reduceMotion) {
                guard isActive, !reduceMotion else {
                    if tilt != .zero {
                        withAnimation(.easeOut(duration: 0.2)) { tilt = .zero }
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled, isActive, !reduceMotion else { return }
                while !Task.isCancelled {
                    let controllers = GCController.controllers()
                    guard !controllers.isEmpty else {
                        if tilt != .zero { tilt = .zero }
                        try? await Task.sleep(for: .milliseconds(500))
                        continue
                    }
                    let sample = MediaTileAnalogPeek.vector()
                    let isStickActive = abs(sample.width) >= 0.08 || abs(sample.height) >= 0.08
                    let isCurrentlyTilted = abs(tilt.width) >= 0.01 || abs(tilt.height) >= 0.01
                    if isStickActive || isCurrentlyTilted {
                        let targetWidth = isStickActive ? sample.width : 0
                        let targetHeight = isStickActive ? sample.height : 0
                        let newWidth = tilt.width + (targetWidth - tilt.width) * 0.32
                        let newHeight = tilt.height + (targetHeight - tilt.height) * 0.32
                        if abs(newWidth - tilt.width) > 0.005 || abs(newHeight - tilt.height) > 0.005 {
                            tilt.width = newWidth
                            tilt.height = newHeight
                        } else if !isStickActive {
                            if tilt != .zero {
                                tilt = .zero
                            }
                        }
                        try? await Task.sleep(for: .milliseconds(32))
                    } else {
                        if tilt != .zero {
                            tilt = .zero
                        }
                        try? await Task.sleep(for: .milliseconds(280))
                    }
                }
            }
    }
}

/// Analog inspection vs committed focus move, matching Apple TV lockup stickiness.
enum MediaTileAnalogPeek {
    static let unstickThreshold: CGFloat = 0.82

    static func vector() -> CGSize {
        var stickX: Float = 0
        var stickY: Float = 0
        var padX: Float = 0
        var padY: Float = 0
        for controller in GCController.controllers() {
            if let stick = controller.extendedGamepad?.leftThumbstick {
                let x = stick.xAxis.value
                let y = stick.yAxis.value
                if hypot(x, y) >= hypot(stickX, stickY) {
                    stickX = x
                    stickY = y
                }
            }
            if hypot(stickX, stickY) < 0.04, let stick = controller.extendedGamepad?.rightThumbstick {
                let x = stick.xAxis.value
                let y = stick.yAxis.value
                if hypot(x, y) >= hypot(stickX, stickY) {
                    stickX = x
                    stickY = y
                }
            }
            if let pad = controller.microGamepad?.dpad {
                let x = pad.xAxis.value
                let y = pad.yAxis.value
                if hypot(x, y) >= hypot(padX, padY) {
                    padX = x
                    padY = y
                }
            }
        }
        let x: Float
        let y: Float
        if hypot(stickX, stickY) >= 0.04 {
            x = stickX
            y = stickY
        } else {
            x = padX
            y = padY
        }
        return CGSize(
            width: abs(x) < 0.05 ? 0 : CGFloat(x),
            height: abs(y) < 0.05 ? 0 : CGFloat(y)
        )
    }

    static func magnitude() -> CGFloat {
        let sample = vector()
        return hypot(sample.width, sample.height)
    }

    static func isDigitalDirectionPressed() -> Bool {
        for controller in GCController.controllers() {
            if let dpad = controller.extendedGamepad?.dpad {
                if dpad.up.isPressed || dpad.down.isPressed || dpad.left.isPressed || dpad.right.isPressed {
                    return true
                }
            }
            if let dpad = controller.microGamepad?.dpad {
                if dpad.up.isPressed || dpad.down.isPressed || dpad.left.isPressed || dpad.right.isPressed {
                    return true
                }
            }
        }
        return false
    }

    /// Thumbstick-only magnitude so Siri Remote swipes are not treated as analog inspection.
    static func analogStickMagnitude() -> CGFloat {
        var x: Float = 0
        var y: Float = 0
        for controller in GCController.controllers() {
            if let stick = controller.extendedGamepad?.leftThumbstick {
                x = stick.xAxis.value
                y = stick.yAxis.value
            }
            if hypot(x, y) < 0.04, let stick = controller.extendedGamepad?.rightThumbstick {
                x = stick.xAxis.value
                y = stick.yAxis.value
            }
            if hypot(x, y) >= 0.04 {
                break
            }
        }
        return CGFloat(hypot(x, y))
    }

    static func shouldAllowFocusMove() -> Bool {
        if isDigitalDirectionPressed() {
            return true
        }
        let stickMagnitude = analogStickMagnitude()
        if stickMagnitude < 0.08 {
            return true
        }
        return stickMagnitude >= unstickThreshold
    }

    /// Neighbor-tile stickiness only. Chrome exits (side rail, letter index, header) always proceed.
    static func shouldBlockNeighborMove(isChromeExit: Bool) -> Bool {
        guard !isChromeExit else { return false }
        return !shouldAllowFocusMove()
    }
}

private struct MediaTileContextMenuModifier: ViewModifier {
    let onPlay: (() -> Void)?
    let onSelect: () -> Void
    let onViewDetails: (() -> Void)?
    let onRemoveFromMRU: (() -> Void)?
    @Environment(\.isFocused) private var isFocused

    @ViewBuilder
    func body(content: Content) -> some View {
        if isFocused, onPlay != nil || onViewDetails != nil || onRemoveFromMRU != nil {
            content.contextMenu {
                if let onPlay {
                    Button(action: onPlay) {
                        Label("Play", systemImage: "play.fill")
                    }
                }
                if let detailsAction = onViewDetails ?? (onPlay != nil ? onSelect : nil) {
                    Button(action: detailsAction) {
                        Label("View Details", systemImage: "info.circle")
                    }
                }
                if let onRemoveFromMRU {
                    Button(role: .destructive, action: onRemoveFromMRU) {
                        Label("Remove from My games", systemImage: "xmark.circle")
                    }
                }
            }
        } else {
            content
        }
    }
}
