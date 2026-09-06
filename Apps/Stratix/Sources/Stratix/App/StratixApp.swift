// StratixApp.swift
// Defines the app entry point and injects the shared controller graph into SwiftUI.
//

import SwiftUI
import StratixCore

@main
/// Boots the Stratix app and wires the shared `AppCoordinator` into the root scene.
struct StratixApp: App {
    @UIApplicationDelegateAdaptor(StratixAppDelegate.self) private var appDelegate

    @State private var coordinator = AppCoordinator()

    /// Creates the main window group and starts coordinator-driven boot only for normal app runs.
    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .environment(coordinator.sessionController)
                .environment(coordinator.libraryController)
                .environment(coordinator.profileController)
                .environment(coordinator.consoleController)
                .environment(coordinator.streamController)
                .environment(coordinator.shellBootstrapController)
                .environment(coordinator.achievementsController)
                .environment(coordinator.inputController)
                .environment(coordinator.previewExportController)
                .environment(coordinator.settingsStore)
                .task(priority: .userInitiated) {
                    appDelegate.coordinator = coordinator
                    guard shouldRunCoordinatorOnAppear else { return }
                    await coordinator.onAppear()
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    /// Skips normal coordinator boot when a UI harness owns startup sequencing.
    private var shouldRunCoordinatorOnAppear: Bool {
        !StratixLaunchMode.isShellUITestModeEnabled
            && !StratixLaunchMode.isGamePassHomeUITestModeEnabled
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "stratix" else { return }
        let host = url.host ?? ""
        let path = url.path
        if host == "play" || path.contains("play") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let titleId = components?.queryItems?.first(where: { $0.name == "titleId" })?.value ?? url.lastPathComponent
            if !titleId.isEmpty && titleId != "play" && titleId != "/" {
                NotificationCenter.default.post(name: .stratixDeepLinkPlay, object: titleId)
            }
        } else if host == "game" || path.contains("game") {
            let titleId = url.lastPathComponent
            if !titleId.isEmpty && titleId != "game" && titleId != "/" {
                NotificationCenter.default.post(name: .stratixDeepLinkDetail, object: titleId)
            }
        }
    }
}

extension Notification.Name {
    static let stratixDeepLinkPlay = Notification.Name("stratixDeepLinkPlay")
    static let stratixDeepLinkDetail = Notification.Name("stratixDeepLinkDetail")
}
