// ConsoleListEmptyState.swift
// Defines the console list empty state.
//

import SwiftUI

extension ConsoleListView {
    var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StratixTheme.Library.sectionSpacing) {
                CloudLibraryPageSectionCard(
                    title: "No Consoles Found",
                    subtitle: emptyStatePrimaryMessage
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        if let discoveryError = consoleController.lastError {
                            Text(discoveryError)
                                .font(StratixTypography.rounded(17, weight: .semibold, dynamicTypeSize: dynamicTypeSize))
                                .foregroundStyle(Color.orange.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Turn on your console, enable remote features, and confirm it has internet access before refreshing.")
                            .font(StratixTypography.rounded(17, weight: .medium, dynamicTypeSize: dynamicTypeSize))
                            .foregroundStyle(StratixTheme.Colors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            CloudLibraryStatPill(icon: "tv.fill", text: "Console on")
                            CloudLibraryStatPill(icon: "gearshape.fill", text: "Remote features enabled")
                            CloudLibraryStatPill(icon: "wifi", text: "Network reachable")
                        }
                    }
                }

                if showTroubleshootDetails {
                    troubleshootSection
                }

                CloudLibraryPageSectionCard(
                    title: "Remote Play Checklist",
                    subtitle: "Confirm these before the next refresh"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        CloudLibraryStatLine(icon: "checkmark.shield.fill", text: "Sign in with the same Xbox account used on your console.")
                        CloudLibraryStatLine(icon: "antenna.radiowaves.left.and.right", text: "Enable remote features in Xbox settings.")
                        CloudLibraryStatLine(icon: "moon.zzz.fill", text: "Use Sleep/Instant-On if you want wake-from-idle support.")
                        CloudLibraryStatLine(icon: "network", text: "Make sure the console stays connected to the internet.")
                    }
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.never)
    }

    var troubleshootSection: some View {
        CloudLibraryPageSectionCard(
            title: "Troubleshoot Discovery",
            subtitle: "Work through these if refresh still returns an empty list"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                CloudLibraryStatLine(icon: "person.crop.circle.badge.checkmark", text: "Use the same Xbox account on console and this app.")
                CloudLibraryStatLine(icon: "gearshape.2.fill", text: "Enable remote features and instant-on standby in console settings.")
                CloudLibraryStatLine(icon: "wifi.router.fill", text: "Avoid guest/VPN networks while testing remote discovery.")
                CloudLibraryStatLine(icon: "arrow.clockwise.circle.fill", text: "Refresh after each change to validate discovery.")
            }
        }
    }
}

extension ConsoleListView {
    var emptyStatePrimaryMessage: String {
        Self.emptyStatePrimaryMessage(
            discoveryError: consoleController.lastError,
            presenceState: profileController.currentUserPresence?.state,
            lastSeenDeviceType: profileController.currentUserPresence?.lastSeen?.deviceType
        )
    }

    /// Pure messaging helper so empty-state copy stays testable without mounting SwiftUI.
    static func emptyStatePrimaryMessage(
        discoveryError: String?,
        presenceState: String?,
        lastSeenDeviceType: String?
    ) -> String {
        if discoveryError != nil {
            return "Console discovery failed. Check your network connection and sign-in state, then refresh."
        }
        if let presenceState,
           presenceState.caseInsensitiveCompare("Offline") == .orderedSame {
            if let lastSeenDeviceType, !lastSeenDeviceType.isEmpty {
                return "Your \(displayName(forDeviceType: lastSeenDeviceType)) appears offline. Remote play discovery only lists consoles that are reachable right now."
            }
            return "Your Xbox appears offline. Remote play discovery only lists consoles that are reachable right now."
        }
        return "We couldn’t find any Xbox consoles ready for remote play on this account."
    }

    static func displayName(forDeviceType deviceType: String) -> String {
        switch deviceType.lowercased() {
        case "scarlett", "xboxseriesx":
            return "Xbox Series X"
        case "lockhart", "xboxseriess":
            return "Xbox Series S"
        case "xboxonex":
            return "Xbox One X"
        case "xboxones":
            return "Xbox One S"
        case "xboxone", "durango":
            return "Xbox One"
        default:
            return deviceType
        }
    }
}
