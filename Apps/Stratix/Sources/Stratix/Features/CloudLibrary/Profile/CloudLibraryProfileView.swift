// CloudLibraryProfileView.swift
// Defines the cloud library profile view used in the CloudLibrary / Profile surface.
//

import Foundation
import SwiftUI
import StratixCore

struct CloudLibraryProfileView: View {
    enum Action: Hashable {
        case openSettings
        case refreshProfile
        case refreshFriends
        case refreshCloudLibrary
        case refreshConsoles
        case signOut
    }

    let profileName: String
    let profileStatus: String
    let profileStatusDetail: String
    let profileDetail: String
    let profileImageURL: URL?
    let profileInitials: String
    let gameDisplayName: String?
    let gamertag: String?
    let gamerscore: String?
    let cloudLibraryCount: Int
    let consoleCount: Int
    let friendsCount: Int
    let friendsLastUpdatedAt: Date?
    let friendsErrorText: String?
    var onOpenSettings: () -> Void = {}
    var onRefreshProfileMetadata: () -> Void = {}
    var onRefreshProfileData: () -> Void = {}
    var onRefreshFriends: () -> Void = {}
    var onRefreshCloudLibrary: () -> Void = {}
    var onRefreshConsoles: () -> Void = {}
    var onSignOut: () -> Void = {}
    var onRequestSideRailEntry: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedAction: Action?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StratixTheme.Library.headerBelowBadgeSpacing) {
                Color.clear
                    .frame(height: StratixTheme.SideRail.collapsedBadgeHeight)

                Text("Account")
                    .font(StratixTypography.rounded(50, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                    .foregroundStyle(Color.white)

                VStack(alignment: .leading, spacing: 120) {
                    HStack(alignment: .top, spacing: 48) {
                        accountHeaderSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        shellStatusSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    HStack(alignment: .top, spacing: 48) {
                        quickActionsSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        friendsSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(.top, 14)
            }
            .padding(.bottom, StratixTheme.Shell.contentBottomPadding)
            .frame(maxWidth: 1720, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollIndicators(.never)
        .accessibilityIdentifier("route_profile_root")
        .onAppear {
            onRefreshProfileMetadata()
        }
    }

    private var accountHeaderSection: some View {
        HStack(alignment: .top, spacing: 22) {
            profileAvatar
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(displayName)
                        .font(StratixTypography.rounded(34, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(profileStatus)
                        .font(StratixTypography.rounded(15, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(profileStatusBadgeTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(profileStatusBadgeFill))
                }

                if let secondaryName, !secondaryName.isEmpty {
                    Text(secondaryName)
                        .font(StratixTypography.rounded(18, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textSecondary)
                }

                if !profileStatusDetail.isEmpty {
                    Text(profileStatusDetail)
                        .font(StratixTypography.rounded(19, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !profileDetail.isEmpty {
                    Text(profileDetail)
                        .font(StratixTypography.rounded(16, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    ForEach(Array(summaryPills.indices), id: \.self) { index in
                        summaryPills[index]
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var shellStatusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shell Status")
                .font(StratixTypography.rounded(24, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textPrimary)

            shellStatusLines
        }
    }

    private var shellStatusLines: some View {
        VStack(alignment: .leading, spacing: 12) {
            CloudLibraryStatLine(icon: "person.crop.circle.fill", text: "Presence: \(profileStatus)")
            if !profileStatusDetail.isEmpty {
                CloudLibraryStatLine(icon: "bolt.horizontal.fill", text: profileStatusDetail)
            }
            CloudLibraryStatLine(icon: "slider.horizontal.3", text: profileDetail)
            CloudLibraryStatLine(icon: "cloud.fill", text: "\(cloudLibraryCount) cloud titles ready")
            CloudLibraryStatLine(icon: "tv.fill", text: "\(consoleCount) consoles available")
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Friends")
                .font(StratixTypography.rounded(24, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textPrimary)

            friendsStatusLines
        }
    }

    private var friendsStatusLines: some View {
        VStack(alignment: .leading, spacing: 12) {
            CloudLibraryStatLine(
                icon: "person.2.fill",
                text: friendsCount == 1 ? "1 friend profile loaded" : "\(friendsCount) friend profiles loaded"
            )

            if let friendsRefreshText, !friendsRefreshText.isEmpty {
                CloudLibraryStatLine(icon: "clock.fill", text: friendsRefreshText)
            }

            if let friendsErrorText, !friendsErrorText.isEmpty {
                CloudLibraryStatLine(icon: "exclamationmark.triangle.fill", text: friendsErrorText)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(StratixTypography.rounded(24, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(StratixTheme.Colors.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16, alignment: .leading),
                    GridItem(.flexible(), spacing: 16, alignment: .leading),
                    GridItem(.flexible(), spacing: 16, alignment: .leading)
                ],
                alignment: .leading,
                spacing: 16
            ) {
                quickActionButton(
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    focusTarget: .openSettings,
                    accessibilityIdentifier: "profile_rail_settings",
                    wantsRailEntryOnLeft: true,
                    action: onOpenSettings
                )
                quickActionButton(
                    title: "Refresh Game Pass",
                    systemImage: "cloud.fill",
                    focusTarget: .refreshCloudLibrary,
                    action: onRefreshCloudLibrary
                )
                quickActionButton(
                    title: "Refresh Consoles",
                    systemImage: "tv.badge.wifi",
                    focusTarget: .refreshConsoles,
                    action: onRefreshConsoles
                )
                quickActionButton(
                    title: "Refresh Profile",
                    systemImage: "arrow.clockwise",
                    focusTarget: .refreshProfile,
                    wantsRailEntryOnLeft: true,
                    action: onRefreshProfileData
                )
                quickActionButton(
                    title: "Refresh Friends",
                    systemImage: "person.2.badge.gearshape.fill",
                    focusTarget: .refreshFriends,
                    action: onRefreshFriends
                )
                quickActionButton(
                    title: "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    focusTarget: .signOut,
                    accessibilityIdentifier: "profile_rail_signout",
                    destructive: true,
                    action: onSignOut
                )
            }
        }
    }

    private var displayName: String {
        sanitized(gameDisplayName) ?? profileName
    }

    private var secondaryName: String? {
        if let gamertag = sanitized(gamertag), gamertag != displayName {
            return gamertag
        }
        if displayName != profileName {
            return profileName
        }
        return nil
    }

    private var summaryPills: [CloudLibraryStatPill] {
        var pills: [CloudLibraryStatPill] = []
        if let gamerscore = sanitized(gamerscore) {
            pills.append(CloudLibraryStatPill(icon: "gamecontroller.fill", text: "\(gamerscore) G"))
        }
        pills.append(CloudLibraryStatPill(icon: "cloud.fill", text: "\(cloudLibraryCount) titles"))
        pills.append(CloudLibraryStatPill(icon: "tv.fill", text: "\(consoleCount) consoles"))
        return pills
    }

    private var friendsRefreshText: String? {
        guard let friendsLastUpdatedAt else { return nil }
        return "Friends refreshed \(friendsLastUpdatedAt.formatted(date: .omitted, time: .shortened))"
    }

    @ViewBuilder
    private var profileAvatar: some View {
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

    private var avatarFallback: some View {
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
                .font(StratixTypography.rounded(36, weight: .bold, dynamicTypeSize: dynamicTypeSize))
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
    }

    private var profileStatusBadgeFill: Color {
        let lower = profileStatus.lowercased()
        if lower.contains("offline") {
            return Color.white.opacity(0.12)
        }
        if lower.contains("busy") || lower.contains("away") {
            return Color.orange.opacity(0.25)
        }
        return StratixTheme.Colors.focusTint
    }

    private var profileStatusBadgeTextColor: Color {
        let lower = profileStatus.lowercased()
        if lower.contains("offline") || lower.contains("busy") || lower.contains("away") {
            return StratixTheme.Colors.textPrimary
        }
        return .black
    }

    private func quickActionButton(
        title: String,
        systemImage: String,
        focusTarget: Action,
        accessibilityIdentifier: String? = nil,
        wantsRailEntryOnLeft: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        CloudLibrarySettingsActionButton(
            title: title,
            systemImage: systemImage,
            destructive: destructive,
            accessibilityIdentifier: accessibilityIdentifier,
            onMoveLeft: wantsRailEntryOnLeft ? onRequestSideRailEntry : nil,
            action: action
        )
        .focused($focusedAction, equals: focusTarget)
        .modifier(DefaultProfileFocusModifier(focusedAction: $focusedAction, focusTarget: focusTarget))
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DefaultProfileFocusModifier: ViewModifier {
    let focusedAction: FocusState<CloudLibraryProfileView.Action?>.Binding
    let focusTarget: CloudLibraryProfileView.Action

    @ViewBuilder
    func body(content: Content) -> some View {
        if focusTarget == .openSettings {
            content.defaultFocus(focusedAction, .openSettings)
        } else {
            content
        }
    }
}
