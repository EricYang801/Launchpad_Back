import XCTest
import Combine
@testable import Launchpad_Back

final class LaunchpadViewModelTests: XCTestCase {
    private var viewModel: LaunchpadViewModel!
    private var mockAppScannerService: MockAppScannerService!
    private var mockAppLauncherService: MockAppLauncherService!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        
        defaultsSuiteName = "LaunchpadViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        
        mockAppScannerService = MockAppScannerService()
        mockAppLauncherService = MockAppLauncherService()
        viewModel = makeViewModel()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        viewModel = nil
        mockAppScannerService = nil
        mockAppLauncherService = nil
        defaults = nil
        defaultsSuiteName = nil
        
        super.tearDown()
    }
    
    func testLoadInstalledApps_PopulatesAppsAndDisplayItems() {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Alpha", bundleID: "com.test.alpha"),
            makeApp(name: "Beta", bundleID: "com.test.beta")
        ]
        
        waitForAppsToLoad()
        
        XCTAssertEqual(viewModel.apps.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(viewModel.displayItems.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(viewModel.searchableApps.map(\.name), ["Alpha", "Beta"])
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLaunchAppFailure_SetsErrorMessage() {
        mockAppLauncherService.shouldSucceed = false
        let app = makeApp(name: "Alpha", bundleID: "com.test.alpha")
        
        let expectation = expectation(description: "launch completion")
        viewModel.launchApp(app)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(mockAppLauncherService.lastLaunchedApp?.stableIdentifier, app.stableIdentifier)
        XCTAssertEqual(viewModel.errorMessage, "Failed to launch: Alpha")
    }
    
    func testCreateSecondFolderAndRestoreSavedOrder() {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Alpha", bundleID: "com.test.alpha"),
            makeApp(name: "Beta", bundleID: "com.test.beta"),
            makeApp(name: "Gamma", bundleID: "com.test.gamma"),
            makeApp(name: "Delta", bundleID: "com.test.delta")
        ]
        
        waitForAppsToLoad()
        
        let alpha = app(named: "Alpha")
        let beta = app(named: "Beta")
        let delta = app(named: "Delta")
        let gamma = app(named: "Gamma")
        
        let firstFolder = viewModel.createFolder(app1: alpha, app2: beta)
        let secondFolder = viewModel.createFolder(app1: delta, app2: gamma)
        
        viewModel.moveItem(withId: secondFolder.id, to: 0)
        viewModel.saveOrder()
        
        XCTAssertEqual(viewModel.folders.count, 2)
        XCTAssertEqual(viewModel.displayItems.map(\.id), [secondFolder.id, firstFolder.id])
        
        viewModel = makeViewModel()
        waitForAppsToLoad()
        
        XCTAssertEqual(viewModel.folders.count, 2)
        XCTAssertEqual(viewModel.displayItems.map(\.id), [secondFolder.id, firstFolder.id])
    }

    func testAddAppToFolder_RemovesStandaloneItemAndUpdatesFolderContents() throws {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Alpha", bundleID: "com.test.alpha"),
            makeApp(name: "Beta", bundleID: "com.test.beta"),
            makeApp(name: "Gamma", bundleID: "com.test.gamma")
        ]
        
        waitForAppsToLoad()
        
        let folder = viewModel.createFolder(app1: app(named: "Alpha"), app2: app(named: "Beta"))
        viewModel.addAppToFolder(app: app(named: "Gamma"), folder: folder)
        
        let updatedFolder = try XCTUnwrap(viewModel.folders.first(where: { $0.id == folder.id }))
        XCTAssertEqual(updatedFolder.apps.map(\.name), ["Alpha", "Beta", "Gamma"])
        XCTAssertFalse(viewModel.displayItems.contains(where: { $0.name == "Gamma" }))
        XCTAssertEqual(viewModel.displayItems.count, 1)
    }
    
    func testRemoveAppFromFolder_ReinsertsAppWhileKeepingFolder() throws {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Alpha", bundleID: "com.test.alpha"),
            makeApp(name: "Beta", bundleID: "com.test.beta"),
            makeApp(name: "Gamma", bundleID: "com.test.gamma"),
            makeApp(name: "Delta", bundleID: "com.test.delta")
        ]
        
        waitForAppsToLoad()
        
        let alpha = app(named: "Alpha")
        let beta = app(named: "Beta")
        let gamma = app(named: "Gamma")
        let folder = viewModel.createFolder(app1: alpha, app2: beta)
        
        viewModel.addAppToFolder(app: gamma, folder: folder)
        let updatedFolder = try XCTUnwrap(viewModel.folders.first(where: { $0.id == folder.id }))
        
        viewModel.removeAppFromFolder(app: gamma, folder: updatedFolder)
        
        let remainingFolder = try XCTUnwrap(viewModel.folders.first(where: { $0.id == folder.id }))
        XCTAssertEqual(remainingFolder.apps.map(\.name), ["Alpha", "Beta"])
        XCTAssertTrue(viewModel.displayItems.contains(where: { $0.name == "Gamma" }))
        XCTAssertEqual(viewModel.displayItems.filter {
            if case .folder(let storedFolder) = $0 { return storedFolder.id == folder.id }
            return false
        }.count, 1)
    }
    
    func testDeleteFolder_RestoresContainedAppsToDisplayItems() {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Alpha", bundleID: "com.test.alpha"),
            makeApp(name: "Beta", bundleID: "com.test.beta"),
            makeApp(name: "Gamma", bundleID: "com.test.gamma")
        ]
        
        waitForAppsToLoad()
        
        let folder = viewModel.createFolder(app1: app(named: "Alpha"), app2: app(named: "Beta"))
        viewModel.deleteFolder(folder)
        
        XCTAssertTrue(viewModel.folders.isEmpty)
        XCTAssertEqual(viewModel.displayItems.compactMap { item -> String? in
            if case .app(let app) = item { return app.name }
            return nil
        }, ["Alpha", "Beta", "Gamma"])
    }
    
    func testEmptyBundleID_UsesPathForPersistenceAndFolderRestore() {
        let untitled = makeApp(name: "Untitled", bundleID: "", path: "/Applications/Untitled.app")
        let helper = makeApp(name: "Helper", bundleID: "", path: "/Applications/Helper.app")
        let regular = makeApp(name: "Regular", bundleID: "com.test.regular")
        mockAppScannerService.appsToReturn = [untitled, helper, regular]
        
        waitForAppsToLoad()
        
        _ = viewModel.createFolder(app1: untitled, app2: helper)
        viewModel.saveOrder()
        
        viewModel = makeViewModel()
        waitForAppsToLoad()
        
        XCTAssertEqual(viewModel.folders.count, 1)
        XCTAssertEqual(viewModel.folders[0].apps.map(\.path).sorted(), ["/Applications/Helper.app", "/Applications/Untitled.app"])
    }

    func testResetLayout_ClearsFoldersAndRestoresAlphabeticalOrder() {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Alpha", bundleID: "com.test.alpha"),
            makeApp(name: "Beta", bundleID: "com.test.beta"),
            makeApp(name: "Gamma", bundleID: "com.test.gamma")
        ]
        
        waitForAppsToLoad()
        
        let folder = viewModel.createFolder(app1: app(named: "Alpha"), app2: app(named: "Beta"))
        viewModel.addAppToFolder(app: app(named: "Gamma"), folder: folder)
        viewModel.resetLayout()
        
        XCTAssertTrue(viewModel.folders.isEmpty)
        XCTAssertEqual(viewModel.displayItems.map(\.name), ["Alpha", "Beta", "Gamma"])
        
        viewModel = makeViewModel()
        waitForAppsToLoad()
        
        XCTAssertTrue(viewModel.folders.isEmpty)
        XCTAssertEqual(viewModel.displayItems.map(\.name), ["Alpha", "Beta", "Gamma"])
    }

    func testFilteredApps_SearchMatchesNameBundleIDAndPath() {
        mockAppScannerService.appsToReturn = [
            makeApp(name: "Safari", bundleID: "com.apple.Safari"),
            makeApp(name: "Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app"),
            makeApp(name: "Notes", bundleID: "com.apple.Notes")
        ]

        waitForAppsToLoad()

        XCTAssertEqual(viewModel.filteredApps(matching: "  safari  ").map(\.name), ["Safari"])
        XCTAssertEqual(viewModel.filteredApps(matching: "GOOGLE").map(\.name), ["Chrome"])
        XCTAssertEqual(viewModel.filteredApps(matching: "google chrome.app").map(\.name), ["Chrome"])
    }
    
    private func makeViewModel() -> LaunchpadViewModel {
        LaunchpadViewModel(
            scannerService: mockAppScannerService,
            launcherService: mockAppLauncherService,
            defaults: defaults
        )
    }
    
    private func waitForAppsToLoad(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = expectation(description: "apps loaded")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadInstalledApps()
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertFalse(viewModel.isLoading, file: file, line: line)
    }
    
    private func app(named name: String, file: StaticString = #filePath, line: UInt = #line) -> AppItem {
        guard let app = viewModel.apps.first(where: { $0.name == name }) else {
            XCTFail("Missing app named \(name)", file: file, line: line)
            return makeApp(name: name, bundleID: "missing.\(name)")
        }
        
        return app
    }
    
    private func makeApp(name: String, bundleID: String, path: String? = nil) -> AppItem {
        AppItem(
            name: name,
            bundleID: bundleID,
            path: path ?? "/Applications/\(name).app",
            isSystemApp: false
        )
    }
}

private final class MockAppScannerService: AppScannerService {
    var appsToReturn: [AppItem] = []
    
    override func scanInstalledApps() -> [AppItem] {
        appsToReturn
    }
}

private final class MockAppLauncherService: AppLauncherService {
    var shouldSucceed = true
    var lastLaunchedApp: AppItem?
    
    override func launch(_ app: AppItem) -> Bool {
        lastLaunchedApp = app
        return shouldSucceed
    }
    
    override func launchAsync(_ app: AppItem, completion: @escaping (Bool) -> Void) {
        lastLaunchedApp = app
        completion(shouldSucceed)
    }
}
