// CloudLibraryLibraryLetterIndexView.swift
// Shows the active alphabetical index position while browsing the library grid.
//

import GameController
import SwiftUI

struct CloudLibraryLibraryLetterIndexView<FocusValue: Hashable>: View {
    let sections: [String]
    var sectionIndexByLetter: [String: Int] = [:]
    let positionLetter: String?
    var focusedTarget: FocusState<FocusValue?>.Binding
    let letterFocusValue: (String) -> FocusValue
    let onSelectLetter: (String) -> Void
    var onMoveFromLetterIndex: ((MoveCommandDirection) -> Void)? = nil
    var isFocusEnabled: Bool = true
    let namespace: Namespace.ID

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let sectionCount = max(sections.count, 1)
            let slotHeight = proxy.size.height / CGFloat(sectionCount)
            let inactiveSize = min(max(slotHeight * 0.70, 15), 21)
            let activeSize = min(max(slotHeight * 0.88, 19), 30)
            let rail = VStack(spacing: 0) {
                ForEach(sections, id: \.self) { letter in
                    LetterIndexKey(
                        letter: letter,
                        isPositionMarker: letter == positionLetter,
                        showsRailFocus: focusedTarget.wrappedValue == letterFocusValue(letter),
                        slotHeight: slotHeight,
                        inactiveSize: inactiveSize,
                        activeSize: activeSize,
                        dynamicTypeSize: dynamicTypeSize,
                        onSelect: { onSelectLetter(letter) },
                        onMoveLeft: { onMoveFromLetterIndex?(.left) },
                        onVerticalRepeat: { offset in
                            stepFocus(offset: offset)
                        }
                    )
                    .focused(focusedTarget, equals: letterFocusValue(letter))
                    .focusable(isFocusEnabled)
                    .accessibilityLabel("Section \(letter)")
                    .accessibilityAddTraits(letter == positionLetter ? .isSelected : [])
                }
            }
            .animation(.easeOut(duration: 0.12), value: positionLetter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if isFocusEnabled {
                rail
                    .focusScope(namespace)
                    .focusSection()
            } else {
                rail
            }
        }
        .frame(width: StratixTheme.Library.letterIndexWidth)
        .accessibilityIdentifier("library_letter_index")
        .task(id: isFocusEnabled) {
            guard isFocusEnabled else { return }
            let hold = LetterIndexHoldState()
            LetterIndexHold.bindDirectionPads(hold)
            var holdStartedAt: ContinuousClock.Instant?
            var lastStepAt: ContinuousClock.Instant?
            while !Task.isCancelled {
                let offset = hold.offset != 0 ? hold.offset : LetterIndexHold.verticalOffset()
                let now = ContinuousClock.now
                if offset == 0 {
                    holdStartedAt = nil
                    lastStepAt = nil
                } else if holdStartedAt == nil {
                    holdStartedAt = now
                    lastStepAt = now
                } else if let started = holdStartedAt {
                    let readyForRepeat = now - started >= .milliseconds(280)
                    let sinceStep = lastStepAt.map { now - $0 } ?? .milliseconds(1_000)
                    if readyForRepeat, sinceStep >= .milliseconds(65) {
                        stepFocus(offset: offset)
                        lastStepAt = now
                    }
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
            LetterIndexHold.unbindDirectionPads()
        }
    }

    private func stepFocus(offset: Int) {
        let current = sections.first { focusedTarget.wrappedValue == letterFocusValue($0) }
        guard let current else { return }
        let index = sectionIndexByLetter[current] ?? sections.firstIndex(of: current)
        guard let index else { return }
        let nextIndex = index + offset
        guard sections.indices.contains(nextIndex) else { return }
        focusedTarget.wrappedValue = letterFocusValue(sections[nextIndex])
    }
}

/// One A–Z key. Up/down are left to the system focus engine so a held d-pad repeats like the search keyboard.
private struct LetterIndexKey: View {
    let letter: String
    let isPositionMarker: Bool
    let showsRailFocus: Bool
    let slotHeight: CGFloat
    let inactiveSize: CGFloat
    let activeSize: CGFloat
    let dynamicTypeSize: DynamicTypeSize
    let onSelect: () -> Void
    let onMoveLeft: () -> Void
    var onVerticalRepeat: ((Int) -> Void)? = nil

