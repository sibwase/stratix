// CloudLibrarySettingsSidebar.swift
// Defines cloud library settings sidebar for the CloudLibrary / Settings surface.
//

import SwiftUI

extension CloudLibrarySettingsView {
    var sidebar: some View {
        VStack(alignment: .leading, spacing: StratixTheme.Library.headerBelowBadgeSpacing) {
            Color.clear
                .frame(height: StratixTheme.SideRail.collapsedBadgeHeight)

            VStack(alignment: .leading, spacing: 16) {
                headerCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(StratixTypography.rounded(18, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                        .textCase(.uppercase)

                    ForEach(CloudLibrarySettingsPane.visibleCases(isAdvanced: isAdvancedMode)) { pane in
                        CloudLibrarySidebarButton(
                            title: pane.title,
                            subtitle: pane.subtitle,
                            systemImage: pane.systemImage,
                            isSelected: selectedPane == pane,
                            onMoveLeft: requestShellSideRailEntry
                        ) {
                            selectedPane = pane
                        }
                        .focused($focusedPane, equals: pane)
                        .defaultFocus($focusedPane, pane)
                    }
                }

                Spacer(minLength: 0)

                CloudLibrarySettingsActionButton(
                    title: isAdvancedMode ? "Switch to Basic" : "Switch to Advanced",
                    systemImage: isAdvancedMode ? "sparkles" : "slider.horizontal.3",
                    onMoveLeft: requestShellSideRailEntry
                ) {
                    isAdvancedMode.toggle()
                }

                CloudLibrarySettingsActionButton(
                    title: previewExportTitle,
                    systemImage: "square.and.arrow.up",
                    onMoveLeft: requestShellSideRailEntry
                ) {
                    startPreviewExport()
                }

                if let exportFeedback, !exportFeedback.isEmpty {
                    Text(exportFeedback)
                        .font(StratixTypography.rounded(16, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CloudLibrarySettingsActionButton(
                    title: "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    destructive: true,
                    onMoveLeft: requestShellSideRailEntry,
                    action: onSignOut
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, StratixTheme.Shell.contentBottomPadding)
        .frame(width: 440, alignment: .topLeading)
    }

    var headerCard: some View {
        CloudLibraryPageSectionCard(title: "Account", subtitle: "Account summary for this shell page") {
            HStack(alignment: .top, spacing: 14) {
                profileAvatar
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 6) {
                    Text(profileName)
                        .font(StratixTypography.rounded(25, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(profileStatusText)
                        .font(StratixTypography.rounded(18, weight: .semibold, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textSecondary)
                        .lineLimit(1)

                    if !profileStatusDetail.isEmpty {
                        Text(profileStatusDetail)
                            .font(StratixTypography.rounded(17, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                            .foregroundStyle(StratixTheme.Colors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    var profileAvatar: some View {
        if let profileImageURL {
            CachedRemoteImage(
                url: profileImageURL,
                kind: .avatar,
                priority: .normal,
                maxPixelSize: 256,
                contentMode: .fill
            ) {
                avatarFallback
            }
            .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [StratixTheme.Colors.focusTint, StratixTheme.Colors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(profileInitials.isEmpty ? "P" : profileInitials)
                .font(StratixTypography.rounded(25, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    private func requestSideRailEntryOnLeft(_ direction: MoveCommandDirection) {
        guard direction == .left else { return }
        requestShellSideRailEntry()
    }
}
