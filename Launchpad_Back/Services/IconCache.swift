import AppKit

/// Loads app icons off the main thread and keeps them rasterized at a size that stays sharp on Retina screens.
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage, Never>] = [:]
    /// 256 px covers the largest icon (128 pt) at 2x.
    private nonisolated static let pixelSize = 256

    private init() {
        cache.totalCostLimit = 128 * 1024 * 1024
    }

    func cachedIcon(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func icon(for url: URL) async -> NSImage {
        if let image = cachedIcon(for: url) { return image }
        if let task = inFlight[url] { return await task.value }

        let task = Task.detached(priority: .userInitiated) { Self.render(url) }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        cache.setObject(image, forKey: url as NSURL, cost: Self.pixelSize * Self.pixelSize * 4)
        return image
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private nonisolated static func render(_ url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let side = CGFloat(pixelSize)
        var rect = CGRect(x: 0, y: 0, width: side, height: side)
        guard let cgImage = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return icon }
        return NSImage(cgImage: cgImage, size: NSSize(width: side / 2, height: side / 2))
    }
}
