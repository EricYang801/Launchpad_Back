import XCTest
import AppKit
@testable import Launchpad_Back

final class AppIconResolverTests: XCTestCase {
    private var temporaryDirectoryURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppIconResolverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
        
        try super.tearDownWithError()
    }
    
    func testResolveIcon_UsesWorkspaceIconForDirectBundlePath() throws {
        let appURL = try makeAppBundle(named: "DirectIcon")
        let genericIcon = makeImage(color: .darkGray)
        let customIcon = makeImage(color: .systemBlue)
        let workspace = MockIconWorkspace(
            genericIcon: genericIcon,
            iconsByPath: [appURL.path: customIcon]
        )
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        
        let resolution = resolver.resolveIcon(for: appURL.path, appName: "Direct Icon")
        
        XCTAssertSource(resolution.source, matches: .workspace)
        XCTAssertEqual(resolution.cacheKey, appURL.path)
        XCTAssertEqual(workspace.requestedPaths, [appURL.path])
        XCTAssertFalse(resolver.isGenericAppIcon(resolution.image))
    }
    
    func testResolveIcon_ResolvesSymlinkBundlePathBeforeUsingWorkspaceIcon() throws {
        let actualAppURL = try makeAppBundle(named: "ActualApp")
        let symlinkURL = temporaryDirectoryURL.appendingPathComponent("Alias.app")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: actualAppURL)
        
        let genericIcon = makeImage(color: .darkGray)
        let customIcon = makeImage(color: .systemRed)
        let workspace = MockIconWorkspace(
            genericIcon: genericIcon,
            iconsByPath: [
                symlinkURL.path: genericIcon,
                actualAppURL.path: customIcon
            ]
        )
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        
        let resolution = resolver.resolveIcon(for: symlinkURL.path, appName: "Alias")
        
        XCTAssertSource(resolution.source, matches: .workspace)
        XCTAssertEqual(resolution.cacheKey, actualAppURL.path)
        XCTAssertEqual(workspace.requestedPaths, [symlinkURL.path, actualAppURL.path])
        XCTAssertFalse(resolver.isGenericAppIcon(resolution.image))
    }
    
    func testResolveIcon_FallsBackToMetadataIconWhenWorkspaceReturnsGenericIcon() throws {
        let appURL = try makeAppBundle(
            named: "MetadataApp",
            infoPlist: [
                "CFBundleIconFile": "metadata-icon"
            ],
            resourceIcons: [
                "metadata-icon.png": makeImage(color: .systemGreen)
            ]
        )
        let genericIcon = makeImage(color: .darkGray)
        let workspace = MockIconWorkspace(genericIcon: genericIcon)
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        
        let resolution = resolver.resolveIcon(for: appURL.path, appName: "Metadata App")
        
        XCTAssertSource(resolution.source, matches: .metadata)
        XCTAssertEqual(resolution.cacheKey, appURL.path)
        XCTAssertTrue(resolver.isGenericAppIcon(genericIcon))
        XCTAssertFalse(resolver.isGenericAppIcon(resolution.image))
    }
    
    func testResolveIcon_GeneratesCustomFallbackWhenBundleHasNoIconMetadata() throws {
        let appURL = try makeAppBundle(named: "FallbackApp")
        let genericIcon = makeImage(color: .darkGray)
        let workspace = MockIconWorkspace(genericIcon: genericIcon)
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        
        let resolution = resolver.resolveIcon(for: appURL.path, appName: "哔哩哔哩")
        
        XCTAssertSource(resolution.source, matches: .fallback)
        XCTAssertEqual(resolution.cacheKey, appURL.path)
        XCTAssertFalse(resolver.isGenericAppIcon(resolution.image))
    }
    
    func testCache_UsesResolvedBundlePathForSymlinkAndCanonicalPath() throws {
        let actualAppURL = try makeAppBundle(named: "CachedActual")
        let symlinkURL = temporaryDirectoryURL.appendingPathComponent("CachedAlias.app")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: actualAppURL)
        
        let genericIcon = makeImage(color: .darkGray)
        let customIcon = makeImage(color: .systemOrange)
        let workspace = MockIconWorkspace(
            genericIcon: genericIcon,
            iconsByPath: [
                symlinkURL.path: genericIcon,
                actualAppURL.path: customIcon
            ]
        )
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        let cache = AppIconCache(resolver: resolver)
        
        let symlinkIcon = try XCTUnwrap(cache.getIcon(for: symlinkURL.path, appName: "Cached Alias"))
        let canonicalIcon = try XCTUnwrap(cache.getIcon(for: actualAppURL.path, appName: "Cached Alias"))
        
        XCTAssertEqual(workspace.requestedPaths, [symlinkURL.path, actualAppURL.path])
        XCTAssertNotNil(cache.cachedIcon(for: symlinkURL.path))
        XCTAssertNotNil(cache.cachedIcon(for: actualAppURL.path))
        XCTAssertEqual(imageFingerprint(for: symlinkIcon), imageFingerprint(for: canonicalIcon))
    }

    func testResolveIcon_IsSafeAcrossConcurrentBackgroundRequests() throws {
        let appURL = try makeAppBundle(named: "ConcurrentIcon")
        let genericIcon = makeImage(color: .darkGray)
        let customIcon = makeImage(color: .systemPurple)
        let workspace = MockIconWorkspace(
            genericIcon: genericIcon,
            iconsByPath: [appURL.path: customIcon]
        )
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        let iterationCount = 12
        let completionExpectation = expectation(description: "concurrent icon resolution completes")
        completionExpectation.expectedFulfillmentCount = iterationCount
        let resultsLock = NSLock()
        var results: [Bool] = []
        
        for _ in 0..<iterationCount {
            DispatchQueue.global(qos: .userInitiated).async {
                let resolution = resolver.resolveIcon(for: appURL.path, appName: "Concurrent Icon")
                let isGeneric = resolver.isGenericAppIcon(resolution.image)
                resultsLock.lock()
                results.append(isGeneric)
                resultsLock.unlock()
                completionExpectation.fulfill()
            }
        }
        
        wait(for: [completionExpectation], timeout: 15)
        XCTAssertEqual(results.count, iterationCount)
        XCTAssertTrue(results.allSatisfy { $0 == false })
    }

    func testGetIconAsync_DeliversResultToRequestsThatJoinInFlightLoad() throws {
        let appURL = try makeAppBundle(named: "AsyncJoinedIcon")
        let genericIcon = makeImage(color: .darkGray)
        let customIcon = makeImage(color: .systemYellow)
        let workspace = DelayedIconWorkspace(
            genericIcon: genericIcon,
            iconsByPath: [appURL.path: customIcon],
            delay: 0.15
        )
        let resolver = AppIconResolver(fileManager: .default, workspace: workspace)
        let cache = AppIconCache(resolver: resolver)
        let firstExpectation = expectation(description: "first async icon callback")
        let secondExpectation = expectation(description: "second async icon callback")
        var fingerprints: [Data?] = [nil, nil]

        cache.getIconAsync(for: appURL.path, appName: "Async Joined Icon") { icon in
            fingerprints[0] = icon.flatMap { self.imageFingerprint(for: $0) }
            firstExpectation.fulfill()
        }
        cache.getIconAsync(for: appURL.path, appName: "Async Joined Icon") { icon in
            fingerprints[1] = icon.flatMap { self.imageFingerprint(for: $0) }
            secondExpectation.fulfill()
        }

        wait(for: [firstExpectation, secondExpectation], timeout: 5)

        XCTAssertNotNil(fingerprints[0])
        XCTAssertEqual(fingerprints[0], fingerprints[1])
        XCTAssertEqual(workspace.requestedPaths, [appURL.path])
    }
    
    private func makeAppBundle(
        named name: String,
        infoPlist: [String: Any] = [:],
        resourceIcons: [String: NSImage] = [:]
    ) throws -> URL {
        let appURL = temporaryDirectoryURL.appendingPathComponent("\(name).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        
        var plist: [String: Any] = [
            "CFBundleIdentifier": "com.test.\(name)",
            "CFBundleName": name,
            "CFBundlePackageType": "APPL"
        ]
        infoPlist.forEach { plist[$0.key] = $0.value }
        
        let plistURL = contentsURL.appendingPathComponent("Info.plist")
        let plistDictionary = NSDictionary(dictionary: plist)
        XCTAssertTrue(plistDictionary.write(to: plistURL, atomically: true))
        
        for (fileName, image) in resourceIcons {
            let fileURL = resourcesURL.appendingPathComponent(fileName)
            try writePNGImage(image, to: fileURL)
        }
        
        return appURL
    }
    
    private func writePNGImage(_ image: NSImage, to url: URL) throws {
        let imageData = try XCTUnwrap(imageFingerprint(for: image))
        try imageData.write(to: url)
    }
    
    private func makeImage(color: NSColor, size: CGFloat = 128) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: imageSize), xRadius: size * 0.2, yRadius: size * 0.2).fill()
        image.unlockFocus()
        
        return image
    }
    
    private func imageFingerprint(for image: NSImage) -> Data? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 64,
            pixelsHigh: 64,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let bitmap else {
            return nil
        }
        
        bitmap.size = NSSize(width: 64, height: 64)
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(x: 0, y: 0, width: 64, height: 64),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()
        
        return bitmap.representation(using: .png, properties: [:])
    }
}

