// StreamControllerInputHost.swift
// Defines stream controller input host for the Features / Streaming surface.
//

import DiagnosticsKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GameController)
import GameController
#endif

#if os(tvOS) && canImport(UIKit) && canImport(GameController)
/// Root modal host for stream screens.
/// Uses GCEventViewController as the presented root to intercept controller menu/back presses
/// before tvOS dismisses the fullScreenCover.
struct StreamControllerInputHost<Content: View>: UIViewControllerRepresentable {
    let allowsControllerUIFocus: Bool
    let content: Content
    let onOverlayToggle: (() -> Void)?

    init(
        allowsControllerUIFocus: Bool = false,
        onOverlayToggle: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.allowsControllerUIFocus = allowsControllerUIFocus
        self.onOverlayToggle = onOverlayToggle
        self.content = content()
    }

    func makeUIViewController(context: Context) -> StreamControllerInputViewController<Content> {
        StreamControllerInputViewController(
            rootView: content,
            allowsControllerUIFocus: allowsControllerUIFocus,
            onOverlayToggle: onOverlayToggle
        )
    }

    func updateUIViewController(_ uiViewController: StreamControllerInputViewController<Content>, context: Context) {
        uiViewController.hostingController.rootView = content
        uiViewController.onOverlayToggle = onOverlayToggle
        uiViewController.allowsControllerUIFocus = allowsControllerUIFocus
    }
}

final class StreamControllerInputViewController<Content: View>: GCEventViewController {
    let hostingController: UIHostingController<Content>
    var onOverlayToggle: (() -> Void)?
    var allowsControllerUIFocus: Bool {
        didSet {
            guard oldValue != allowsControllerUIFocus else { return }
            controllerUserInteractionEnabled = allowsControllerUIFocus
            if !allowsControllerUIFocus {
                _ = becomeFirstResponder()
            }
        }
    }

    private let logger = GLogger(category: .auth)

    init(
        rootView: Content,
        allowsControllerUIFocus: Bool = false,
        onOverlayToggle: (() -> Void)? = nil
    ) {
        self.hostingController = UIHostingController(rootView: rootView)
        self.allowsControllerUIFocus = allowsControllerUIFocus
        self.onOverlayToggle = onOverlayToggle
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        // Disable controller-driven tvOS UI focus during gameplay so B/Menu reach the stream.
        // Re-enable while launch controls or the stream overlay need focusable buttons.
        controllerUserInteractionEnabled = allowsControllerUIFocus

        hostingController.view.backgroundColor = .clear
        hostingController.view.insetsLayoutMarginsFromSafeArea = false

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _ = becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if shouldSwallowPlayPausePress(presses) { return }
        if shouldSwallowMenuPress(presses) {
            logSwallowedMenuPress(phase: "began", presses: presses)
            return
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if shouldSwallowPlayPausePress(presses) {
            if StratixLaunchMode.allowsPlayPauseStreamOverlayToggle {
                onOverlayToggle?()
            }
            return
        }
        if shouldSwallowMenuPress(presses) {
            logSwallowedMenuPress(phase: "ended", presses: presses)
            return
        }
        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if shouldSwallowPlayPausePress(presses) { return }
        if shouldSwallowMenuPress(presses) {
            logSwallowedMenuPress(phase: "cancelled", presses: presses)
            return
        }
        super.pressesCancelled(presses, with: event)
    }

    private func logSwallowedMenuPress(phase: String, presses: Set<UIPress>) {
        guard GLogger.isEnabled else { return }
        logger.debug("Stream input host swallowed menu press (phase=\(phase), count=\(presses.count))")
    }

    private func shouldSwallowMenuPress(_ presses: Set<UIPress>) -> Bool {
        presses.contains { $0.type == .menu }
    }

    /// Xbox controller X maps to `UIPress.playPause` on tvOS. Swallow it so gameplay input
    /// stays on the GameController path and the stream overlay only opens via L3+R3 hold.
    private func shouldSwallowPlayPausePress(_ presses: Set<UIPress>) -> Bool {
        presses.contains { $0.type == .playPause }
    }
}
#else
struct StreamControllerInputHost<Content: View>: View {
    let content: Content

    init(
        allowsControllerUIFocus: Bool = false,
        onOverlayToggle: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        _ = allowsControllerUIFocus
        _ = onOverlayToggle
        self.content = content()
    }

    var body: some View { content }
}
#endif