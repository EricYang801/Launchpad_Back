//
//  AppIconResolver.swift
//  Launchpad_Back
//
//  Created by Codex on 2026/4/6.
//

import AppKit
import UniformTypeIdentifiers

protocol AppIconWorkspaceProviding {
    func icon(forFile path: String) -> NSImage
    func genericApplicationIcon() -> NSImage
}

extension NSWorkspace: AppIconWorkspaceProviding {
    func genericApplicationIcon() -> NSImage {
        icon(for: .application)
    }
}

final class AppIconResolver {
    enum Source: Equatable {
        case workspace
        case metadata
        case fallback
    }
    
    struct Resolution {
        let cacheKey: String
        let image: NSImage
        let source: Source
    }
    
    static let shared = AppIconResolver()
    
    private let fileManager: FileManager
    private let workspace: AppIconWorkspaceProviding
    private let lock = NSLock()
    private let comparisonSize = NSSize(width: 64, height: 64)
    private let fallbackPalette: [(NSColor, NSColor)] = [
        (.systemBlue, NSColor(calibratedRed: 0.17, green: 0.49, blue: 0.96, alpha: 1)),
        (.systemTeal, NSColor(calibratedRed: 0.09, green: 0.67, blue: 0.70, alpha: 1)),
        (.systemGreen, NSColor(calibratedRed: 0.20, green: 0.67, blue: 0.35, alpha: 1)),
        (.systemOrange, NSColor(calibratedRed: 0.93, green: 0.48, blue: 0.16, alpha: 1)),
        (.systemPink, NSColor(calibratedRed: 0.84, green: 0.28, blue: 0.58, alpha: 1)),
        (.systemIndigo, NSColor(calibratedRed: 0.39, green: 0.35, blue: 0.92, alpha: 1)),
    ]
    private var canonicalPathCache: [String: String] = [:]
    private var missingCanonicalPaths: Set<String> = []
    private var genericIconFingerprint: Data?
    private var hasComputedGenericIconFingerprint = false
    
    init(
        fileManager: FileManager = .default,
        workspace: AppIconWorkspaceProviding = NSWorkspace.shared
    ) {
        self.fileManager = fileManager
        self.workspace = workspace
    }
    
    func cacheKey(for path: String) -> String {
        canonicalBundlePath(for: path) ?? standardizedPath(path)
    }
    
    func resolvedBundlePath(for path: String) -> String? {
        canonicalBundlePath(for: path)
    }
    
    func resolveIcon(for path: String, appName: String? = nil, targetSize: CGFloat = 96) -> Resolution {
        let standardizedOriginalPath = standardizedPath(path)
        let resolvedBundlePath = canonicalBundlePath(for: standardizedOriginalPath)
        let resolvedCacheKey = resolvedBundlePath ?? standardizedOriginalPath
        let candidatePaths = uniquePaths([
            standardizedOriginalPath,
            resolvedBundlePath
        ].compactMap { $0 })
        
        for candidatePath in candidatePaths where fileManager.fileExists(atPath: candidatePath) {
            let icon = performGraphicsWork {
                workspace.icon(forFile: candidatePath)
            }
            if !isGenericAppIcon(icon) {
                return Resolution(cacheKey: resolvedCacheKey, image: icon, source: .workspace)
            }
        }
        
        if let resolvedBundlePath,
           let metadataIcon = metadataIcon(forBundlePath: resolvedBundlePath) {
            return Resolution(cacheKey: resolvedCacheKey, image: metadataIcon, source: .metadata)
        }
        
        let fallbackName = appName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? appName!
            : fallbackDisplayName(for: resolvedBundlePath ?? standardizedOriginalPath)
        
        return Resolution(
            cacheKey: resolvedCacheKey,
            image: fallbackIcon(forAppNamed: fallbackName, size: targetSize),
            source: .fallback
        )
    }
    
    func isGenericAppIcon(_ image: NSImage) -> Bool {
        guard let genericIconFingerprint = genericIconFingerprintData() else {
            return false
        }
        
        return performGraphicsWork {
            normalizedPNGData(for: image) == genericIconFingerprint
        }
    }
    
