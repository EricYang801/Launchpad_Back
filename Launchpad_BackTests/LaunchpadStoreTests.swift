import XCTest
@testable import Launchpad_Back

@MainActor
final class LaunchpadStoreTests: XCTestCase {
    private var store: LaunchpadStore!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = makeDefaults()
        store = LaunchpadStore(preferences: Preferences(defaults: defaults), defaults: defaults, scanner: AppScanner(roots: []))
        store.size = CGSize(width: 1440, height: 900)
        store.setApps([makeApp("Alpha"), makeApp("Beta"), makeApp("Charlie"), makeApp("Delta", category: "public.app-category.games")])
    }

    private var metrics: GridMetrics { store.metrics }

    /// A point in the label area of a cell: between icons, where dropping reorders.
    private func gap(_ slot: Int) -> CGPoint {
        let center = metrics.center(of: slot)
        return CGPoint(x: center.x, y: center.y + metrics.cellSize.height * 0.4)
    }

    func testStartsAlphabetical() {
        XCTAssertEqual(store.items.names, ["Alpha", "Beta", "Charlie", "Delta"])
        XCTAssertEqual(store.pageCount, 1)
    }

    func testDropOnIconCreatesFolderNamedByCategoryAndOpensIt() throws {
        let alpha = store.items[0]
        store.dragChanged(alpha, from: nil, to: metrics.iconCenter(of: 0))
        store.dragChanged(alpha, from: nil, to: metrics.iconCenter(of: 3))
        XCTAssertEqual(store.drag?.mergeTarget, store.items[3].id)
        store.endDrag()

        XCTAssertNil(store.drag)
        XCTAssertEqual(store.items.count, 3)
        let folder = try XCTUnwrap(store.openFolder)
        XCTAssertEqual(folder.name, String(localized: "Games"))
        XCTAssertEqual(folder.apps.map(\.name), ["Delta", "Alpha"])
        XCTAssertNotNil(Layout.load(from: defaults).entries.first { if case .folder = $0 { true } else { false } }, "saved")
    }

    func testDropBetweenIconsReorders() async throws {
        let alpha = store.items[0]
        store.dragChanged(alpha, from: nil, to: metrics.iconCenter(of: 0))
        store.dragChanged(alpha, from: nil, to: gap(3))
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(store.gridItems.names, ["Beta", "Charlie", "Delta", "Alpha"], "icons make room while dragging")
        store.endDrag()
        XCTAssertEqual(store.items.names, ["Beta", "Charlie", "Delta", "Alpha"])
        XCTAssertTrue(store.isEditing)
    }

    func testDraggingOutOfFolderMovesAppToMainGrid() async throws {
        store.dragChanged(store.items[0], from: nil, to: metrics.iconCenter(of: 0))
        store.dragChanged(store.items[0], from: nil, to: metrics.iconCenter(of: 1))
        store.endDrag()
        let folder = try XCTUnwrap(store.openFolder)
        let beta = LaunchItem.app(folder.apps[0])

        let folderGrid = store.folderMetrics(for: folder)
        store.dragChanged(beta, from: folder.id, to: folderGrid.iconCenter(of: 0))
        store.dragChanged(beta, from: folder.id, to: CGPoint(x: 720, y: 880))
        XCTAssertEqual(store.drag?.leftFolder, true)
        XCTAssertFalse(store.showsFolder)
        store.endDrag()

        XCTAssertNil(store.openFolderID)
        XCTAssertEqual(store.items.names, ["Alpha", "Charlie", "Delta", "Beta"], "the folder dissolves into its last app")
    }

    func testSearchingDisablesDragging() {
        store.query = "char"
        store.dragChanged(store.gridItems[0], from: nil, to: .zero)
        XCTAssertNil(store.drag)
        XCTAssertFalse(store.isEditing)
    }

    func testSearchRanksNamePrefixFirstAndKeyboardSelects() {
        store.setApps([makeApp("Keynote"), makeApp("Notes"), makeApp("Music")])
        store.query = "note"
        XCTAssertEqual(store.searchResults.map(\.name), ["Notes", "Keynote"])
        XCTAssertTrue(store.handle(.right))
        XCTAssertEqual(store.selection, 1)
        XCTAssertTrue(store.handle(.right))
        XCTAssertEqual(store.selection, 1, "clamped to the last result")
    }

    func testEscapeBacksOutOneLevelAtATime() {
        var dismissed = false
        store.dismiss = { dismissed = true }
        store.query = "a"
        store.isEditing = true
        store.escape()
        XCTAssertFalse(store.isEditing)
        store.escape()
        XCTAssertEqual(store.query, "")
        XCTAssertFalse(dismissed)
        store.escape()
        XCTAssertTrue(dismissed)
    }

    func testRemovedAppsDisappearAndComeBackInPlace() {
        store.setApps([makeApp("Alpha"), makeApp("Charlie"), makeApp("Delta")])
        XCTAssertEqual(store.items.names, ["Alpha", "Charlie", "Delta"])
        store.setApps([makeApp("Alpha"), makeApp("Beta"), makeApp("Charlie"), makeApp("Delta")])
        XCTAssertEqual(store.items.names, ["Alpha", "Beta", "Charlie", "Delta"])
    }

    func testResetLayout() {
        store.dragChanged(store.items[0], from: nil, to: metrics.iconCenter(of: 0))
        store.dragChanged(store.items[0], from: nil, to: metrics.iconCenter(of: 1))
        store.endDrag()
        store.resetLayout()
        XCTAssertEqual(store.items.names, ["Alpha", "Beta", "Charlie", "Delta"])
    }
}
