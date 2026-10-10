import AppKit

/// Loads app icons off the main thread and keeps them rasterized at the size they are shown,
/// so memory follows the grid's icon size instead of a fixed worst case.
final class IconCache {
    static let shared = IconCache()

    /// The sharpest screen attached; icons are rendered for it.
    static var displayScale: CGFloat { NSScreen.screens.map(\.backingScaleFactor).max() ?? 2 }

    private final class Entry {
        let image: NSImage
        let pixels: Int
        init(image: NSImage, pixels: Int) {
            self.image = image
            self.pixels = pixels
        }
    }

    private let cache = NSCache<NSURL, Entry>()
    private var inFlight: [URL: (pixels: Int, task: Task<NSImage, Never>)] = [:]

    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Side length in pixels for an icon shown at `points`, rounded up to a 32 px step so nearby sizes share a raster.
    static func pixels(for points: CGFloat) -> Int {
        let exact = Int((points * displayScale).rounded(.up))
        return min(max((exact + 31) / 32 * 32, 32), 512)
    }

    /// A cached icon at least `pixels` wide; a larger one serves smaller requests (e.g. folder previews).
    func cachedIcon(for url: URL, pixels: Int) -> NSImage? {
        guard let entry = cache.object(forKey: url as NSURL), entry.pixels >= pixels else { return nil }
        return entry.image
    }

    func icon(for url: URL, pixels: Int) async -> NSImage {
        if let image = cachedIcon(for: url, pixels: pixels) { return image }
        if let pending = inFlight[url], pending.pixels >= pixels { return await pending.task.value }

        let task = Task.detached(priority: .userInitiated) { Self.render(url, pixels: pixels) }
        inFlight[url] = (pixels, task)
        let image = await task.value
        if inFlight[url]?.pixels == pixels { inFlight[url] = nil }
        if (cache.object(forKey: url as NSURL)?.pixels ?? 0) < pixels {
            cache.setObject(Entry(image: image, pixels: pixels), forKey: url as NSURL, cost: pixels * pixels * 4)
        }
        return image
    }

    private nonisolated static func render(_ url: URL, pixels: Int) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let side = CGFloat(pixels)
        var rect = CGRect(x: 0, y: 0, width: side, height: side)
        guard let cgImage = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return icon }
        return NSImage(cgImage: cgImage, size: NSSize(width: side / 2, height: side / 2))
    }
}
