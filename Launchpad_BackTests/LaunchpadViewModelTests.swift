import XCTest
@testable import Launchpad_Back

class LaunchpadViewModelTests: XCTestCase {
    
    var viewModel: LaunchpadViewModel!
    var mockAppScannerService: MockAppScannerService!
    var mockAppLauncherService: MockAppLauncherService!
    
    override func setUp() {
        super.setUp()
        
        mockAppScannerService = MockAppScannerService()
        mockAppLauncherService = MockAppLauncherService()
        
        viewModel = LaunchpadViewModel(
            appScannerService: mockAppScannerService,
            appLauncherService: mockAppLauncherService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockAppScannerService = nil
        mockAppLauncherService = nil
        
        super.tearDown()
    }
    
    func testLoadInstalledApps_Success() {
        // Arrange
        let expectedApps = [
            AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true),
            AppItem(id: UUID(), name: "Mail", bundleID: "com.apple.mail", path: "/Applications/Mail.app", isSystemApp: true)
        ]
        mockAppScannerService.apps = expectedApps
        
        // Act
        viewModel.loadInstalledApps()
        
        // Assert
        XCTAssertEqual(viewModel.apps.count, 2)
        XCTAssertEqual(viewModel.apps[0].name, "Safari")
        XCTAssertEqual(viewModel.apps[1].name, "Mail")
    }
    
    func testLoadInstalledApps_LoadingState() {
        // Arrange
        let expectation = self.expectation(description: "Loading state changed")
        var loadingStates: [Bool] = []
        
        let cancellable = viewModel.$isLoading.sink { isLoading in
            loadingStates.append(isLoading)
            if loadingStates.count == 2 {
                expectation.fulfill()
            }
        }
        
        mockAppScannerService.apps = []
        
        // Act
        viewModel.loadInstalledApps()
        
        // Assert
        wait(for: [expectation], timeout: 5.0)
        cancellable.cancel()
        
        XCTAssertEqual(loadingStates.first, true)
        XCTAssertEqual(loadingStates.last, false)
    }
    
    func testLaunchApp_Success() {
        // Arrange
        let app = AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true)
        mockAppLauncherService.shouldSucceed = true
        
        // Act
        viewModel.launchApp(app)
        
        // Assert
        XCTAssertTrue(mockAppLauncherService.launchCalled)
        XCTAssertEqual(mockAppLauncherService.lastLaunchedApp?.bundleID, "com.apple.Safari")
    }
    
    func testLaunchApp_Failure() {
        // Arrange
        let app = AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true)
        mockAppLauncherService.shouldSucceed = false
        
        // Act
        viewModel.launchApp(app)
        
        // Assert
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
    }
    
    func testRefreshApps() {
        // Arrange
        let expectedApps = [
            AppItem(id: UUID(), name: "Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app", isSystemApp: false)
        ]
        mockAppScannerService.apps = expectedApps
        
        // Act
        viewModel.refreshApps()
        
        // Assert
        XCTAssertEqual(viewModel.apps.count, 1)
        XCTAssertEqual(viewModel.apps[0].name, "Chrome")
    }
    
    func testClearError() {
        // Arrange
        viewModel.errorMessage = "Test error"
        
        // Act
        viewModel.clearError()
        
        // Assert
        XCTAssertTrue(viewModel.errorMessage.isEmpty)
    }
}

// MARK: - Mock Services

class MockAppScannerService: AppScannerService {
    var apps: [AppItem] = []
    var scanCalled = false
    
    override func scanApplications(completion: @escaping ([AppItem]) -> Void) {
        scanCalled = true
        completion(apps)
    }
}

class MockAppLauncherService: AppLauncherService {
    var shouldSucceed = true
    var launchCalled = false
    var lastLaunchedApp: AppItem?
    
    override func launchApplication(_ app: AppItem) -> Bool {
        launchCalled = true
        lastLaunchedApp = app
        return shouldSucceed
    }
}
