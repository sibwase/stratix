// CloudLibraryLibraryScreenControls.swift
// Defines cloud library library screen controls for the CloudLibrary / Library surface.
//

import SwiftUI

struct LibraryFilterChipButton: View {
    let chip: ChipViewState
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 8) {
                    if let image = chip.systemImage {
                        Image(systemName: image)
                    }
                    Text(chip.label)
                        .lineLimit(1)
                }
                .font(StratixTypography.rounded(22, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(chip.isSelected || chip.style == .accent ? Color.black : StratixTheme.Colors.textPrimary)
                .padding(.horizontal, StratixTheme.Library.chipHorizontalPadding + 8)
                .padding(.vertical, StratixTheme.Library.chipVerticalPadding + 4)
                .background(
                    Capsule(style: .continuous).fill(
                        chip.isSelected || chip.style == .accent
                            ? Color.white
                            : Color.white.opacity(isFocused ? 0.14 : 0.07)
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            chip.isSelected || chip.style == .accent
                                ? Color.clear
                                : Color.white.opacity(isFocused ? 0.55 : 0.12),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .shadow(
                    color: Color.white.opacity(isFocused ? 0.18 : 0.0),
                    radius: isFocused ? 10 : 0
                )
                .shadow(
                    color: Color.black.opacity(isFocused ? 0.40 : 0.08),
                    radius: isFocused ? 14 : 4,
                    y: isFocused ? 6 : 2
                )
                .zIndex(isFocused ? 10 : 0)
                .animation(.easeOut(duration: 0.14), value: isFocused)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }
}

struct LibraryTabButton: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                ZStack {
                    // Sizing guide reserves the exact bold width so sibling views (like query text) never jitter during focus transitions
                    HStack(spacing: 10) {
                        Text(title)
                        if let systemImage {
                            Image(systemName: systemImage)
                        }
                    }
                    .font(
                        StratixTypography.rounded(
                            48,
                            weight: .bold,
                            dynamicTypeSize: dynamicTypeSize
                        )
                    )
                    .opacity(0)

                    // Visible button content with full original font styling, weight change, and scale effect
                    HStack(spacing: 10) {
                        Text(title)
                        if let systemImage {
                            Image(systemName: systemImage)
                        }
                    }
                    .font(
                        StratixTypography.rounded(
                            48,
                            weight: isSelected || isFocused ? .bold : .semibold,
                            dynamicTypeSize: dynamicTypeSize
                        )
                    )
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (isFocused ? Color.white.opacity(0.68) : Color.white.opacity(0.38))
                    )
                    .scaleEffect(isFocused ? 1.04 : 1.0)
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .padding(.horizontal, 0)
                .padding(.vertical, 6)
                .animation(.easeOut(duration: 0.14), value: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }
}

struct SortButton: View {
    let title: String
    var icon: String = "arrow.up.arrow.down"
    let onSelect: () -> Void
    var menuOptions: [(id: String, title: String, action: () -> Void)] = []

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onSelect) {
            FocusAwareView { isFocused in
                HStack(spacing: 10) {
                    Image(systemName: icon)
                    Text(title)
                        .lineLimit(1)
                }
                .font(StratixTypography.rounded(22, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textPrimary)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background {
                    stratixGlassSurface(
                        cornerRadius: 14,
                        fill: Color.white.opacity(isFocused ? 0.14 : 0.07)
                    )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .gamePassFocusRing(isFocused: isFocused, cornerRadius: 14)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .modifier(SortButtonContextMenuModifier(menuOptions: menuOptions))
    }
}

private struct SortButtonContextMenuModifier: ViewModifier {
    let menuOptions: [(id: String, title: String, action: () -> Void)]

    @ViewBuilder
    func body(content: Content) -> some View {
        if menuOptions.isEmpty {
            content
        } else {
            content.contextMenu {
                ForEach(menuOptions, id: \.id) { option in
                    Button(option.title, action: option.action)
                }
            }
        }
    }
}
