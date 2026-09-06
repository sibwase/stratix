// RemoteImagePipeline.swift
// Defines remote image pipeline for the Shared / Theme surface.
//

import UIKit
import ImageIO
import StratixCore
import OSLog
import os.signpost

/// Actor-backed shared artwork loader that deduplicates in-flight requests and keeps a decoded
/// UIImage cache for the SwiftUI image views layered on top of it.
actor RemoteImagePipeline {
    static let shared = RemoteImagePipeline()
    private static let perfSignpostLog = OSLog(subsystem: "com.stratix.app", category: "CloudLibraryPerf")
    // Visible-tile decode budget; NSCache evicts under library-grid pressure.
    private static let decodedCountLimit = 64
    private static let decodedCostLimit = 48 * 1_024 * 1_024

    private let decodedCache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        decodedCache.countLimit = Self.decodedCountLimit
        decodedCache.totalCostLimit = Self.decodedCostLimit
    }

    /// Returns a previously decoded image without starting any new network or decode work.
    func cachedImage(for key: String) -> UIImage? {
        decodedCache.object(forKey: key as NSString)
    }

    /// Resolves one artwork request through the decoded cache, in-flight dedupe map, and
    /// fetch/decode pipeline in that order.
    func image(
        for request: ArtworkRequest,
        cacheKey: String,
        maxPixelSize: CGFloat?
    ) async -> UIImage? {
        if let cached = decodedCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        if let task = inFlight[cacheKey] {
            return await task.value
        }

        #if DEBUG
        let signpostID = OSSignpostID(log: Self.perfSignpostLog)
        os_signpost(
            .begin,
            log: Self.perfSignpostLog,
            name: "ArtworkRequest",
            signpostID: signpostID,
            "kind=%{public}s",
            request.kind.rawValue
        )
        #endif

        let task = Task.detached(priority: Self.taskPriority(for: request.priority)) {
            await Self.fetchImage(request: request, maxPixelSize: maxPixelSize)
        }
        inFlight[cacheKey] = task
        let image = await task.value
        inFlight[cacheKey] = nil

        if let image {
            let cacheNSString = cacheKey as NSString
            if decodedCache.object(forKey: cacheNSString) == nil {
                decodedCache.setObject(
                    image,
                    forKey: cacheNSString,
                    cost: Self.imageCostBytes(image)
                )
            }
        }

        #if DEBUG
        os_signpost(
            .end,
            log: Self.perfSignpostLog,
            name: "ArtworkRequest",
            signpostID: signpostID,
            "kind=%{public}s source=%{public}s",
            request.kind.rawValue,
            image == nil ? "pipeline_miss" : "shared_pipeline"
        )
        #endif
        return image
    }

    private static func fetchImage(request: ArtworkRequest, maxPixelSize: CGFloat?) async -> UIImage? {
        guard let response = try? await ArtworkPipeline.shared.data(for: request) else {
            return nil
        }
        return decodeImage(from: response.data, maxPixelSize: maxPixelSize)
    }

    /// Applies thumbnail decoding when a pixel-size hint exists so large hero/poster assets
    /// do not always inflate to full source size in memory.
    private static func decodeImage(from data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        if let maxPixelSize,
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize),
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceShouldCache: true
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return UIImage(cgImage: cgImage)
            }
        }

        return UIImage(data: data)
    }

    private static func imageCostBytes(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    private static func taskPriority(for priority: ArtworkPriority) -> TaskPriority {
        switch priority {
        case .low:
            return .utility
        case .normal:
            return .userInitiated
        case .high, .immediate:
            return .high
        }
    }
}
