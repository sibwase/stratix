// NetworkTransportError.swift
// Classifies TLS / connectivity failures that should not wipe an existing session.
//

import Foundation

enum NetworkTransportError {
    /// True for TLS handshake resets, timeouts, and other path failures that often
    /// recover without invalidating cached Microsoft / xCloud tokens.
    static func isTransient(_ error: Error) -> Bool {
        isTransient(error as NSError, depth: 0)
    }

    private static func isTransient(_ error: NSError, depth: Int) -> Bool {
        guard depth < 4 else { return false }

        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorSecureConnectionFailed,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorInternationalRoamingOff,
                 NSURLErrorCallIsActive,
                 NSURLErrorDataNotAllowed:
                return true
            default:
                break
            }
        }

        if error.domain == "kCFErrorDomainCFNetwork" {
            switch error.code {
            case -9816, -9806, -9830, -1200:
                return true
            default:
                break
            }
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isTransient(underlying, depth: depth + 1)
        }
        return false
    }
}
