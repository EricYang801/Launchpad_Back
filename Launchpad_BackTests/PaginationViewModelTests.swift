import XCTest
@testable import Launchpad_Back

class PaginationViewModelTests: XCTestCase {
    
    var viewModel: PaginationViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = PaginationViewModel(itemsPerPage: 20)
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialization() {
        // Assert
        XCTAssertEqual(viewModel.itemsPerPage, 20)
        XCTAssertEqual(viewModel.currentPage, 1)
    }
    
    func testTotalPages_WithApps() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        
        // Act
        let totalPages = viewModel.totalPages(for: apps)
        
        // Assert
        XCTAssertEqual(totalPages, 3) // 50 items / 20 per page = 2.5 → 3 pages
    }
    
    func testTotalPages_Empty() {
        // Arrange
        let apps: [AppItem] = []
        
        // Act
        let totalPages = viewModel.totalPages(for: apps)
        
        // Assert
        XCTAssertEqual(totalPages, 1)
    }
    
    func testAppsForPage_FirstPage() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        viewModel.currentPage = 1
        
        // Act
        let pageApps = viewModel.appsForPage(apps)
        
        // Assert
        XCTAssertEqual(pageApps.count, 20)
        XCTAssertEqual(pageApps[0].name, "App 0")
        XCTAssertEqual(pageApps[19].name, "App 19")
    }
    
    func testAppsForPage_MiddlePage() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        viewModel.currentPage = 2
        
        // Act
        let pageApps = viewModel.appsForPage(apps)
        
        // Assert
        XCTAssertEqual(pageApps.count, 20)
        XCTAssertEqual(pageApps[0].name, "App 20")
        XCTAssertEqual(pageApps[19].name, "App 39")
    }
    
    func testAppsForPage_LastPage() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        viewModel.currentPage = 3
        
        // Act
        let pageApps = viewModel.appsForPage(apps)
        
        // Assert
        XCTAssertEqual(pageApps.count, 10) // Remaining items
        XCTAssertEqual(pageApps[0].name, "App 40")
        XCTAssertEqual(pageApps[9].name, "App 49")
    }
    
    func testNextPage() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        viewModel.currentPage = 1
        
        // Act
        viewModel.nextPage(total: apps.count)
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 2)
    }
    
    func testNextPage_OnLastPage() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        viewModel.currentPage = 3
        
        // Act
        viewModel.nextPage(total: apps.count)
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 3) // Should not go beyond last page
    }
    
    func testPreviousPage() {
        // Arrange
        viewModel.currentPage = 2
        
        // Act
        viewModel.previousPage()
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 1)
    }
    
    func testPreviousPage_OnFirstPage() {
        // Arrange
        viewModel.currentPage = 1
        
        // Act
        viewModel.previousPage()
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 1) // Should not go below 1
    }
    
    func testGoToPage() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        
        // Act
        viewModel.goToPage(2, total: apps.count)
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 2)
    }
    
    func testGoToPage_OutOfRange() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        
        // Act
        viewModel.goToPage(10, total: apps.count) // Beyond max page
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 3) // Should clamp to max page
    }
    
    func testCanGoNext() {
        // Arrange
        let apps = (0..<50).map { index in
            AppItem(id: UUID(), name: "App \(index)", bundleID: "com.test.app\(index)", path: "/Applications/App\(index).app", isSystemApp: false)
        }
        
        // First page should be able to go next
        viewModel.currentPage = 1
        XCTAssertTrue(viewModel.canGoNext(total: apps.count))
        
        // Last page should not be able to go next
        viewModel.currentPage = 3
        XCTAssertFalse(viewModel.canGoNext(total: apps.count))
    }
    
    func testCanGoPrevious() {
        // First page should not be able to go previous
        viewModel.currentPage = 1
        XCTAssertFalse(viewModel.canGoPrevious())
        
        // Other pages should be able to go previous
        viewModel.currentPage = 2
        XCTAssertTrue(viewModel.canGoPrevious())
    }
}
