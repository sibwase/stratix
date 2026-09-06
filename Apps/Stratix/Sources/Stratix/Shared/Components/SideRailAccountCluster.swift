// SideRailAccountCluster.swift
// Defines side rail account cluster for the Shared / Components surface.
//

import SwiftUI

extension SideRailNavigationView {
    /// Profile owns settings in the shell, so both utility routes keep the account cluster selected.
    var isProfileClusterSelected: Bool {
        activeUtilityRoute == .profile || activeUtilityRoute == .settings
    }

    /// Top account/profile entry point for the side rail, sharing the same collapse-to-content behavior as the rest of the rail.
    var accountClusterView: some View {
        Button {
            onSelectAction("profile-menu")
            collapseRail()
        } label: {
            FocusAwareView { isFocused in
                HStack(spacing: 14) {
                    profileAvatar
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())

                    if isRailExpanded {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.accountName.isEmpty ? "Stratix Player" : state.accountName)
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(isFocused ? Color.black : Color.white)
                                .lineLimit(1)

                            Text(state.accountStatus.isEmpty ? "Online" : state.accountStatus)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(isFocused ? Color.black.opacity(0.75) : Color.white.opacity(0.60))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: StratixTheme.Shell.profileAccountClusterHeight, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: StratixTheme.SideRail.rowCornerRadius, style: .continuous)
                        .fill(SideRailRowStyle.fill(isFocused: isFocused, isSelected: isProfileClusterSelected))
                )
                .animation(StratixTheme.SideRail.rowFocusAnimation, value: isFocused)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .focused($focusedTarget, equals: .account)
        .disabled(!isRailExpanded)
        .accessibilityIdentifier("side_rail_action_profile_menu")
        .accessibilityLabel(Text("\(state.accountName), \(state.accountStatus)"))
        .accessibilityHint(Text("Open profile menu"))
        .accessibilityValue(Text(isProfileClusterSelected ? "selected" : "not_selected"))
        .onMoveCommand { direction in
            if direction == .right {
                moveFocusToContent()
                return
            }
            guard direction == .down else { return }
            if let firstExpandedNavID {
                focusedTarget = .nav(firstExpandedNavID)
            } else if let firstActionID {
                focusedTarget = .action(firstActionID)
            }
        }
    }

    /// Resolves the remote avatar when available and falls back to initials when profile art is missing.
    @ViewBuilder
    var profileAvatar: some View {
        if let imageURL = state.profileImageURL {
            CachedRemoteImage(
                url: imageURL,
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

    /// Gradient initials fallback used while profile artwork is unavailable.
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
            Text(state.profileInitials.isEmpty ? "P" : state.profileInitials)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black)
        }
        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}
