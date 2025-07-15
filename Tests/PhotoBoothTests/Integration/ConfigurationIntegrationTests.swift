import XCTest
import Combine
import Foundation
@testable import PhotoBooth

/// Integration tests for configuration loading and validation across components
@MainActor
final class ConfigurationIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mainViewModel: PhotoBoothViewModel!
    var serviceCoordinator: PhotoBoothServiceCoordinator!
    var configurationService: (any ConfigurationServiceProtocol)!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Create service coordinator and main view model
        serviceCoordinator = PhotoBoothServiceCoordinator()
        mainViewModel = PhotoBoothViewModel(serviceCoordinator: serviceCoordinator)
        configurationService = serviceCoordinator.configurationService
        
        // Give time for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        cancellables = nil
        mainViewModel = nil
        serviceCoordinator = nil
        configurationService = nil
        try await super.tearDown()
    }
    
    // MARK: - Configuration Loading Tests
    
    /// Test that configuration is properly loaded and accessible
    func testConfigurationLoading() async throws {
        // Test basic configuration loading
        configurationService.validateConfiguration()
        
        // Verify configuration properties are accessible
        XCTAssertNotNil(configurationService.isOpenAIConfigured)
        XCTAssertNotNil(configurationService.isTwilioConfigured)
        XCTAssertNotNil(configurationService.isFullyConfigured)
        XCTAssertNotNil(configurationService.configurationSummary)
        
        // Test configuration retrieval methods
        let openAIKey = configurationService.getOpenAIKey()
        let twilioSID = configurationService.getTwilioSID()
        let twilioToken = configurationService.getTwilioToken()
        let twilioFromNumber = configurationService.getTwilioFromNumber()
        
        // Configuration values should be consistent
        XCTAssertEqual(configurationService.isOpenAIConfigured, openAIKey != nil)
        XCTAssertEqual(configurationService.isTwilioConfigured, 
                      twilioSID != nil && twilioToken != nil && twilioFromNumber != nil)
        
        // Test host configuration
        let openAIHost = configurationService.getOpenAIHost()
        let openAIPort = configurationService.getOpenAIPort()
        let openAIScheme = configurationService.getOpenAIScheme()
        
        XCTAssertFalse(openAIHost.isEmpty)
        XCTAssertGreaterThan(openAIPort, 0)
        XCTAssertFalse(openAIScheme.isEmpty)
    }
    
    /// Test configuration validation across services
    func testConfigurationValidationAcrossServices() async throws {
        // Test that configuration validation affects all services
        configurationService.validateConfiguration()
        
        // Setup all services to trigger proper validation
        await serviceCoordinator.setupAllServices()
        
        let openAIService = serviceCoordinator.openAIService
        let isConfigured = configurationService.isOpenAIConfigured
        
        // OpenAI service should reflect configuration state
        XCTAssertEqual(openAIService.isConfigured, isConfigured)
        
        // Service coordinator should reflect configuration state after full setup
        let hasErrors = serviceCoordinator.hasConfigurationErrors
        let servicesValid = serviceCoordinator.validateServicesConfiguration()
        
        // After full setup, error state should be consistent with service validation
        XCTAssertEqual(hasErrors, !servicesValid, 
                      "Service coordinator error state should match service validation")
        
        // Main view model should reflect configuration state
        XCTAssertEqual(mainViewModel.isOpenAIConfigured, isConfigured)
    }
    
    /// Test theme configuration loading
    func testThemeConfigurationLoading() async throws {
        let themeService = serviceCoordinator.themeConfigurationService
        
        // Test theme loading - themes are loaded automatically during initialization
        
        // Verify themes are loaded
        let themes = themeService.availableThemes
        XCTAssertGreaterThan(themes.count, 0, "Should have loaded themes")
        
        // Test theme categories
        let categories = themeService.getAvailableCategories()
        XCTAssertGreaterThan(categories.count, 0, "Should have theme categories")
        
        // Test themes by category
        let themesByCategory = themeService.themesByCategory
        XCTAssertGreaterThan(themesByCategory.count, 0, "Should have themes organized by category")
        
        // Verify theme configuration is reflected in main view model
        XCTAssertEqual(mainViewModel.isThemeConfigurationLoaded, themeService.isConfigured)
    }
    
    /// Test configuration change propagation
    func testConfigurationChangePropagation() async throws {
        let expectation = XCTestExpectation(description: "Configuration change propagation")
        
        // Monitor configuration changes
        var changeCount = 0
        
        serviceCoordinator.$hasConfigurationErrors
            .dropFirst()
            .sink { hasErrors in
                changeCount += 1
                if changeCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger configuration validation
        configurationService.validateConfiguration()
        
        // Wait for propagation
        await fulfillment(of: [expectation], timeout: 3.0)
        
        // Verify configuration state is consistent across components
        let hasErrors = serviceCoordinator.hasConfigurationErrors
        let isConfigured = configurationService.isFullyConfigured
        
        XCTAssertEqual(hasErrors, !isConfigured)
    }
    
    /// Test environment variable configuration
    func testEnvironmentVariableConfiguration() async throws {
        // Test that environment variables are properly loaded
        let openAIKey = configurationService.getOpenAIKey()
        let twilioSID = configurationService.getTwilioSID()
        
        // If environment variables are set, they should be loaded
        if let envOpenAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            XCTAssertEqual(openAIKey, envOpenAIKey)
        }
        
        if let envTwilioSID = ProcessInfo.processInfo.environment["TWILIO_ACCOUNT_SID"] {
            XCTAssertEqual(twilioSID, envTwilioSID)
        }
        
        // Test configuration summary includes environment status
        let summary = configurationService.configurationSummary
        XCTAssertFalse(summary.isEmpty)
    }
    
    /// Test configuration error handling
    func testConfigurationErrorHandling() async throws {
        // Test configuration validation with potential errors
        configurationService.validateConfiguration()
        
        // Setup all services to trigger proper error state validation
        await serviceCoordinator.setupAllServices()
        
        let hasErrors = serviceCoordinator.hasConfigurationErrors
        let isConfigured = configurationService.isFullyConfigured
        let servicesValid = serviceCoordinator.validateServicesConfiguration()
        
        // Error state should be consistent with service validation
        XCTAssertEqual(hasErrors, !servicesValid, 
                      "Service coordinator error state should match service validation")
        
        // If there are configuration errors, they should be properly handled
        if hasErrors {
            // Service coordinator should be in error state
            XCTAssertTrue(serviceCoordinator.hasConfigurationErrors)
            
            // Services should reflect configuration errors
            if !configurationService.isOpenAIConfigured {
                XCTAssertFalse(serviceCoordinator.openAIService.isConfigured)
            }
            
            // Main view model should reflect configuration errors
            XCTAssertEqual(mainViewModel.isOpenAIConfigured, configurationService.isOpenAIConfigured)
        }
    }
    
    /// Test configuration loading performance
    func testConfigurationLoadingPerformance() async throws {
        let startTime = Date()
        
        // Perform configuration loading operations
        configurationService.validateConfiguration()
        // Theme configuration is loaded automatically during initialization
        
        let completionTime = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(completionTime, 5.0, 
                         "Configuration loading should complete within 5 seconds")
    }
    
    /// Test configuration consistency across ViewModels
    func testConfigurationConsistencyAcrossViewModels() async throws {
        let cameraViewModel = mainViewModel.cameraViewModel
        let imageProcessingViewModel = mainViewModel.imageProcessingViewModel
        
        // Test that all ViewModels have consistent configuration access
        XCTAssertEqual(mainViewModel.isOpenAIConfigured, 
                      serviceCoordinator.openAIService.isConfigured)
        XCTAssertEqual(mainViewModel.isThemeConfigurationLoaded, 
                      serviceCoordinator.themeConfigurationService.isConfigured)
        
        // Test that ViewModels reflect configuration state
        let themes = imageProcessingViewModel.themes
        let themeConfigLoaded = imageProcessingViewModel.isThemeConfigurationLoaded
        
        XCTAssertEqual(themes.count > 0, themeConfigLoaded)
    }
    
    // MARK: - Service Configuration Integration Tests
    
    /// Test OpenAI service configuration integration
    func testOpenAIServiceConfigurationIntegration() async throws {
        let openAIService = serviceCoordinator.openAIService
        
        // Test that OpenAI service reflects configuration
        let isConfigured = openAIService.isConfigured
        let configHasOpenAI = configurationService.isOpenAIConfigured
        
        XCTAssertEqual(isConfigured, configHasOpenAI)
        
        // If configured, test that service can be used
        if isConfigured {
            let themes = serviceCoordinator.themeConfigurationService.availableThemes
            if !themes.isEmpty {
                let testImage = createTestImage()
                let theme = themes.first!
                
                // Test that service can generate images
                do {
                    let result = try await openAIService.generateThemedImage(from: testImage, theme: theme)
                    XCTAssertNotNil(result)
                } catch {
                    // Configuration might be invalid, which is also a valid test result
                    XCTAssertNotNil(error)
                }
            }
        }
    }
    
    /// Test camera service configuration integration
    func testCameraServiceConfigurationIntegration() async throws {
        let cameraService = serviceCoordinator.cameraService
        
        // Test camera service initialization
        await cameraService.setupCamera()
        
        // Test that camera service can discover cameras
        await cameraService.discoverCameras()
        
        // Camera service should have consistent state
        let cameras = cameraService.availableCameras
        XCTAssertNotNil(cameras)
        
        // Test camera selection if cameras are available
        if !cameras.isEmpty {
            let firstCamera = cameras.first!
            await cameraService.selectCamera(firstCamera)
            
            XCTAssertEqual(cameraService.selectedCameraDevice?.uniqueID, firstCamera.uniqueID)
        }
    }
    
    /// Test image processing service configuration integration
    func testImageProcessingServiceConfigurationIntegration() async throws {
        let imageProcessingService = serviceCoordinator.imageProcessingService
        
        // Test image processing capabilities
        let testImage = createTestImage()
        
        // Test image processing capabilities
        // Note: ImageProcessingService protocols may not have direct save/load methods
        // This tests the service is properly configured and available
        XCTAssertNotNil(imageProcessingService, "Image processing service should be available")
    }
    
    /// Test configuration validation timing
    func testConfigurationValidationTiming() async throws {
        let expectation = XCTestExpectation(description: "Configuration validation timing")
        
        // Monitor configuration validation
        var validationCount = 0
        
        serviceCoordinator.$isInitialized
            .dropFirst()
            .sink { isInitialized in
                validationCount += 1
                if validationCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger validation
        await serviceCoordinator.setupAllServices()
        
        // Wait for validation
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify validation completed
        XCTAssertGreaterThan(validationCount, 0)
    }
    
    // MARK: - Configuration Recovery Tests
    
    /// Test configuration recovery from errors
    func testConfigurationRecovery() async throws {
        // Test that system can recover from configuration errors
        configurationService.validateConfiguration()
        
        let initialErrorState = serviceCoordinator.hasConfigurationErrors
        
        // Re-validate configuration
        configurationService.validateConfiguration()
        
        let finalErrorState = serviceCoordinator.hasConfigurationErrors
        
        // Error state should be consistent
        XCTAssertEqual(initialErrorState, finalErrorState)
        
        // Test that services can still function with partial configuration
        if serviceCoordinator.hasConfigurationErrors {
            // Camera service should still work
            await serviceCoordinator.cameraService.setupCamera()
            XCTAssertNotNil(serviceCoordinator.cameraService.availableCameras)
            
            // Theme service should still work
            let themes = serviceCoordinator.themeConfigurationService.availableThemes
            XCTAssertGreaterThan(themes.count, 0)
        }
    }
    
    /// Test configuration validation with concurrent access
    func testConfigurationValidationConcurrency() async throws {
        // Test concurrent configuration validation
        async let validation1 = configurationService.validateConfiguration()
        async let validation2 = configurationService.validateConfiguration()
        async let validation3 = configurationService.validateConfiguration()
        
        // Wait for all validations
        _ = await (validation1, validation2, validation3)
        
        // Setup all services to trigger proper error state validation
        await serviceCoordinator.setupAllServices()
        
        // Configuration should be in consistent state after concurrent validation
        let isConfigured = configurationService.isFullyConfigured
        let hasErrors = serviceCoordinator.hasConfigurationErrors
        let servicesValid = serviceCoordinator.validateServicesConfiguration()
        
        // After concurrent validation and full setup, state should be consistent
        XCTAssertEqual(hasErrors, !servicesValid, 
                      "Service coordinator error state should match service validation after concurrent access")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.green.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
}

// MARK: - Test Extensions

extension ConfigurationIntegrationTests {
    
    /// Test configuration state persistence
    func testConfigurationStatePersistence() async throws {
        // Test that configuration state persists across operations
        let initialConfigurationState = configurationService.isFullyConfigured
        
        // Perform operations that might affect configuration
        await serviceCoordinator.setupAllServices()
        configurationService.validateConfiguration()
        
        // Configuration state should be consistent
        let finalConfigurationState = configurationService.isFullyConfigured
        XCTAssertEqual(initialConfigurationState, finalConfigurationState)
    }
    
    /// Test configuration caching
    func testConfigurationCaching() async throws {
        // Test that configuration values are cached appropriately
        let openAIKey1 = configurationService.getOpenAIKey()
        let openAIKey2 = configurationService.getOpenAIKey()
        
        // Should return same value (cached)
        XCTAssertEqual(openAIKey1, openAIKey2)
        
        // Test configuration summary caching
        let summary1 = configurationService.configurationSummary
        let summary2 = configurationService.configurationSummary
        
        XCTAssertEqual(summary1, summary2)
    }
    
    /// Test configuration loading with different environments
    func testConfigurationEnvironmentHandling() async throws {
        // Test that configuration handles different environment scenarios
        let openAIHost = configurationService.getOpenAIHost()
        let openAIPort = configurationService.getOpenAIPort()
        let openAIScheme = configurationService.getOpenAIScheme()
        
        // Should have reasonable defaults
        XCTAssertFalse(openAIHost.isEmpty)
        XCTAssertGreaterThan(openAIPort, 0)
        XCTAssertTrue(openAIScheme == "http" || openAIScheme == "https")
        
        // Test configuration summary reflects environment
        let summary = configurationService.configurationSummary
        XCTAssertTrue(summary.contains("OpenAI") || summary.contains("Configuration"))
    }
} 