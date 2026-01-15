import XCTest
@testable import Launchpad_Back

class SearchViewModelTests: XCTestCase {
    
    var viewModel: SearchViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testFilterApps_EmptySearch() {
        // Arrange
        let apps = [
            AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true),
            AppItem(id: UUID(), name: "Mail", bundleID: "com.apple.mail", path: "/Applications/Mail.app", isSystemApp: true)
        ]
        viewModel.searchText = ""
        
        // Act
        let filtered = viewModel.filterApps(apps)
        
        // Assert
        XCTAssertEqual(filtered.count, 2)
    }
    
    func testFilterApps_SearchByName() {
        // Arrange
        let apps = [
            AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true),
            AppItem(id: UUID(), name: "Mail", bundleID: "com.apple.mail", path: "/Applications/Mail.app", isSystemApp: true),
            AppItem(id: UUID(), name: "Notes", bundleID: "com.apple.Notes", path: "/Applications/Notes.app", isSystemApp: true)
        ]
        viewModel.searchText = "Safari"
        
        // Act
        let filtered = viewModel.filterApps(apps)
        
        // Assert
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Safari")
    }
    
    func testFilterApps_SearchByBundleID() {
        // Arrange
        let apps = [
            AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true),
            AppItem(id: UUID(), name: "Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app", isSystemApp: false)
        ]
        viewModel.searchText = "google"
        
        // Act
        let filtered = viewModel.filterApps(apps)
        
        // Assert
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Chrome")
    }
    
    func testFilterApps_CaseInsensitive() {
        // Arrange
        let apps = [
            AppItem(id: UUID(), name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", isSystemApp: true)
        ]
        viewModel.searchText = "SAFARI"
        
        // Act
        let filtered = viewModel.filterApps(apps)
        
        // Assert
        XCTAssertEqual(filtered.count, 1)
    }
    
    func testFilterApps_PartialMatch() {
        // Arrange
        let apps = [
            AppItem(id: UUID(), name: "Visual Studio Code", bundleID: "com.microsoft.VSCode", path: "/Applications/Visual Studio Code.app", isSystemApp: false),
            AppItem(id: UUID(), name: "VS Code Insiders", bundleID: "com.microsoft.VSCodeInsiders", path: "/Applications/VS Code Insiders.app", isSystemApp: false)
        ]
        viewModel.searchText = "code"
        
        // Act
        let filtered = viewModel.filterApps(apps)
        
        // Assert
        XCTAssertEqual(filtered.count, 2)
    }
    
    func testClearSearch() {
        // Arrange
        viewModel.searchText = "Test"
        viewModel.currentPage = 5
        
        // Act
        viewModel.clearSearch()
        
        // Assert
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertEqual(viewModel.currentPage, 1)
    }
    
    func testResetPage() {
        // Arrange
        viewModel.currentPage = 10
        
        // Act
        viewModel.resetPage()
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 1)
    }
    
    func testSearchText_UpdatesCurrentPage() {
        // Arrange
        viewModel.currentPage = 5
        
        // Act
        viewModel.searchText = "New search"
        
        // Assert
        XCTAssertEqual(viewModel.currentPage, 1)
    }
}
