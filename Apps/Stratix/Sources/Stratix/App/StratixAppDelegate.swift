// StratixAppDelegate.swift
// Defines the UIApplication delegate hooks that bridge system events into the app coordinator.
//

import UIKit
import StratixCore

/// Forwards app-level UIKit lifecycle callbacks into the shared coordinator surface.
final class StratixAppDelegate: NSObject, UIApplicationDelegate {
    var coordinator: AppCoordinator?

    /// Finishes delegate setup without introducing additional UIKit-owned boot work.
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated {
            StratixScrollChromePolicy.install()
        }
        return true
    }

    /// Runs the coordinator-owned background refresh path when tvOS requests a fetch cycle.
    func application(
        _: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let coordinator else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            let refreshed = await coordinator.performBackgroundAppRefresh()
            completionHandler(refreshed ? .newData : .noData)
        }
    }
}

/// Hides system scroll chrome through appearance and SwiftUI environment only.
/// Method swizzling on `UIView`/`UIScrollView` deadlocked library hydration on tvOS.
@MainActor
enum StratixScrollChromePolicy {
    private static var didInstall = false

    static func install() {
        guard !didInstall else { return }
        didInstall = true

        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        UIScrollView.appearance().indexDisplayMode = .alwaysHidden
    }
}
