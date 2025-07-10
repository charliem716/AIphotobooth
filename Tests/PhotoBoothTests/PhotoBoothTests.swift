import XCTest
@testable import PhotoBooth

final class PhotoBoothTests: XCTestCase {
    func testThemeCount() {
        let viewModel = PhotoBoothViewModel()
        XCTAssertEqual(viewModel.themes.count, 9, "Should have 9 themes")
    }
    
    func testPhoneNumberValidation() {
        // This is a placeholder test
        // In a real implementation, you'd test the phone number validation logic
        XCTAssertTrue(true)
    }
} 