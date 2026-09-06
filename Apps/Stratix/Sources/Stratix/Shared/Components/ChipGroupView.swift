// ChipGroupView.swift
// Defines the chip group view used in the Shared / Components surface.
//

import SwiftUI

/// Wrapping layout used for metadata chips so rows flow naturally without hard-coded line breaks.
private struct WrappingChipLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        frames(for: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = frames(
            for: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )

        for (index, subview) in subviews.enumerated() where index < layout.frames.count {
            let frame = layout.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    /// Measures and wraps subviews into rows based on the proposed width.
    private func frames(for proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        guard !subviews.isEmpty else { return (.zero, []) }

        let proposedWidth = proposal.width ?? .greatestFiniteMagnitude
        let maxRowWidth = proposedWidth.isFinite ? max(proposedWidth, 1) : .greatestFiniteMagnitude

        var rects: [CGRect] = []
        rects.reserveCapacity(subviews.count)

        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if maxRowWidth.isFinite {
                size.width = min(size.width, maxRowWidth)
            }

            if cursorX > 0, cursorX + size.width > maxRowWidth {
                cursorX = 0
                cursorY += rowHeight + rowSpacing
                rowHeight = 0
            }

            let frame = CGRect(origin: CGPoint(x: cursorX, y: cursorY), size: size)
            rects.append(frame)

            cursorX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, frame.maxX)
        }

        let finalHeight = cursorY + rowHeight
        let finalWidth = proposedWidth.isFinite ? proposedWidth : contentWidth
        return (CGSize(width: finalWidth, height: finalHeight), rects)
    }
}

/// Shared non-interactive metadata chip used across detail and summary surfaces.
struct MetadataChip: View {
    let chip: ChipViewState

    var body: some View {
        HStack(spacing: 9) {
            if let systemImage = chip.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
            }
            Text(chip.label)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color.white.opacity(chip.style == .accent ? 0.96 : 0.85))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(chip.style == .accent ? 0.16 : 0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    Color.white.opacity(chip.style == .accent ? 0.28 : 0.12),
                    lineWidth: 1
                )
        )
    }
}

/// Leading-aligned wrapping container for metadata chips.
struct ChipGroupView: View {
    let chips: [ChipViewState]
    var spacing: CGFloat = 10

    var body: some View {
        WrappingChipLayout(spacing: spacing, rowSpacing: 10) {
            ForEach(chips) { chip in
                MetadataChip(chip: chip)
            }
        }
        .padding(.vertical, 2)
        .frame(minHeight: 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shared CTA pill styling for detail-route primary/secondary actions.
struct CloudLibraryActionButton: View {
    let action: CloudLibraryActionViewState
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = action.systemImage {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
            }
            Text(action.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 32)
        .padding(.vertical, 18)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: isFocused ? 2.5 : 1)
        )
        .shadow(
            color: Color.white.opacity(isFocused ? 0.22 : 0.0),
            radius: isFocused ? 14 : 0
        )
        .shadow(
            color: Color.black.opacity(isFocused ? 0.50 : 0.16),
            radius: isFocused ? 20 : 6,
            y: isFocused ? 8 : 3
        )
        .zIndex(isFocused ? 10 : 0)
        .animation(.easeOut(duration: 0.14), value: isFocused)
    }

    private var foreground: Color {
        Color.white
    }

    private var backgroundFill: Color {
        Color.white.opacity(isFocused ? 0.16 : 0.08)
    }

    private var borderColor: Color {
        Color.white.opacity(isFocused ? 0.65 : 0.16)
    }
}

/// Focus section that switches between a static row and a horizontal scroller depending on action count.
struct ActionButtonBar: View {
    let actions: [CloudLibraryActionViewState]
    let onSelect: (CloudLibraryActionViewState) -> Void
    var onMoveCommand: ((MoveCommandDirection, Int, CloudLibraryActionViewState) -> Void)? = nil
    var defaultFocusActionID: String? = nil
    var defaultFocusNamespace: Namespace.ID? = nil

    var body: some View {
        actionScroller
    }

    private var actionScroller: some View {
        Group {
            if actions.count <= 3 {
                HStack(spacing: 12) {
                    ForEach(actions) { action in
                        let index = actions.firstIndex(of: action) ?? 0
                        actionButtonItem(
                            action: action,
                            index: index,
                            onMoveCommand: { direction in
                                onMoveCommand?(direction, index, action)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(actions) { action in
                            let index = actions.firstIndex(of: action) ?? 0
                            actionButtonItem(
                                action: action,
                                index: index,
                                onMoveCommand: { direction in
                                    onMoveCommand?(direction, index, action)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .focusSection()
    }

    @ViewBuilder
    private func actionButtonItem(
        action: CloudLibraryActionViewState,
        index: Int,
        onMoveCommand: @escaping (MoveCommandDirection) -> Void
    ) -> some View {
        let item = ActionButtonBarItem(
            action: action,
            onSelect: onSelect,
            onMoveCommand: onMoveCommand
        )
        if let defaultFocusNamespace {
            let prefersFocus = defaultFocusActionID.map { action.id == $0 } ?? (index == 0)
            item.prefersDefaultFocus(prefersFocus, in: defaultFocusNamespace)
        } else {
            item
        }
    }
}

/// Individual focusable action button entry used inside `ActionButtonBar`.
private struct ActionButtonBarItem: View {
    let action: CloudLibraryActionViewState
    let onSelect: (CloudLibraryActionViewState) -> Void
    var onMoveCommand: ((MoveCommandDirection) -> Void)? = nil

    var body: some View {
        Button {
            onSelect(action)
        } label: {
            FocusAwareView { isFocused in
                CloudLibraryActionButton(action: action, isFocused: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .onMoveCommand { direction in
            onMoveCommand?(direction)
        }
    }
}

#if DEBUG
#Preview("ChipGroupView", traits: .fixedLayout(width: 1200, height: 280)) {
    ZStack {
        CloudLibraryAmbientBackground(imageURL: CloudLibraryPreviewData.library.heroBackdropURL)
        VStack(alignment: .leading, spacing: 16) {
            ChipGroupView(chips: CloudLibraryPreviewData.detail.capabilityChips)
            ActionButtonBar(
                actions: [CloudLibraryPreviewData.detail.primaryAction] + CloudLibraryPreviewData.detail.secondaryActions
            ) { _ in }
        }
        .padding(60)
    }
}
#endif
