// StreamLaunchCancelGate.swift
// Ignores the button press that started a stream so leftover A cannot cancel launch.
//

import Foundation

/// Rising-edge detector for "A cancels stream launch".
///
/// The same A press that activates Play is often still held when launch input
/// observation attaches. Treat that held press as already consumed, and only
/// cancel after A has been released and pressed again.
struct StreamLaunchCancelGate {
    private var previousAPressed: Bool
    private var hasSeenAReleased: Bool

    init(isAPressed: Bool) {
        previousAPressed = isAPressed
        hasSeenAReleased = !isAPressed
    }

    /// Returns `true` when a fresh A press should cancel an in-flight launch.
    mutating func registerAPressed(_ aPressed: Bool) -> Bool {
        if !aPressed {
            hasSeenAReleased = true
            previousAPressed = false
            return false
        }

        let isRisingEdge = !previousAPressed
        previousAPressed = true
        return hasSeenAReleased && isRisingEdge
    }
}
