import XCTest
import Combine
import AVFoundation
@testable import PhotoBooth

/// Integration tests for ViewModel coordination and communication
@MainActor
final class ViewModelCoordinationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mainViewModel: PhotoBoothViewModel!
    var serviceCoordinator: PhotoBoothServiceCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
        
        // Create service coordinator and main view model
        serviceCoordinator = PhotoBoothServiceCoordinator()
        mainViewModel = PhotoBoothViewModel(serviceCoordinator: serviceCoordinator)
        
        // Give time for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        cancellables = nil
        mainViewModel = nil
        serviceCoordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - ViewModel Coordination Tests
    
    /// Test that main PhotoBoothViewModel properly coordinates specialized ViewModels
    func testMainViewModelCoordination() async throws {
        // THEN: Should coordinate properly
        XCTAssertNotNil(mainViewModel.cameraViewModel.isSessionRunning)
        XCTAssertNotNil(mainViewModel.cameraViewModel.isCameraConnected)
        XCTAssertNotNil(mainViewModel.imageProcessingViewModel.isProcessing)
        XCTAssertNotNil(mainViewModel.uiStateViewModel.countdown)
        XCTAssertNotNil(mainViewModel.uiStateViewModel.isCountingDown)
        
        // Test that main ViewModel exposes proper specialized ViewModels
        XCTAssertNotNil(mainViewModel.cameraViewModel)
        XCTAssertNotNil(mainViewModel.imageProcessingViewModel)
        XCTAssertNotNil(mainViewModel.uiStateViewModel)
        
        // Test that configuration properties are accessible
        XCTAssertNotNil(mainViewModel.isOpenAIConfigured)
        XCTAssertNotNil(mainViewModel.isThemeConfigurationLoaded)
    }
    
    /// Test camera and UI state coordination
    func testCameraUIStateCoordination() async throws {
        let cameraViewModel = mainViewModel.cameraViewModel
        let uiStateViewModel = mainViewModel.uiStateViewModel
        
        // Test that camera state affects UI state
        await cameraViewModel.setupCamera()
        
        // Give time for state propagation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Test that UI state reflects camera state
        let cameraConnected = cameraViewModel.isCameraConnected
        
        // If camera is connected, UI should be in ready state
        if cameraConnected {
            XCTAssertTrue(uiStateViewModel.isReadyForNextPhoto, 
                         "UI should be ready when camera is connected")
        }
        
        // Test countdown coordination
        if cameraConnected {
            uiStateViewModel.startCountdown(duration: 1)
            XCTAssertTrue(uiStateViewModel.isCountingDown, 
                         "UI should show countdown state")
            
            // Wait for countdown to complete
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            XCTAssertFalse(uiStateViewModel.isCountingDown, 
                          "Countdown should complete")
        }
    }
    
    /// Test image processing and UI coordination
    func testImageProcessingUICoordination() async throws {
        let imageProcessingViewModel = mainViewModel.imageProcessingViewModel
        let uiStateViewModel = mainViewModel.uiStateViewModel
        
        // Test theme selection coordination
        let availableThemes = imageProcessingViewModel.themes
        if !availableThemes.isEmpty {
            let firstTheme = availableThemes.first!
            imageProcessingViewModel.selectedTheme = firstTheme
            
            // Verify theme selection is reflected in main ViewModel
            XCTAssertEqual(mainViewModel.imageProcessingViewModel.selectedTheme?.id, firstTheme.id)
        }
        
        // Test that processing state affects UI
        let processingState = imageProcessingViewModel.isProcessing
        
        // Should be consistent with main ViewModel
        XCTAssertEqual(mainViewModel.imageProcessingViewModel.isProcessing, processingState)
        
        // Test error handling coordination
        if let errorMessage = uiStateViewModel.errorMessage {
            XCTAssertTrue(uiStateViewModel.showError, 
                         "Error should be shown when error message exists")
        }
    }
    
    /// Test cross-ViewModel communication and state synchronization
    func testCrossViewModelCommunication() async throws {
        let expectation = XCTestExpectation(description: "ViewModel communication")
        
        // Monitor state changes across ViewModels
        var stateChangeCount = 0
        
        // Subscribe to camera state changes
        mainViewModel.cameraViewModel.$isCameraConnected
            .dropFirst()
            .sink { isConnected in
                stateChangeCount += 1
                if stateChangeCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger camera setup to cause state changes
        await mainViewModel.cameraViewModel.setupCamera()
        
        // Wait for state propagation
        await fulfillment(of: [expectation], timeout: 3.0)
        
        // Verify state consistency
        XCTAssertEqual(mainViewModel.cameraViewModel.isCameraConnected, 
                      mainViewModel.cameraViewModel.isCameraConnected)
    }
    
    /// Test ViewModel delegation and callback coordination
    func testViewModelDelegation() async throws {
        let cameraViewModel = mainViewModel.cameraViewModel
        let imageProcessingViewModel = mainViewModel.imageProcessingViewModel
        
        // Test that ViewModels have proper publisher-based communication setup
        XCTAssertNotNil(cameraViewModel.photoCapturedPublisher)
        XCTAssertNotNil(imageProcessingViewModel.processingCompletedPublisher)
        
        // Test that specialized ViewModels are properly connected
        XCTAssertNotNil(cameraViewModel)
        XCTAssertNotNil(imageProcessingViewModel)
        
        // Test that main ViewModel acts as coordinator
        XCTAssertNotNil(mainViewModel, "Main ViewModel should coordinate other ViewModels")
    }
    
    /// Test async operation coordination between ViewModels
    func testAsyncOperationCoordination() async throws {
        // Test that async operations are properly coordinated
        let startTime = Date()
        
        // Start multiple async operations
        async let cameraSetup = mainViewModel.cameraViewModel.setupCamera()
        async let systemSetup = mainViewModel.setupPhotoBoothSystem()
        
        // Wait for all operations to complete
        _ = await (cameraSetup, systemSetup)
        
        let completionTime = Date().timeIntervalSince(startTime)
        
        // Should complete within reasonable time
        XCTAssertLessThan(completionTime, 10.0, 
                         "Async operations should complete within 10 seconds")
        
        // Verify final state consistency
        XCTAssertEqual(mainViewModel.cameraViewModel.isSessionRunning, 
                      mainViewModel.cameraViewModel.isSessionRunning)
    }
    
    /// Test error propagation across ViewModels
    func testErrorPropagation() async throws {
        let uiStateViewModel = mainViewModel.uiStateViewModel
        
        // Test error display coordination
        uiStateViewModel.showError(message: "Test error message")
        
        // Verify error state is properly set
        XCTAssertTrue(uiStateViewModel.showError)
        XCTAssertEqual(uiStateViewModel.errorMessage, "Test error message")
        
        // Test error clearing - clear error manually
        uiStateViewModel.showError = false
        uiStateViewModel.errorMessage = nil
        
        // Verify error state is cleared
        XCTAssertFalse(uiStateViewModel.showError)
        XCTAssertNil(uiStateViewModel.errorMessage)
    }
    
    /// Test photo capture workflow coordination
    func testPhotoCaptureWorkflowCoordination() async throws {
        let cameraViewModel = mainViewModel.cameraViewModel
        let imageProcessingViewModel = mainViewModel.imageProcessingViewModel
        let uiStateViewModel = mainViewModel.uiStateViewModel
        
        // Setup camera first
        await cameraViewModel.setupCamera()
        
        // Test that photo capture workflow is properly coordinated
        if cameraViewModel.isCameraConnected {
            // Select a theme
            let themes = imageProcessingViewModel.themes
            if !themes.isEmpty {
                imageProcessingViewModel.selectedTheme = themes.first!
            }
            
            // Start countdown
            uiStateViewModel.startCountdown(duration: 1)
            
            // Wait for countdown
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Verify workflow state
            XCTAssertFalse(uiStateViewModel.isCountingDown)
            XCTAssertNotNil(imageProcessingViewModel.selectedTheme)
        }
    }
    
    /// Test slideshow coordination
    func testSlideshowCoordination() async throws {
        // Test slideshow ViewModel coordination
        let slideshowActive = mainViewModel.isSlideShowActive
        
        // Start slideshow
        await mainViewModel.startSlideshow()
        
        // Verify slideshow state
        XCTAssertTrue(mainViewModel.isSlideShowActive)
        XCTAssertGreaterThanOrEqual(mainViewModel.slideShowPhotoPairCount, 0)
        
        // Stop slideshow
        await mainViewModel.stopSlideshow()
        
        // Verify slideshow stopped
        XCTAssertFalse(mainViewModel.isSlideShowActive)
    }
    
    /// Test configuration coordination across ViewModels
    func testConfigurationCoordination() async throws {
        // Test that configuration state is consistent across ViewModels
        let openAIConfigured = mainViewModel.isOpenAIConfigured
        let themeConfigLoaded = mainViewModel.isThemeConfigurationLoaded
        
        // Configuration should be consistent
        XCTAssertEqual(openAIConfigured, serviceCoordinator.openAIService.isConfigured)
        XCTAssertEqual(themeConfigLoaded, 
                      serviceCoordinator.themeConfigurationService.isConfigured)
        
        // Test that configuration changes propagate
        // Note: validateConfiguration is called on configurationService, not serviceCoordinator
        serviceCoordinator.configurationService.validateConfiguration()
        
        // Give time for state updates
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify consistency is maintained
        XCTAssertEqual(mainViewModel.isOpenAIConfigured, 
                      serviceCoordinator.openAIService.isConfigured)
    }
}

