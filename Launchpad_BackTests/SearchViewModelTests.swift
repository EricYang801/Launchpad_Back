import XCTest
@testable import Launchpad_Back

final class SearchViewModelTests: XCTestCase {
    private var viewModel: SearchViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = SearchViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialization_StartsEmpty() {
        XCTAssertEqual(viewModel.searchText, "")
    }
    
    func testClearSearch_ResetsText() {
        viewModel.searchText = "Test"
        
        viewModel.clearSearch()
        
        XCTAssertEqual(viewModel.searchText, "")
    }
}