    func fallbackIcon(forAppNamed appName: String, size: CGFloat) -> NSImage {
        performGraphicsWork {
            let imageSize = NSSize(width: size, height: size)
            let image = NSImage(size: imageSize)
            let label = fallbackLabel(from: appName)
            let palette = fallbackPalette[colorIndex(for: appName)]
            let rect = NSRect(origin: .zero, size: imageSize)
            let inset = max(1, size * 0.025)
            let iconRect = rect.insetBy(dx: inset, dy: inset)
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
            shadow.shadowBlurRadius = size * 0.08
            shadow.shadowOffset = NSSize(width: 0, height: -size * 0.03)
            
            image.lockFocus()
            defer { image.unlockFocus() }
            
            NSColor.clear.setFill()
            rect.fill()
            
            let backgroundPath = NSBezierPath(
                roundedRect: iconRect,
                xRadius: size * 0.22,
                yRadius: size * 0.22
            )
            shadow.set()
            NSGradient(colors: [palette.0, palette.1])?.draw(in: backgroundPath, angle: -45)
            
            NSColor.white.withAlphaComponent(0.14).setStroke()
            backgroundPath.lineWidth = max(1, size * 0.025)
            backgroundPath.stroke()
            
            let titleShadow = NSShadow()
            titleShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
            titleShadow.shadowBlurRadius = size * 0.06
            titleShadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)
            
            let fontSize = size * (label.count > 1 ? 0.32 : 0.42)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.white,
                .shadow: titleShadow
            ]
            let attributedString = NSAttributedString(string: label, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = NSRect(
                x: rect.midX - textSize.width / 2,
                y: rect.midY - textSize.height / 2 - size * 0.02,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            
            return image
        }
    }
    
    private func canonicalBundlePath(for path: String) -> String? {
        let standardized = standardizedPath(path)
        lock.lock()
        if let cachedPath = canonicalPathCache[standardized] {
            lock.unlock()
            return cachedPath
        }
        if missingCanonicalPaths.contains(standardized) {
            lock.unlock()
            return nil
        }
        lock.unlock()

        let resolved = URL(fileURLWithPath: standardized).resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalPath = uniquePaths([
            bundlePath(containing: resolved),
            bundlePath(containing: standardized)
        ].compactMap { $0 }).first(where: { fileManager.fileExists(atPath: $0) })

        lock.lock()
        if let canonicalPath {
            canonicalPathCache[standardized] = canonicalPath
            canonicalPathCache[resolved] = canonicalPath
        } else {
            missingCanonicalPaths.insert(standardized)
            missingCanonicalPaths.insert(resolved)
        }
        lock.unlock()

        return canonicalPath
    }
    
    private func bundlePath(containing path: String) -> String? {
        var url = URL(fileURLWithPath: path)
        
        while true {
            if url.pathExtension.lowercased() == "app" {
                return url.standardizedFileURL.path
            }
            
            let parentURL = url.deletingLastPathComponent()
            if parentURL.path == url.path {
                return nil
            }
            
            url = parentURL
        }
    }
    
    private func metadataIcon(forBundlePath bundlePath: String) -> NSImage? {
        let infoPlistPath = bundlePath + "/Contents/Info.plist"
        let resourcesPath = bundlePath + "/Contents/Resources"
        
        guard let infoPlist = NSDictionary(contentsOfFile: infoPlistPath) as? [String: Any],
              fileManager.fileExists(atPath: resourcesPath) else {
            return nil
        }
        
        for iconName in metadataIconNames(from: infoPlist) {
            if let image = iconImage(named: iconName, resourcesPath: resourcesPath) {
                return image
            }
        }
        
        return nil
    }
    
