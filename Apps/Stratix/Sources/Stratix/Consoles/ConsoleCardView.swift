// ConsoleCardView.swift
// Defines the console card view used in the Consoles surface.
//

import SwiftUI
import XCloudAPI

struct ConsoleCardView: View {
    let console: RemoteConsole
    let onSelect: () -> Void

    @State private var analogTilt = CGSize.zero

    var body: some View {
        Button {
            onSelect()
        } label: {
            FocusAwareView { isFocused in
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 18) {
                        consoleArtwork(isFocused: isFocused)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(console.deviceName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(isFocused ? StratixTheme.Colors.focusTint : StratixTheme.Colors.textPrimary)
                                .lineLimit(1)
                            Text(console.consoleType)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(StratixTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 12)

                        statusBadge
                    }

                    HStack(spacing: 10) {
                        ConsoleInfoPill(icon: "play.fill", text: "Remote Play")
                        if console.outOfHomeWarning {
                            ConsoleInfoPill(icon: "house.slash.fill", text: "Out-of-home limits", style: .warning)
                        }
                        if console.wirelessWarning {
                            ConsoleInfoPill(icon: "wifi.exclamationmark", text: "Wireless warning", style: .warning)
                        }
                        if console.isDevKit {
                            ConsoleInfoPill(icon: "hammer.fill", text: "DevKit")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(isFocused ? StratixTheme.Colors.focusTint : Color.white.opacity(0.85))
                        Text("Start remote play")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(isFocused ? StratixTheme.Colors.focusTint : StratixTheme.Colors.textPrimary)
                        Spacer(minLength: 10)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isFocused ? StratixTheme.Colors.focusTint : Color.white.opacity(0.45))
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isFocused ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isFocused ? StratixTheme.Colors.focusTint.opacity(0.40) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .padding(22)
                .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: StratixTheme.Radius.xl, style: .continuous)
                        .fill(isFocused ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StratixTheme.Radius.xl, style: .continuous)
                        .stroke(
                            isFocused ? StratixTheme.Colors.focusTint.opacity(0.35) : Color.white.opacity(0.09),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .scaleEffect(isFocused ? 1.0 : 0.95)
                .offset(x: analogTilt.width * 18, y: -analogTilt.height * 18)
                .animation(.easeOut(duration: 0.18), value: isFocused)
                .modifier(MediaTileAnalogTiltModifier(isActive: isFocused, tilt: $analogTilt))
                .gamePassFocusRing(isFocused: isFocused, cornerRadius: StratixTheme.Radius.xl, appliesScaling: false)
                .zIndex(isFocused ? 10 : 0)
            }
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
    }

    private func consoleArtwork(isFocused: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [powerColor.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: consoleIcon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(powerColor)
        }
        .frame(width: 86, height: 86)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.30) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var consoleIcon: String {
        let type = console.consoleType.lowercased()
        if type.contains("series") {
            return "xbox.logo"
        }
        if type.contains("one") {
            return "tv.fill"
        }
        return "gamecontroller.fill"
    }

    private var powerColor: Color {
        switch console.powerState.lowercased() {
        case "on":
            return Color(red: 0.0, green: 0.78, blue: 0.12)
        case "standby":
            return Color.orange
        default:
            return Color.white.opacity(0.55)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(powerColor)
                .frame(width: 10, height: 10)
            Text(console.powerState.capitalized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

}

enum ConsoleInfoPillStyle {
    case neutral
    case warning
}

struct ConsoleInfoPill: View {
    let icon: String
    let text: String
    var style: ConsoleInfoPillStyle = .neutral

    var body: some View {
        let foreground: Color = style == .warning ? Color.orange : StratixTheme.Colors.textSecondary
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(foreground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
