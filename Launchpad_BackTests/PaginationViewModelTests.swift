import XCTest
@testable import Launchpad_Back

final class PaginationViewModelTests: XCTestCase {
    private var viewModel: PaginationViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = PaginationViewModel()
        viewModel.updateScreenSize(CGSize(width: 1200, height: 800))
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertEqual(viewModel.currentPage, 0)
        XCTAssertEqual(viewModel.appsPerPage, 36)
    }
    
    func testTotalPages_UsesCalculatedItemsPerPage() {
        XCTAssertEqual(viewModel.totalPages(for: 0), 1)
        XCTAssertEqual(viewModel.totalPages(for: 36), 1)
        XCTAssertEqual(viewModel.totalPages(for: 37), 2)
    }
    
    func testItemsForPage_ReturnsExpectedSlicesForApps() {
        let apps = makeApps(count: 40)
        
        let firstPage = viewModel.itemsForPage(apps, page: 0)
        let secondPage = viewModel.itemsForPage(apps, page: 1)
        
        XCTAssertEqual(firstPage.count, 36)
        XCTAssertEqual(firstPage.first?.name, "App 0")
        XCTAssertEqual(firstPage.last?.name, "App 35")
        XCTAssertEqual(secondPage.count, 4)
        XCTAssertEqual(secondPage.first?.name, "App 36")
        XCTAssertEqual(secondPage.last?.name, "App 39")
    }
    
    func testItemsForPage_ReturnsExpectedSlices() {
        let items = makeApps(count: 40).map(LaunchpadDisplayItem.app)
        
        let firstPage = viewModel.itemsForPage(items, page: 0)
        let secondPage = viewModel.itemsForPage(items, page: 1)
        
        XCTAssertEqual(firstPage.count, 36)
        XCTAssertEqual(secondPage.count, 4)
        XCTAssertEqual(secondPage.first?.name, "App 36")
    }
    
    func testNavigation_ClampsWithinBounds() {
        viewModel.nextPage(totalPages: 3)
        XCTAssertEqual(viewModel.currentPage, 1)
        
        viewModel.jumpToPage(10, totalPages: 3)
        XCTAssertEqual(viewModel.currentPage, 2)
        
        viewModel.nextPage(totalPages: 3)
        XCTAssertEqual(viewModel.currentPage, 2)
        
        viewModel.previousPage()
        XCTAssertEqual(viewModel.currentPage, 1)
        
        viewModel.reset()
        XCTAssertEqual(viewModel.currentPage, 0)
    }
    
    func testValidateCurrentPage_AdjustsOverflow() {
        viewModel.jumpToPage(2, totalPages: 3)
        XCTAssertEqual(viewModel.currentPage, 2)
        
        viewModel.validateCurrentPage(totalPages: 1)
        XCTAssertEqual(viewModel.currentPage, 0)
    }
    
    private func makeApps(count: Int) -> [AppItem] {
        (0..<count).map { index in
            AppItem(
                name: "App \(index)",
                bundleID: "com.test.app\(index)",
                path: "/Applications/App\(index).app",
                isSystemApp: false
            )
        }
    }
}
