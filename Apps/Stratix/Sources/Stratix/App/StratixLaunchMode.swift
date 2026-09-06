// StratixLaunchMode.swift
// Defines stratix launch mode for the App surface.
//

import Foundation

/// Centralizes process-argument and environment-based launch flags used by harnesses and targeted UI tests.
enum StratixLaunchMode {
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let environment = ProcessInfo.processInfo.environment

    /// Enables the shell-focused UI-test harness instead of the real authenticated root.
    static var isShellUITestModeEnabled: Bool {
        hasArgument("-stratix-uitest-shell")
    }

    /// Enables the deterministic Game Pass home harness used by focused browse-route UI tests.
    static var isGamePassHomeUITestModeEnabled: Bool {
        hasArgument("-stratix-uitest-gamepass-home")
            || hasEnvironmentValue("STRATIX_UI_TEST_GAMEPASS_HOME")
    }

    /// Enables the home harness auto-detail path used by detail-entry roundtrip tests.
    static var isGamePassHomeAutoDetailUITestEnabled: Bool {
        hasArgument("-stratix-uitest-gamepass-home-auto-detail")
            || hasEnvironmentValue("STRATIX_UI_TEST_GAMEPASS_AUTO_DETAIL")
    }

    /// Returns the browse-route override passed by UI tests that want the shell to restore into a specific route.
    static var uiTestBrowseRouteOverrideRawValue: String? {
        guard let flagIndex = arguments.firstIndex(of: "-stratix-uitest-browse-route") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return arguments[valueIndex]
    }

    /// Enables the stream disconnect focus harness mode for stream-exit restoration tests.
    static var isStreamDisconnectUITestModeEnabled: Bool {
        hasArgument("-stratix-uitest-stream-disconnect-focus")
    }

    /// Enables the runtime probe harness mode used by stream telemetry and runtime marker tests.
    static var isStreamRuntimeProbeUITestModeEnabled: Bool {
        hasArgument("-stratix-uitest-stream-runtime-probe")
    }

    /// Allows Siri Remote Play/Pause to toggle the stream overlay in UI-test harnesses only.
    /// Production gameplay opens the overlay exclusively via L3+R3 hold (see `InputController`).
    static var allowsPlayPauseStreamOverlayToggle: Bool {
        isStreamDisconnectUITestModeEnabled || isStreamRuntimeProbeUITestModeEnabled
    }

    /// Forces a one-time live home refresh after authentication so tests can avoid cached-home startup paths.
    static var shouldForceLiveHomeRefreshForUITest: Bool {
        hasArgument("-stratix-uitest-force-live-home-refresh")
    }

    /// Seeds mock remote-play consoles so Consoles → StreamView UI can be exercised without a live Xbox.
    static var isMockConsolesUITestModeEnabled: Bool {
        hasArgument("-stratix-uitest-mock-consoles")
    }

    /// Checks for a launch argument exactly as passed by the current process.
    private static func hasArgument(_ argument: String) -> Bool {
        arguments.contains(argument)
    }

    /// Treats `"1"` as the enabled value for environment-based harness flags.
    private static func hasEnvironmentValue(_ key: String) -> Bool {
        environment[key] == "1"
    }
}
