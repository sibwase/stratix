// CloudLibraryLibraryShoulderTabSwitch.swift
// Maps gamepad LB/RB to library header tab cycling via event-driven handlers.
//

import GameController
import SwiftUI
import UIKit

private struct LibraryGamepadChromeEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var libraryGamepadChromeEnabled: Bool {
        get { self[LibraryGamepadChromeEnabledKey.self] }
        set { self[LibraryGamepadChromeEnabledKey.self] = newValue }
    }
}

struct CloudLibraryLibraryShoulderTabSwitch: UIViewRepresentable {
    var isEnabled: Bool
    var onShoulderLeft: () -> Void
    var onShoulderRight: () -> Void
    var onThumbstickLeft: (() -> Void)? = nil
    var onThumbstickRight: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        context.coordinator.start()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onShoulderLeft = onShoulderLeft
        context.coordinator.onShoulderRight = onShoulderRight
        context.coordinator.onThumbstickLeft = onThumbstickLeft
        context.coordinator.onThumbstickRight = onThumbstickRight
        context.coordinator.updateBindings()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, @unchecked Sendable {
        var isEnabled = false
        var onShoulderLeft: (() -> Void)?
        var onShoulderRight: (() -> Void)?
        var onThumbstickLeft: (() -> Void)?
        var onThumbstickRight: (() -> Void)?

        private var observers: [NSObjectProtocol] = []
        private var isObserving = false
        private var wasStickLeft = false
        private var wasStickRight = false

        func start() {
            guard !isObserving else { return }
            isObserving = true

            observers = [
                NotificationCenter.default.addObserver(
                    forName: .GCControllerDidConnect,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updateBindings()
                },
                NotificationCenter.default.addObserver(
                    forName: .GCControllerDidDisconnect,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updateBindings()
                }
            ]

            updateBindings()
        }

        func stop() {
            guard isObserving else { return }
            isObserving = false
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            unbindHandlers()
        }

        private var boundControllerIDs: Set<ObjectIdentifier> = []

        func updateBindings() {
            let currentIDs = Set(GCController.controllers().map { ObjectIdentifier($0) })
            if !isEnabled {
                if !boundControllerIDs.isEmpty {
                    unbindHandlers()
                    boundControllerIDs.removeAll()
                }
                return
            }
            guard currentIDs != boundControllerIDs else { return }
            bindHandlers()
            boundControllerIDs = currentIDs
        }

        private func bindHandlers() {
            unbindHandlers()
            for controller in GCController.controllers() {
                guard let gamepad = controller.extendedGamepad else { continue }
                gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                    guard let self, self.isEnabled, pressed else { return }
                    DispatchQueue.main.async {
                        self.onShoulderLeft?()
                    }
                }
                gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                    guard let self, self.isEnabled, pressed else { return }
                    DispatchQueue.main.async {
                        self.onShoulderRight?()
                    }
                }
                gamepad.leftThumbstick.xAxis.valueChangedHandler = { [weak self] _, value in
                    guard let self, self.isEnabled else { return }
                    let isLeft = value < -0.75
                    let isRight = value > 0.75
                    if isLeft && !self.wasStickLeft {
                        DispatchQueue.main.async {
                            self.onThumbstickLeft?()
                        }
                    }
                    if isRight && !self.wasStickRight {
                        DispatchQueue.main.async {
                            self.onThumbstickRight?()
                        }
                    }
                    self.wasStickLeft = isLeft
                    self.wasStickRight = isRight
                }
            }
        }

        private func unbindHandlers() {
            for controller in GCController.controllers() {
                guard let gamepad = controller.extendedGamepad else { continue }
                gamepad.leftShoulder.pressedChangedHandler = nil
                gamepad.rightShoulder.pressedChangedHandler = nil
                gamepad.leftThumbstick.xAxis.valueChangedHandler = nil
            }
            boundControllerIDs.removeAll()
        }
    }
}