private final class MockIconWorkspace: AppIconWorkspaceProviding {
    private let genericIconImage: NSImage
    private let iconsByPath: [String: NSImage]
    private let lock = NSLock()
    
    private(set) var requestedPaths: [String] = []
    
    init(genericIcon: NSImage, iconsByPath: [String: NSImage] = [:]) {
        self.genericIconImage = genericIcon
        self.iconsByPath = iconsByPath
    }
    
    func icon(forFile path: String) -> NSImage {
        lock.lock()
        requestedPaths.append(path)
        let icon = iconsByPath[path] ?? genericIconImage
        lock.unlock()
        return icon
    }
    
    func genericApplicationIcon() -> NSImage {
        genericIconImage
    }
}

private final class DelayedIconWorkspace: AppIconWorkspaceProviding {
    private let genericIconImage: NSImage
    private let iconsByPath: [String: NSImage]
    private let delay: TimeInterval
    private let lock = NSLock()

    private(set) var requestedPaths: [String] = []

    init(genericIcon: NSImage, iconsByPath: [String: NSImage] = [:], delay: TimeInterval) {
        self.genericIconImage = genericIcon
        self.iconsByPath = iconsByPath
        self.delay = delay
    }

    func icon(forFile path: String) -> NSImage {
        Thread.sleep(forTimeInterval: delay)
        lock.lock()
        requestedPaths.append(path)
        let icon = iconsByPath[path] ?? genericIconImage
        lock.unlock()
        return icon
    }

    func genericApplicationIcon() -> NSImage {
        genericIconImage
    }
}

private extension AppIconResolverTests {
    func XCTAssertSource(
        _ source: AppIconResolver.Source,
        matches expected: AppIconResolver.Source,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (source, expected) {
        case (.workspace, .workspace), (.metadata, .metadata), (.fallback, .fallback):
            return
        default:
            XCTFail("Expected source \(expected), got \(source)", file: file, line: line)
        }
    }
}