    private func metadataIconNames(from infoPlist: [String: Any]) -> [String] {
        var names: [String] = []
        
        appendIconNames(from: infoPlist["CFBundleIconFile"], to: &names)
        appendIconNames(from: infoPlist["CFBundleIconName"], to: &names)
        appendIconNames(from: infoPlist["CFBundleIconFiles"], to: &names)
        appendIconNames(from: infoPlist["CFBundleIcons"], to: &names)
        appendIconNames(from: infoPlist["CFBundleIcons~mac"], to: &names)
        
        var seen = Set<String>()
        return names.filter { name in
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return false }
            return seen.insert(normalized.lowercased()).inserted
        }
    }
    
    private func appendIconNames(from value: Any?, to names: inout [String]) {
        switch value {
        case let string as String:
            names.append(string)
        case let strings as [String]:
            names.append(contentsOf: strings)
        case let values as [Any]:
            for value in values {
                appendIconNames(from: value, to: &names)
            }
        case let dictionary as [String: Any]:
            appendIconNames(from: dictionary["CFBundleIconFile"], to: &names)
            appendIconNames(from: dictionary["CFBundleIconName"], to: &names)
            appendIconNames(from: dictionary["CFBundleIconFiles"], to: &names)
            appendIconNames(from: dictionary["CFBundlePrimaryIcon"], to: &names)
        default:
            break
        }
    }
    
    private func iconImage(named iconName: String, resourcesPath: String) -> NSImage? {
        let candidateFileNames = resourceCandidates(for: iconName)
        
        for candidateFileName in candidateFileNames {
            let candidatePath = (resourcesPath as NSString).appendingPathComponent(candidateFileName)
            if let image = loadImage(at: candidatePath) {
                return image
            }
        }
        
        let targetBaseNames = Set(candidateFileNames.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent.lowercased()
        })
        let allowedExtensions = Set(["icns", "png", "pdf", "tiff", "tif"])
        
        guard let enumerator = fileManager.enumerator(atPath: resourcesPath) else {
            return nil
        }
        
        while let relativePath = enumerator.nextObject() as? String {
            let url = URL(fileURLWithPath: relativePath)
            let pathExtension = url.pathExtension.lowercased()
            guard allowedExtensions.contains(pathExtension) else {
                continue
            }
            
            let baseName = url.deletingPathExtension().lastPathComponent.lowercased()
            guard targetBaseNames.contains(baseName) else {
                continue
            }
            
            let candidatePath = (resourcesPath as NSString).appendingPathComponent(relativePath)
            if let image = loadImage(at: candidatePath) {
                return image
            }
        }
        
        return nil
    }
    
    private func resourceCandidates(for iconName: String) -> [String] {
        let trimmedName = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return []
        }
        
        let url = URL(fileURLWithPath: trimmedName)
        if !url.pathExtension.isEmpty {
            return [trimmedName]
        }
        
        return [
            trimmedName + ".icns",
            trimmedName + ".png",
            trimmedName + "@2x.png",
            trimmedName + ".pdf",
            trimmedName + ".tiff",
            trimmedName
        ]
    }
    
    private func loadImage(at path: String) -> NSImage? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        
        guard let image = performGraphicsWork({
            NSImage(contentsOfFile: path)
        }),
        image.size.width > 0 else {
            return nil
        }
        
        return image
    }
    
    private func fallbackDisplayName(for path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
    
    private func fallbackLabel(from appName: String) -> String {
        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return "A"
        }
        
        let tokens = trimmedName.split { character in
            character.isWhitespace || character == "-" || character == "_" || character == "."
        }
        
        let initials = tokens.prefix(2).compactMap { token in
            token.first.map(String.init)
        }.joined()
        
        let label = initials.isEmpty ? String(trimmedName.prefix(2)) : initials
        return label.uppercased()
    }
    
    private func colorIndex(for appName: String) -> Int {
        abs(appName.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult * 31) + Int(scalar.value)
        }) % fallbackPalette.count
    }
    
    private func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
    
    private func uniquePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    private func genericIconFingerprintData() -> Data? {
        lock.lock()
        if hasComputedGenericIconFingerprint {
            let cachedFingerprint = genericIconFingerprint
            lock.unlock()
            return cachedFingerprint
        }
        lock.unlock()
        
        let computedFingerprint = performGraphicsWork {
            normalizedPNGData(for: workspace.genericApplicationIcon())
        }
        
        lock.lock()
        if !hasComputedGenericIconFingerprint {
            genericIconFingerprint = computedFingerprint
            hasComputedGenericIconFingerprint = true
        }
        let cachedFingerprint = genericIconFingerprint
        lock.unlock()
        
        return cachedFingerprint
    }

    private func performGraphicsWork<T>(_ work: () -> T) -> T {
        if Thread.isMainThread {
            return work()
        }
        
        return DispatchQueue.main.sync(execute: work)
    }
    
    private func normalizedPNGData(for image: NSImage) -> Data? {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(comparisonSize.width),
            pixelsHigh: Int(comparisonSize.height),
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
        
        bitmap.size = comparisonSize
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: comparisonSize).fill()
        image.draw(
            in: NSRect(origin: .zero, size: comparisonSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()
        
        return bitmap.representation(using: .png, properties: [:])
    }
}
