// StreamLaunchCancellation.swift
// Defines stream launch cancellation helpers for the Streaming surface.
//

import Foundation

enum StreamLaunchCancellation {
    static func throwIfCancelled() throws {
        try Task.checkCancellation()
    }

    static func isCancelled() -> Bool {
        Task.isCancelled
    }
}