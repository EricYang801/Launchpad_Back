import AppKit
import CoreImage

/// Launchpad's backdrop: the desktop picture, heavily blurred and dimmed.
enum Wallpaper {
    private static var cached: (key: String, image: NSImage)?
    /// Creating a Core Image context is costly; one is reused for every render.
    private nonisolated static let context = CIContext(options: [.cacheIntermediates: false])

    /// Returns nil for wallpapers that are not still images (e.g. dynamic aerials); callers fall back to a material.
    static func blurred(for screen: NSScreen) async -> NSImage? {
        guard var url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        #if DEBUG
        // README screenshots: `-BackdropImage <path>` blurs that image instead of the real wallpaper.
        if let path = UserDefaults.standard.string(forKey: "BackdropImage") { url = URL(fileURLWithPath: path) }
        #endif
        let modified =
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        let key = "\(url.path)|\(modified.timeIntervalSince1970)"
        if let cached, cached.key == key { return cached.image }

        let image = await Task.detached(priority: .userInitiated) { render(url) }.value
        if let image { cached = (key, image) }
        return image
    }

    private nonisolated static func render(_ url: URL) -> NSImage? {
        guard var image = CIImage(contentsOf: url) else { return nil }

        // Blur at a small size: the result is soft anyway and this keeps it fast.
        let scale = 640 / max(image.extent.width, 1)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = image.extent
        image = image.clampedToExtent()
            .applyingGaussianBlur(sigma: 18)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.15, kCIInputBrightnessKey: -0.12])
            .cropped(to: extent)

        guard let cgImage = context.createCGImage(image, from: extent) else { return nil }
        return NSImage(cgImage: cgImage, size: extent.size)
    }
}
