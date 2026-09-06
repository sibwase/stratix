// CloudLibraryTitleDetailPanels.swift
// Defines cloud library title detail panels for the CloudLibrary / Detail surface.
//

import SwiftUI

extension CloudLibraryTitleDetailScreen {
    var detailPanelsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailSectionTitle("Details", isActive: focusedDetailPanelID != nil)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(state.detailPanels) { panel in
                    DetailPanelCardView(panel: panel)
                        .focused($focusedDetailPanelID, equals: panel.id)
                        .onMoveCommand { direction in
                            guard direction == .up else { return }
                            requestGalleryFocus()
                        }
                }
            }
            .focusSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func detailSectionTitle(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(StratixTheme.Fonts.sectionTitle)
            .foregroundStyle(isActive ? StratixTheme.Colors.textPrimary : StratixTheme.Colors.textSecondary)
            .animation(.easeOut(duration: 0.12), value: isActive)
    }
}

private struct DetailPanelCardView: View {
    let panel: OverlayPanelViewState

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !panel.title.isEmpty {
                Text(panel.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textPrimary)
            }

            Text(panel.body)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textSecondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(isFocused ? 0.45 : 0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(isFocused ? 0.5 : 0.12), lineWidth: isFocused ? 2 : 1)
        )
        .focusable(true)
        .gamePassDisableSystemFocusEffect()
        .gamePassFocusRing(isFocused: isFocused, cornerRadius: 20)
    }
}
