import XCTest

@testable import Launchpad_Back

final class LayoutTests: XCTestCase {
    private let alpha = makeApp("Alpha")
    private let beta = makeApp("Beta", category: "public.app-category.developer-tools")
    private let gamma = makeApp("Gamma")
    private let delta = makeApp("Delta")

    private var all: [String: AppItem] { appMap([alpha, beta, gamma, delta]) }
    private var installed: Set<String> { Set(all.keys) }

    private func placed(_ entries: [LayoutEntry] = []) -> Layout {
        var layout = Layout(entries: entries)
        layout.place(all)
        return layout
    }

    func testPlaceSortsNewAppsAlphabeticallyAfterExistingOnes() {
        let layout = placed([.app(gamma.id)])
        XCTAssertEqual(layout.items(for: all).names, ["Gamma", "Alpha", "Beta", "Delta"])
    }

    func testPlaceDropsDuplicatePlacements() {
        let folder = SavedFolder(id: UUID(), name: "F", apps: [alpha.id, beta.id])
        let layout = placed([.app(alpha.id), .folder(folder)])
        XCTAssertEqual(layout.items(for: all).names.first, "Alpha")
        guard case .folder(let saved) = layout.entries[1] else { return XCTFail("expected folder") }
        XCTAssertEqual(saved.apps, [beta.id])
    }

    func testMoveUsesVisibleIndices() {
        // Delta's entry is hidden (not installed); moving Alpha to visible index 2 must skip it.
        var apps = all
        apps[delta.id] = nil
        var layout = Layout(entries: [.app(alpha.id), .app(delta.id), .app(beta.id), .app(gamma.id)])
        layout.move(alpha.id, to: 2, installed: Set(apps.keys))
        XCTAssertEqual(layout.items(for: apps).names, ["Beta", "Gamma", "Alpha"])
        XCTAssertTrue(layout.entries.contains(.app(delta.id)), "missing apps keep their place")
    }

    func testMergeTwoAppsCreatesFolderAtTargetPosition() throws {
        var layout = placed()
        let id = try XCTUnwrap(layout.merge(gamma.id, into: beta.id, newFolderName: "Tools"))
        let items = layout.items(for: all)
        XCTAssertEqual(items.names, ["Alpha", "Tools", "Delta"])
        guard case .folder(let folder) = items[1] else { return XCTFail("expected folder") }
        XCTAssertEqual(folder.id, id)
        XCTAssertEqual(folder.apps.map(\.name), ["Beta", "Gamma"])
    }

    func testMergeIntoFolderAppends() throws {
        var layout = placed()
        let id = try XCTUnwrap(layout.merge(beta.id, into: alpha.id, newFolderName: "F"))
        XCTAssertEqual(layout.merge(delta.id, into: id.uuidString, newFolderName: "ignored"), id)
        guard case .folder(let folder) = layout.items(for: all)[0] else { return XCTFail("expected folder") }
        XCTAssertEqual(folder.apps.map(\.name), ["Alpha", "Beta", "Delta"])
    }

    func testMergeRejectsFoldersAndSelf() throws {
        var layout = placed()
        let id = try XCTUnwrap(layout.merge(beta.id, into: alpha.id, newFolderName: "F"))
        let before = layout
        XCTAssertNil(layout.merge(id.uuidString, into: gamma.id, newFolderName: "x"), "folders can't go into folders")
        XCTAssertNil(layout.merge(gamma.id, into: gamma.id, newFolderName: "x"))
        XCTAssertNil(layout.merge(alpha.id, into: id.uuidString, newFolderName: "x"), "already in that folder")
        XCTAssertEqual(layout, before)
    }

    func testMovingAppOutOfTwoAppFolderDissolvesIt() throws {
        var layout = placed()
        _ = try XCTUnwrap(layout.merge(beta.id, into: alpha.id, newFolderName: "F"))
        layout.move(beta.id, to: 0, installed: installed)
        XCTAssertEqual(layout.items(for: all).names, ["Beta", "Alpha", "Delta", "Gamma"])
    }

    func testFolderKeepsAppsThatAreNotInstalled() throws {
        var layout = placed()
        _ = try XCTUnwrap(layout.merge(beta.id, into: alpha.id, newFolderName: "F"))
        var withoutBeta = all
        withoutBeta[beta.id] = nil
        layout.place(withoutBeta)
        guard case .folder(let folder) = layout.items(for: withoutBeta)[0] else { return XCTFail("expected folder") }
        XCTAssertEqual(folder.apps.map(\.name), ["Alpha"])
        layout.place(all)
        guard case .folder(let restored) = layout.items(for: all)[0] else { return XCTFail("expected folder") }
        XCTAssertEqual(restored.apps.map(\.name), ["Alpha", "Beta"], "the app comes back to its folder")
    }

    func testMoveInFolderAndRename() throws {
        var layout = placed()
        let id = try XCTUnwrap(layout.merge(beta.id, into: alpha.id, newFolderName: "F"))
        layout.merge(gamma.id, into: id.uuidString, newFolderName: "")
        layout.moveInFolder(id, app: gamma.id, to: 0, installed: installed)
        layout.rename(id, to: "Renamed")
        guard case .folder(let folder) = layout.items(for: all)[0] else { return XCTFail("expected folder") }
        XCTAssertEqual(folder.name, "Renamed")
        XCTAssertEqual(folder.apps.map(\.name), ["Gamma", "Alpha", "Beta"])
    }

    func testSaveAndLoadRoundTrip() throws {
        let defaults = makeDefaults()
        var layout = placed()
        _ = try XCTUnwrap(layout.merge(beta.id, into: alpha.id, newFolderName: "F"))
        layout.save(to: defaults)
        XCTAssertEqual(Layout.load(from: defaults), layout)
    }

    func testMigratesLegacyLayout() {
        let defaults = makeDefaults()
        let folderID = UUID()
        defaults.set(
            ["app:\(gamma.id)", "folder:\(folderID.uuidString)", "app:\(delta.id)"], forKey: "launchpad_item_order")
        defaults.set(
            [["id": folderID.uuidString, "name": "Old", "appIdentifiers": [alpha.id, beta.id]]],
            forKey: "launchpad_folders")

        var layout = Layout.load(from: defaults)
        layout.place(all)
        let items = layout.items(for: all)
        XCTAssertEqual(items.names, ["Gamma", "Old", "Delta"])
        guard case .folder(let folder) = items[1] else { return XCTFail("expected folder") }
        XCTAssertEqual(folder.id, folderID)
        XCTAssertEqual(folder.apps.map(\.name), ["Alpha", "Beta"])
    }

    func testFolderNameComesFromCategory() {
        XCTAssertEqual(FolderName.suggested(for: [alpha, beta]), String(localized: "Developer Tools"))
        XCTAssertEqual(FolderName.suggested(for: [alpha]), String(localized: "Untitled"))
        XCTAssertEqual(FolderName.categoryName("public.app-category.puzzle-games"), String(localized: "Games"))
    }

    func testVisiblePosition() {
        let array = [1, -1, 2, -2, 3]
        XCTAssertEqual(Layout.position(ofVisible: 0, in: array) { $0 > 0 }, 0)
        XCTAssertEqual(Layout.position(ofVisible: 1, in: array) { $0 > 0 }, 2)
        XCTAssertEqual(Layout.position(ofVisible: 3, in: array) { $0 > 0 }, 5)
    }
}