    var body: some View {
        Button(action: onSelect) {
            let active = showsRailFocus
            Text(letter)
                .font(
                    StratixTypography.rounded(
                        active ? activeSize : (isPositionMarker ? activeSize * 0.95 : inactiveSize),
                        weight: active ? .heavy : (isPositionMarker ? .bold : .semibold),
                        dynamicTypeSize: dynamicTypeSize
                    )
                )
                .foregroundStyle(
                    active
                        ? Color.white
                        : (isPositionMarker ? StratixTheme.Colors.focusTint : Color.white.opacity(0.45))
                )
                .scaleEffect(active ? 1.30 : (isPositionMarker ? 1.10 : 1.0))
                .shadow(
                    color: active
                        ? Color.white.opacity(0.65)
                        : (isPositionMarker ? StratixTheme.Colors.focusTint.opacity(0.45) : Color.clear),
                    radius: active ? 8 : 4,
                    x: 0,
                    y: 0
                )
                .frame(maxWidth: .infinity, minHeight: slotHeight, maxHeight: slotHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .onMoveCommand { direction in
            if direction == .left {
                onMoveLeft()
            }
        }
        .onKeyPress(keys: [.upArrow, .downArrow], phases: [.repeat]) { press in
            let offset = press.key == .upArrow ? -1 : 1
            Task { @MainActor in
                onVerticalRepeat?(offset)
            }
            return .handled
        }
    }
}

private final class LetterIndexHoldState: @unchecked Sendable {
    var offset: Int = 0
}

private enum LetterIndexHold {
    static func bindDirectionPads(_ hold: LetterIndexHoldState) {
        let handler: GCControllerDirectionPadValueChangedHandler = { _, _, y in
            if y > 0.45 {
                hold.offset = -1
            } else if y < -0.45 {
                hold.offset = 1
            } else {
                hold.offset = 0
            }
        }
        for controller in GCController.controllers() {
            controller.extendedGamepad?.dpad.valueChangedHandler = handler
            controller.microGamepad?.dpad.valueChangedHandler = handler
            controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { _, _, y in
                if y > 0.55 {
                    hold.offset = -1
                } else if y < -0.55 {
                    hold.offset = 1
                } else if abs(y) < 0.25 {
                    hold.offset = 0
                }
            }
        }
    }

    static func unbindDirectionPads() {
        for controller in GCController.controllers() {
            controller.extendedGamepad?.dpad.valueChangedHandler = nil
            controller.microGamepad?.dpad.valueChangedHandler = nil
            controller.extendedGamepad?.leftThumbstick.valueChangedHandler = nil
        }
    }

    static func verticalOffset() -> Int {
        var up = false
        var down = false
        for controller in GCController.controllers() {
            if let pad = controller.extendedGamepad?.dpad {
                if pad.up.isPressed || pad.yAxis.value > 0.45 { up = true }
                if pad.down.isPressed || pad.yAxis.value < -0.45 { down = true }
            }
            if let pad = controller.microGamepad?.dpad {
                if pad.up.isPressed || pad.yAxis.value > 0.45 { up = true }
                if pad.down.isPressed || pad.yAxis.value < -0.45 { down = true }
            }
            if let stick = controller.extendedGamepad?.leftThumbstick {
                if stick.yAxis.value > 0.55 { up = true }
                if stick.yAxis.value < -0.55 { down = true }
            }
        }
        if up && !down { return -1 }
        if down && !up { return 1 }
        return 0
    }
}

enum CloudLibraryLibraryLetterIndexSupport {
    static func indexLetter(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "#" }
        let letter = String(first).uppercased()
        return letter.first?.isLetter == true ? letter : "#"
    }

    static func highlightedLetter(
        sections: [String],
        jumpLetter: String?,
        scrollLetter: String?,
        focusedLetter: String?,
        prefersFocusedLetter: Bool = false
    ) -> String? {
        if let jumpLetter, sections.contains(jumpLetter) {
            return jumpLetter
        }
        if prefersFocusedLetter, let focusedLetter, sections.contains(focusedLetter) {
            return focusedLetter
        }
        if let scrollLetter, sections.contains(scrollLetter) {
            return scrollLetter
        }
        if let focusedLetter, sections.contains(focusedLetter) {
            return focusedLetter
        }
        return sections.first
    }

    static func isLiveScrollPhase(_ phase: ScrollPhase) -> Bool {
        phase != .idle
    }

    static func rowStride(
        itemWidth: CGFloat,
        titleSpacing: CGFloat = StratixTheme.Home.tileTitleSpacing,
        titleBlockHeight: CGFloat = StratixTheme.Home.tileTitleBlockHeight,
        itemSpacing: CGFloat = StratixTheme.Library.gridItemSpacing,
        tileAspect: CGFloat = StratixTheme.Layout.tileAspect
    ) -> CGFloat {
        let artworkHeight = (itemWidth * tileAspect).rounded()
        return artworkHeight + titleSpacing + titleBlockHeight + itemSpacing
    }

    static func letter(
        visibleMidY: CGFloat,
        headerHeight: CGFloat,
        rowStride: CGFloat,
        columnCount: Int,
        sectionLetters: [String]
    ) -> String? {
        letter(
            visibleMinY: visibleMidY,
            visibleMaxY: visibleMidY,
            scrollDelta: 0,
            headerHeight: headerHeight,
            rowStride: rowStride,
            columnCount: columnCount,
            sectionLetters: sectionLetters
        )
    }

    static func letter(
        visibleMinY: CGFloat,
        visibleMaxY: CGFloat,
        scrollDelta: CGFloat,
        headerHeight: CGFloat,
        rowStride: CGFloat,
        columnCount: Int,
        sectionLetters: [String]
    ) -> String? {
        guard !sectionLetters.isEmpty else { return nil }
        guard rowStride > 0, columnCount > 0 else { return sectionLetters.first }
        let sampleY: CGFloat
        if scrollDelta > 1 {
            sampleY = visibleMaxY - min(rowStride * 0.45, max(0, visibleMaxY - visibleMinY) * 0.22)
        } else if scrollDelta < -1 {
            sampleY = visibleMinY + min(rowStride * 0.45, max(0, visibleMaxY - visibleMinY) * 0.22)
        } else {
            sampleY = (visibleMinY + visibleMaxY) / 2
        }
        let yInGrid = sampleY - headerHeight
        let row = max(0, Int(floor(yInGrid / rowStride)))
        let index = min(sectionLetters.count - 1, row * columnCount)
        return sectionLetters[index]
    }
}