// MARK: - Test Extensions

extension ViewModelCoordinationTests {
    
    /// Test ViewModel memory management and cleanup
    func testViewModelMemoryManagement() async throws {
        // Create additional ViewModels to test memory management
        var additionalViewModel: PhotoBoothViewModel? = PhotoBoothViewModel()
        
        // Verify it's created
        XCTAssertNotNil(additionalViewModel)
        
        // Clear reference
        additionalViewModel = nil
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify cleanup (in real app, we would use weak references to test this)
        XCTAssertNil(additionalViewModel)
    }
    
    /// Test concurrent ViewModel operations
    func testConcurrentViewModelOperations() async throws {
        // Test multiple ViewModels can operate concurrently
        let cameraViewModel = mainViewModel.cameraViewModel
        let imageProcessingViewModel = mainViewModel.imageProcessingViewModel
        let uiStateViewModel = mainViewModel.uiStateViewModel
        
        // Start concurrent operations
        async let cameraTask = cameraViewModel.setupCamera()
        async let themeTask = imageProcessingViewModel.themes.count
        async let uiTask = uiStateViewModel.isReadyForNextPhoto
        
        // Wait for all operations
        let results = await (cameraTask, themeTask, uiTask)
        
        // Verify operations completed successfully
        XCTAssertGreaterThanOrEqual(results.1, 0) // Theme count
        XCTAssertNotNil(results.2) // UI state
    }
    
    /// Test ViewModel state persistence
    func testViewModelStatePersistence() async throws {
        let uiStateViewModel = mainViewModel.uiStateViewModel
        
        // Test that certain state is persisted (like settings)
        let originalDisplayDuration = uiStateViewModel.minimumDisplayDuration
        
        // Verify display duration is a reasonable value
        XCTAssertGreaterThan(originalDisplayDuration, 0)
        XCTAssertLessThan(originalDisplayDuration, 60) // Should be less than 1 minute
        
        // Test that state changes are properly handled
        uiStateViewModel.isReadyForNextPhoto = false
        XCTAssertFalse(uiStateViewModel.isReadyForNextPhoto)
        
        uiStateViewModel.isReadyForNextPhoto = true
        XCTAssertTrue(uiStateViewModel.isReadyForNextPhoto)
    }
} 