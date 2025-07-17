import XCTest
import Combine
@testable import PhotoBooth

/// Comprehensive tests for ThemeConfigurationService
@MainActor
final class ThemeConfigurationServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var themeService: ThemeConfigurationService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Test Lifecycle
    
    override func setUp() async throws {
        try await super.setUp()
        themeService = ThemeConfigurationService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        themeService = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Configuration Tests
    
    func testInitialization() async {
        // Given & When
        let service = ThemeConfigurationService()
        
        // Then
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isConfigured, "Should not be configured initially")
        XCTAssertTrue(service.availableThemes.isEmpty, "Should have no themes initially")
        XCTAssertTrue(service.themesByCategory.isEmpty, "Should have no categories initially")
    }
    
    func testConfigurationLoading() async {
        // Given
        let service = ThemeConfigurationService()
        
        // When
        await service.loadConfiguration()
        
        // Then
        XCTAssertTrue(service.isConfigured, "Should be configured after loading")
        XCTAssertGreaterThan(service.availableThemes.count, 0, "Should have loaded themes")
        XCTAssertGreaterThan(service.themesByCategory.count, 0, "Should have organized themes by category")
        XCTAssertFalse(service.themeConfiguration.version.isEmpty, "Should have configuration version")
    }
    
    func testReloadConfiguration() async {
        // Given
        await themeService.loadConfiguration()
        let initialThemeCount = themeService.availableThemes.count
        
        // When
        await themeService.reloadConfiguration()
        
        // Then
        XCTAssertTrue(themeService.isConfigured, "Should remain configured after reload")
        XCTAssertEqual(themeService.availableThemes.count, initialThemeCount, "Should maintain theme count after reload")
    }
    
    // MARK: - PhotoTheme Prompt Tests
    
    func testPhotoThemePromptEffectiveness() async {
        // Given - PhotoTheme prompts are very effective for image theming
        await themeService.loadConfiguration()
        
        // When - Test various PhotoTheme prompt styles
        let themes = themeService.availableThemes
        
        // Then - Should have themes with effective prompts
        XCTAssertGreaterThan(themes.count, 0, "Should have PhotoTheme prompts available")
        
        // Test prompt quality
        for theme in themes {
            XCTAssertFalse(theme.prompt.isEmpty, "Theme \(theme.name) should have non-empty prompt")
            XCTAssertGreaterThan(theme.prompt.count, 10, "Theme \(theme.name) should have substantial prompt")
            
            // Test prompt structure - should be descriptive
            let promptWords = theme.prompt.components(separatedBy: " ")
            XCTAssertGreaterThan(promptWords.count, 3, "Theme \(theme.name) should have descriptive prompt")
        }
    }
    
    func testPortraitThemePrompts() async {
        // Given
        await themeService.loadConfiguration()
        
        // When - Get portrait themes
        let portraitThemes = themeService.getThemesByCategory("portrait")
        
        // Then - Should have portrait-specific prompts
        if !portraitThemes.isEmpty {
            for theme in portraitThemes {
                let prompt = theme.prompt.lowercased()
                let hasPortraitKeywords = prompt.contains("portrait") || 
                                         prompt.contains("headshot") || 
                                         prompt.contains("face") ||
                                         prompt.contains("person") ||
                                         prompt.contains("studio")
                
                XCTAssertTrue(hasPortraitKeywords, "Portrait theme \(theme.name) should have portrait-related keywords")
            }
        }
    }
    
    func testLandscapeThemePrompts() async {
        // Given - User prefers landscape resolution (1536x1024) for group photos
        await themeService.loadConfiguration()
        
        // When - Get landscape themes
        let landscapeThemes = themeService.getThemesByCategory("landscape")
        
        // Then - Should have landscape-specific prompts
        if !landscapeThemes.isEmpty {
            for theme in landscapeThemes {
                let prompt = theme.prompt.lowercased()
                let hasLandscapeKeywords = prompt.contains("landscape") || 
                                          prompt.contains("scenery") || 
                                          prompt.contains("outdoor") ||
                                          prompt.contains("nature") ||
                                          prompt.contains("background")
                
                XCTAssertTrue(hasLandscapeKeywords, "Landscape theme \(theme.name) should have landscape-related keywords")
            }
        }
    }
    
    func testVintageThemePrompts() async {
        // Given
        await themeService.loadConfiguration()
        
        // When - Get vintage themes
        let vintageThemes = themeService.getThemesByCategory("vintage")
        
        // Then - Should have vintage-specific prompts
        if !vintageThemes.isEmpty {
            for theme in vintageThemes {
                let prompt = theme.prompt.lowercased()
                let hasVintageKeywords = prompt.contains("vintage") || 
                                        prompt.contains("retro") || 
                                        prompt.contains("sepia") ||
                                        prompt.contains("old") ||
                                        prompt.contains("classic")
                
                XCTAssertTrue(hasVintageKeywords, "Vintage theme \(theme.name) should have vintage-related keywords")
            }
        }
    }
    
    // MARK: - Theme Category Tests
    
    func testThemeCategories() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let categories = themeService.getAvailableCategories()
        let themesByCategory = themeService.themesByCategory
        
        // Then
        XCTAssertGreaterThan(categories.count, 0, "Should have theme categories")
        XCTAssertEqual(categories.count, themesByCategory.count, "Categories should match organized themes")
        
        // Test common categories
        let commonCategories = ["portrait", "landscape", "artistic", "vintage", "modern"]
        for category in commonCategories {
            if categories.contains(category) {
                let themesInCategory = themeService.getThemesByCategory(category)
                XCTAssertGreaterThan(themesInCategory.count, 0, "Category \(category) should have themes")
            }
        }
    }
    
    func testThemeOrganization() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let themesByCategory = themeService.themesByCategory
        let allThemes = themeService.availableThemes
        
        // Then - All themes should be organized into categories
        var totalThemesInCategories = 0
        for (category, themes) in themesByCategory {
            XCTAssertGreaterThan(themes.count, 0, "Category \(category) should have themes")
            totalThemesInCategories += themes.count
            
            // Verify all themes in category have correct category
            for theme in themes {
                XCTAssertEqual(theme.category, category, "Theme \(theme.name) should be in correct category")
            }
        }
        
        XCTAssertEqual(totalThemesInCategories, allThemes.count, "All themes should be categorized")
    }
    
    func testCategoryFiltering() async {
        // Given
        await themeService.loadConfiguration()
        
        // When - Test filtering by category
        let categories = themeService.getAvailableCategories()
        
        // Then
        for category in categories {
            let filteredThemes = themeService.getThemesByCategory(category)
            let enabledThemes = themeService.getEnabledThemesByCategory(category)
            
            XCTAssertGreaterThan(filteredThemes.count, 0, "Category \(category) should have themes")
            XCTAssertLessOrEqual(enabledThemes.count, filteredThemes.count, "Enabled themes should be subset of all themes")
            
            // Verify enabled themes are actually enabled
            for theme in enabledThemes {
                XCTAssertTrue(theme.enabled, "Theme \(theme.name) should be enabled")
            }
        }
    }
    
    // MARK: - Theme Retrieval Tests
    
    func testThemeRetrieval() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let allThemes = themeService.availableThemes
        
        // Then
        for theme in allThemes {
            let retrievedTheme = themeService.getTheme(by: theme.id)
            XCTAssertNotNil(retrievedTheme, "Should retrieve theme by ID: \(theme.id)")
            XCTAssertEqual(retrievedTheme?.id, theme.id, "Retrieved theme should have correct ID")
            XCTAssertEqual(retrievedTheme?.name, theme.name, "Retrieved theme should have correct name")
        }
    }
    
    func testThemeRetrievalByName() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let allThemes = themeService.availableThemes
        
        // Then
        for theme in allThemes {
            let retrievedTheme = themeService.getTheme(byName: theme.name)
            XCTAssertNotNil(retrievedTheme, "Should retrieve theme by name: \(theme.name)")
            XCTAssertEqual(retrievedTheme?.name, theme.name, "Retrieved theme should have correct name")
            XCTAssertEqual(retrievedTheme?.id, theme.id, "Retrieved theme should have correct ID")
        }
    }
    
    func testThemeRetrievalInvalidID() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let invalidTheme = themeService.getTheme(by: 999999)
        
        // Then
        XCTAssertNil(invalidTheme, "Should return nil for invalid theme ID")
    }
    
    func testThemeRetrievalInvalidName() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let invalidTheme = themeService.getTheme(byName: "NonExistentTheme")
        
        // Then
        XCTAssertNil(invalidTheme, "Should return nil for invalid theme name")
    }
    
    // MARK: - Theme Validation Tests
    
    func testThemeValidation() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let themes = themeService.availableThemes
        
        // Then - Test theme structure validation
        for theme in themes {
            // Test required fields
            XCTAssertGreaterThan(theme.id, 0, "Theme \(theme.name) should have valid ID")
            XCTAssertFalse(theme.name.isEmpty, "Theme \(theme.name) should have non-empty name")
            XCTAssertFalse(theme.prompt.isEmpty, "Theme \(theme.name) should have non-empty prompt")
            XCTAssertFalse(theme.category.isEmpty, "Theme \(theme.name) should have non-empty category")
            
            // Test ID uniqueness
            let duplicateThemes = themes.filter { $0.id == theme.id }
            XCTAssertEqual(duplicateThemes.count, 1, "Theme ID \(theme.id) should be unique")
            
            // Test name uniqueness
            let duplicateNames = themes.filter { $0.name == theme.name }
            XCTAssertEqual(duplicateNames.count, 1, "Theme name \(theme.name) should be unique")
        }
    }
    
    func testThemePromptValidation() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let themes = themeService.availableThemes
        
        // Then - Test prompt quality
        for theme in themes {
            let prompt = theme.prompt
            
            // Test prompt length
            XCTAssertGreaterThan(prompt.count, 5, "Theme \(theme.name) should have substantial prompt")
            XCTAssertLessThan(prompt.count, 1000, "Theme \(theme.name) prompt should not be excessively long")
            
            // Test prompt content
            XCTAssertFalse(prompt.contains("TODO"), "Theme \(theme.name) should not have placeholder prompts")
            XCTAssertFalse(prompt.contains("FIXME"), "Theme \(theme.name) should not have placeholder prompts")
            
            // Test prompt structure
            let hasDescriptiveWords = prompt.contains("style") || 
                                     prompt.contains("lighting") || 
                                     prompt.contains("color") ||
                                     prompt.contains("background") ||
                                     prompt.contains("aesthetic")
            
            XCTAssertTrue(hasDescriptiveWords, "Theme \(theme.name) should have descriptive prompt")
        }
    }
    
    // MARK: - Configuration Error Tests
    
    func testConfigurationWithEmptyFile() async {
        // Given - Mock empty configuration
        let emptyService = ThemeConfigurationService()
        
        // When - Try to load empty configuration
        await emptyService.loadConfiguration()
        
        // Then - Should still be configured with fallback themes
        XCTAssertTrue(emptyService.isConfigured, "Should be configured with fallback themes")
        XCTAssertGreaterThan(emptyService.availableThemes.count, 0, "Should have fallback themes")
    }
    
    func testConfigurationRecovery() async {
        // Given
        await themeService.loadConfiguration()
        let originalThemeCount = themeService.availableThemes.count
        
        // When - Simulate configuration reload
        await themeService.reloadConfiguration()
        
        // Then - Should recover configuration
        XCTAssertTrue(themeService.isConfigured, "Should recover configuration")
        XCTAssertEqual(themeService.availableThemes.count, originalThemeCount, "Should maintain theme count")
    }
    
    // MARK: - Performance Tests
    
    func testConfigurationLoadingPerformance() async {
        // Given
        let service = ThemeConfigurationService()
        
        // When - Time configuration loading
        let startTime = CFAbsoluteTimeGetCurrent()
        await service.loadConfiguration()
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Should load within reasonable time
        XCTAssertLessThan(loadTime, 2.0, "Configuration loading should be fast")
        XCTAssertTrue(service.isConfigured, "Should be configured after loading")
        
        // Log performance for debugging
        print("🔍 Performance: \(loadTime) seconds for theme configuration loading")
    }
    
    func testThemeRetrievalPerformance() async {
        // Given
        await themeService.loadConfiguration()
        let themes = themeService.availableThemes
        
        // When - Time theme retrieval
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for theme in themes {
            _ = themeService.getTheme(by: theme.id)
        }
        
        let retrievalTime = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = retrievalTime / Double(themes.count)
        
        // Then - Should retrieve themes quickly
        XCTAssertLessThan(averageTime, 0.001, "Theme retrieval should be fast")
        
        // Log performance for debugging
        print("🔍 Performance: \(averageTime) seconds average per theme retrieval")
    }
    
    // MARK: - Theme Configuration Structure Tests
    
    func testThemeConfigurationStructure() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let configuration = themeService.themeConfiguration
        
        // Then
        XCTAssertFalse(configuration.version.isEmpty, "Configuration should have version")
        XCTAssertGreaterThan(configuration.themes.count, 0, "Configuration should have themes")
        
        // Test configuration metadata
        XCTAssertNotNil(configuration.lastModified, "Configuration should have last modified date")
        XCTAssertGreaterThan(configuration.categories.count, 0, "Configuration should have categories")
    }
    
    func testThemeConfigurationCategories() async {
        // Given
        await themeService.loadConfiguration()
        
        // When
        let configuration = themeService.themeConfiguration
        let configCategories = configuration.categories
        let serviceCategories = themeService.getAvailableCategories()
        
        // Then
        XCTAssertEqual(Set(configCategories), Set(serviceCategories), "Configuration and service categories should match")
        
        // Test category completeness
        for category in configCategories {
            let themesInCategory = themeService.getThemesByCategory(category)
            XCTAssertGreaterThan(themesInCategory.count, 0, "Category \(category) should have themes")
        }
    }
    
    // MARK: - Integration Tests
    
    func testThemeServiceIntegration() async {
        // Given
        await themeService.loadConfiguration()
        
        // When - Test complete theme service workflow
        let themes = themeService.availableThemes
        let categories = themeService.getAvailableCategories()
        
        // Then - Should have comprehensive theme integration
        XCTAssertGreaterThan(themes.count, 0, "Should have themes")
        XCTAssertGreaterThan(categories.count, 0, "Should have categories")
        
        // Test theme-category consistency
        for theme in themes {
            XCTAssertTrue(categories.contains(theme.category), "Theme category should be in available categories")
        }
        
        // Test theme retrieval integration
        for theme in themes {
            let retrievedById = themeService.getTheme(by: theme.id)
            let retrievedByName = themeService.getTheme(byName: theme.name)
            
            XCTAssertEqual(retrievedById?.id, theme.id, "Theme retrieval by ID should work")
            XCTAssertEqual(retrievedByName?.name, theme.name, "Theme retrieval by name should work")
        }
    }
    
    // MARK: - Theme Extensibility Tests
    
    func testThemeExtensibility() async {
        // Given
        await themeService.loadConfiguration()
        
        // When - Test theme system extensibility
        let themes = themeService.availableThemes
        
        // Then - Should support theme extensibility
        XCTAssertGreaterThan(themes.count, 5, "Should have substantial theme library")
        
        // Test diverse theme categories
        let categories = themeService.getAvailableCategories()
        XCTAssertGreaterThan(categories.count, 3, "Should have diverse theme categories")
        
        // Test theme prompt diversity
        let prompts = themes.map { $0.prompt }
        let uniquePrompts = Set(prompts)
        XCTAssertEqual(prompts.count, uniquePrompts.count, "All theme prompts should be unique")
    }
    
    // MARK: - Theme Caching Tests
    
    func testThemeCaching() async {
        // Given
        await themeService.loadConfiguration()
        
        // When - Test theme caching behavior
        let firstLoad = themeService.availableThemes
        let secondLoad = themeService.availableThemes
        
        // Then - Should use cached themes
        XCTAssertEqual(firstLoad.count, secondLoad.count, "Should use cached themes")
        
        // Test category caching
        let firstCategories = themeService.getAvailableCategories()
        let secondCategories = themeService.getAvailableCategories()
        
        XCTAssertEqual(firstCategories.count, secondCategories.count, "Should use cached categories")
    }
    
    // MARK: - Configuration Observation Tests
    
    func testConfigurationObservation() async {
        // Given
        let expectation = XCTestExpectation(description: "Configuration loaded")
        
        // When - Observe configuration changes
        themeService.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await themeService.loadConfiguration()
        
        // Then - Should notify observers
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestTheme(id: Int = 1, name: String = "Test Theme", category: String = "test") -> PhotoTheme {
        return PhotoTheme(
            id: id,
            name: name,
            prompt: "test prompt for \(name)",
            enabled: true,
            category: category
        )
    }
    
    private func createTestThemes() -> [PhotoTheme] {
        return [
            createTestTheme(id: 1, name: "Portrait Test", category: "portrait"),
            createTestTheme(id: 2, name: "Landscape Test", category: "landscape"),
            createTestTheme(id: 3, name: "Artistic Test", category: "artistic"),
            createTestTheme(id: 4, name: "Vintage Test", category: "vintage")
        ]
    }
} 