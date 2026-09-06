// CachedRemoteImage.swift
// Defines cached remote image for the Shared / Components surface.
//

import SwiftUI
import UIKit
import StratixCore

/// Shared SwiftUI image view that bridges view-driven artwork identity to the actor-backed
/// remote image pipeline and only updates displayed artwork when the cache identity changes.
struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    var kind: ArtworkKind = .poster
    var priority: ArtworkPriority = .normal
    var maxPixelSize: CGFloat? = nil
    var contentMode: ContentMode = .fill
    var adjustsImageWhenAncestorFocused: Bool = false
    var isFocused: Bool = false
    var cornerRadius: CGFloat = 0
    var onImageLoaded: (() -> Void)? = nil
    let placeholder: () -> Placeholder
    private let cacheIdentity: String

    @State private var image: UIImage?
    @State private var displayKey: String?

    init(
        url: URL?,
        kind: ArtworkKind = .poster,
        priority: ArtworkPriority = .normal,
        maxPixelSize: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        adjustsImageWhenAncestorFocused: Bool = false,
        isFocused: Bool = false,
        cornerRadius: CGFloat = 0,
        onImageLoaded: (() -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.kind = kind
        self.priority = priority
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
        self.adjustsImageWhenAncestorFocused = adjustsImageWhenAncestorFocused
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
        self.onImageLoaded = onImageLoaded
        self.placeholder = placeholder

        let identity = Self.makeCacheIdentity(url: url, kind: kind, maxPixelSize: maxPixelSize)
        self.cacheIdentity = identity
        _image = State(initialValue: nil)
        _displayKey = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let image {
                if adjustsImageWhenAncestorFocused {
                    NativeTVFocusPoster(
                        image: image,
                        cornerRadius: cornerRadius,
                        contentMode: contentMode,
                        isFocused: isFocused
                    )
                    .transition(.opacity)
                    .onAppear {
                        onImageLoaded?()
                    }
                } else {
                    posterImage(image)
                        .transition(.opacity)
                        .onAppear {
                            onImageLoaded?()
                        }
                }
            } else {
                placeholder()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: displayKey)
        .task(id: cacheIdentity) {
            await loadImage()
        }
    }

    @ViewBuilder
    private func posterImage(_ image: UIImage) -> some View {
        let rendered = Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
        if cornerRadius > 0 {
            rendered.clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            rendered
        }
    }

    private static func makeCacheIdentity(
        url: URL?,
        kind: ArtworkKind,
        maxPixelSize: CGFloat?
    ) -> String {
        "\(url?.absoluteString ?? "nil")|\(kind.rawValue)|\(maxPixelSize.map { String(Int($0)) } ?? "full")"
    }

    /// Clears stale displayed artwork before awaiting a replacement so reused SwiftUI cells do
    /// not briefly show the wrong remote image.
    @MainActor
    private func loadImage() async {
        guard let url else {
            clearImage()
            return
        }
        let cacheKey = cacheIdentity
        if displayKey == cacheKey, image != nil {
            return
        }
        if let cached = await RemoteImagePipeline.shared.cachedImage(for: cacheKey) {
            displayImage(cached, for: cacheKey)
            return
        }

        clearImageIfDisplayingDifferentKey(cacheKey)

        guard let loaded = await RemoteImagePipeline.shared.image(
            for: ArtworkRequest(url: url, kind: kind, priority: priority),
            cacheKey: cacheKey,
            maxPixelSize: maxPixelSize
        ) else {
            return
        }

        displayImage(loaded, for: cacheKey)
    }

    @MainActor
    private func clearImage() {
        image = nil
        displayKey = nil
    }

    @MainActor
    private func clearImageIfDisplayingDifferentKey(_ cacheKey: String) {
        guard displayKey != cacheKey else { return }
        image = nil
    }

    @MainActor
    private func displayImage(_ image: UIImage, for cacheKey: String) {
        self.image = image
        displayKey = cacheKey
    }
}


/// Native tvOS poster: `UIImageView.adjustsImageWhenAncestorFocused` provides system
/// specular lighting that tracks Siri Remote touch and a smooth focus lift.
private struct NativeTVFocusPoster: UIViewRepresentable {
    var image: UIImage?
    var cornerRadius: CGFloat
    var contentMode: ContentMode = .fill
    var isFocused: Bool = false

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.adjustsImageWhenAncestorFocused = true
        view.masksFocusEffectToContents = true
        view.clipsToBounds = false
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.cornerCurve = .continuous
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        apply(to: uiView)
        // Keep native specular/motion, cancel the system image zoom so details stay sharp.
        if isFocused, uiView.bounds.width > 1 {
            let focusedSize = uiView.focusedFrameGuide.layoutFrame.size
            var scaleX = focusedSize.width / uiView.bounds.width
            var scaleY = focusedSize.height / uiView.bounds.height
            if scaleX < 1.02 { scaleX = 1.12 }
            if scaleY < 1.02 { scaleY = 1.12 }
            uiView.transform = CGAffineTransform(scaleX: 1 / scaleX, y: 1 / scaleY)
        } else {
            uiView.transform = .identity
        }
    }

    private func apply(to view: UIImageView) {
        view.image = image
        view.layer.cornerRadius = cornerRadius
        view.contentMode = contentMode == .fit ? .scaleAspectFit : .scaleAspectFill
        view.adjustsImageWhenAncestorFocused = true
        view.masksFocusEffectToContents = true
        view.clipsToBounds = false
    }
}
