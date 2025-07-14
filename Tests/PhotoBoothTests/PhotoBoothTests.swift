import XCTest
@testable import PhotoBooth

final class PhotoBoothTests: XCTestCase {
    @MainActor
    func testThemeCount() async {
        let viewModel = PhotoBoothViewModel()
        
        // Wait for the theme configuration to load
        await viewModel.setupPhotoBoothSystem()
        
        // Allow some time for theme configuration loading
        try? await Task.sleep(for: .milliseconds(100))
        
        // In test environment, the theme service falls back to 3 default themes
        // when themes.json is not found in the bundle
        XCTAssertEqual(viewModel.themes.count, 3, "Should have 3 fallback themes in test environment")
        
        // Verify themes are not empty
        XCTAssertFalse(viewModel.themes.isEmpty, "Should have at least some themes available")
        
        // Verify theme structure
        if let firstTheme = viewModel.themes.first {
            XCTAssertFalse(firstTheme.name.isEmpty, "Theme should have a name")
            XCTAssertFalse(firstTheme.prompt.isEmpty, "Theme should have a prompt")
            XCTAssertTrue(firstTheme.id > 0, "Theme should have a valid ID")
        }
    }
    
    func testPhoneNumberValidation() {
        // This is a placeholder test
        // In a real implementation, you'd test the phone number validation logic
        XCTAssertTrue(true)
    }
    
    @MainActor
    func testThemeConfigurationService() async {
        let themeService = ThemeConfigurationService()
        
        // Wait for configuration to load
        await themeService.loadConfiguration()
        
        // Service should be configured (either from file or fallback)
        XCTAssertTrue(themeService.isConfigured, "Theme service should be configured")
        
        // Should have themes available
        XCTAssertFalse(themeService.availableThemes.isEmpty, "Should have available themes")
        
        // Configuration should have a version
        XCTAssertFalse(themeService.themeConfiguration.version.isEmpty, "Configuration should have a version")
        
        // Test theme retrieval
        if let firstTheme = themeService.availableThemes.first {
            let retrievedTheme = themeService.getTheme(by: firstTheme.id)
            XCTAssertNotNil(retrievedTheme, "Should be able to retrieve theme by ID")
            XCTAssertEqual(retrievedTheme?.id, firstTheme.id, "Retrieved theme should match")
        }
    }
} 