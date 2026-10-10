import AppKit
import XCTest
@testable import Launchpad_Back

final class GridMetricsTests: XCTestCase {
    private let grid = GridMetrics.main(in: CGSize(width: 1440, height: 900), columns: 7, rows: 5)

    func testSlotAndCenterRoundTrip() {
        for slot in 0..<grid.perPage {
            XCTAssertEqual(grid.slot(at: grid.center(of: slot)), slot)
            XCTAssertEqual(grid.slot(at: grid.iconCenter(of: slot)), slot)
        }
        XCTAssertNil(grid.slot(at: CGPoint(x: 1, y: 1)))
    }

    func testCentersRepeatOnEveryPage() {
        XCTAssertEqual(grid.center(of: grid.perPage + 3), grid.center(of: 3))
    }

    func testPageCount() {
        XCTAssertEqual(grid.pageCount(for: 0), 1)
        XCTAssertEqual(grid.pageCount(for: 35), 1)
        XCTAssertEqual(grid.pageCount(for: 36), 2)
    }

    func testOverIconOnlyNearTheIcon() {
        XCTAssertTrue(grid.isOverIcon(grid.iconCenter(of: 3), slot: 3))
        let corner = CGPoint(x: grid.frame.minX + 2, y: grid.frame.minY + 2)
        XCTAssertFalse(grid.isOverIcon(corner, slot: 0))
    }

    func testIconSizeIsSensible() {
        XCTAssertGreaterThan(grid.iconSize, 60)
        XCTAssertLessThanOrEqual(grid.iconSize, 128)
    }

    func testFolderGridIsCenteredAndSmaller() {
        let folder = GridMetrics.folder(in: CGSize(width: 1440, height: 900), main: grid, appCount: 4)
        XCTAssertEqual(folder.columns, 5)
        XCTAssertEqual(folder.rows, 1)
        XCTAssertEqual(folder.frame.midX, 720, accuracy: 0.5)
        XCTAssertEqual(folder.cellSize.width, grid.cellSize.width, accuracy: 0.001)
    }
}

final class AppScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeBundle(_ path: String, info: [String: Any]?) throws {
        let contents = root.appendingPathComponent(path).appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        if let info {
            XCTAssertTrue((info as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"), atomically: true))
        }
    }

    func testScansNestedFoldersDedupesAndSkipsBackgroundApps() throws {
        try makeBundle("first/Alpha.app", info: ["CFBundleIdentifier": "com.x.alpha", "CFBundleName": "Alpha", "LSApplicationCategoryType": "public.app-category.music"])
        try makeBundle("first/Suite/Beta.app", info: ["CFBundleIdentifier": "com.x.beta", "CFBundleDisplayName": " "])
        try makeBundle("first/a/b/c/TooDeep.app", info: ["CFBundleIdentifier": "com.x.deep"])
        try makeBundle("first/Agent.app", info: ["CFBundleIdentifier": "com.x.agent", "LSBackgroundOnly": true])
        try makeBundle("first/NoInfo.app", info: nil)
        try makeBundle("second/AlphaCopy.app", info: ["CFBundleIdentifier": "com.x.alpha", "CFBundleName": "Alpha Old"])

        let scanner = AppScanner(roots: [
            .init(url: root.appendingPathComponent("first"), depth: 3),
            .init(url: root.appendingPathComponent("second"), depth: 1),
        ])
        let apps = Dictionary(uniqueKeysWithValues: scanner.scan().map { ($0.id, $0) })

        XCTAssertEqual(apps["com.x.alpha"]?.url.lastPathComponent, "Alpha.app", "earlier roots win")
        XCTAssertEqual(apps["com.x.alpha"]?.category, "public.app-category.music")
        XCTAssertEqual(apps["com.x.beta"]?.name, "Beta", "blank display names fall back")
        XCTAssertNil(apps["com.x.deep"])
        XCTAssertNil(apps["com.x.agent"])
        let noInfo = apps.values.first { $0.url.lastPathComponent == "NoInfo.app" }
        XCTAssertEqual(noInfo?.name, "NoInfo")
        XCTAssertEqual(noInfo?.id, noInfo?.url.path, "apps without a bundle ID are keyed by path")
        XCTAssertEqual(apps.count, 3)
    }

    func testSearchKeyIncludesAliases() {
        let app = AppItem(id: "com.apple.systempreferences", name: "系統設定", url: URL(fileURLWithPath: "/System/Applications/System Settings.app"), aliases: ["System Settings"])
        XCTAssertTrue(app.searchKey.contains("system settings"))
        XCTAssertTrue(app.searchKey.contains("系統設定"))
    }
}

final class HotKeyTests: XCTestCase {
    func testDecodesShortcutSavedByVersion2() throws {
        let json = #"{"keyCode":118,"carbonModifiers":0,"display":"F4"}"#
        let hotKey = try JSONDecoder().decode(HotKey.self, from: Data(json.utf8))
        XCTAssertEqual(hotKey, HotKey(keyCode: 118, carbonModifiers: 0, display: "F4"))
    }

    func testRequiresModifierUnlessFunctionKey() throws {
        func key(_ code: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                             context: nil, characters: characters, charactersIgnoringModifiers: characters,
                             isARepeat: false, keyCode: code)!
        }
        XCTAssertNil(HotKey(event: key(37, "l", [])))
        XCTAssertNil(HotKey(event: key(37, "L", [.shift])))
        XCTAssertEqual(HotKey(event: key(37, "l", [.command, .option]))?.display, "⌥⌘L")
        XCTAssertEqual(HotKey(event: key(118, "\u{F707}", []))?.display, "F4")
    }
}
