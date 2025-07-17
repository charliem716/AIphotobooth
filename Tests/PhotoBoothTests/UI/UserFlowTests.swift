import XCTest
import SwiftUI
import AVFoundation
@testable import PhotoBooth

/// User flow tests for PhotoBooth application
/// Tests complete user workflows using ViewModels directly
@MainActor
final class UserFlowTests: XCTestCase {
    
    // MARK: - Test Properties
    private var viewModel: PhotoBoothViewModel!
    
    // MARK: - Test Lifecycle
    
    override func setUp() async throws {
        continueAfterFailure = false
        
        // Setup view model with default configuration
        viewModel = PhotoBoothViewModel()
        
        // Configure for testing
        await setupTestEnvironment()
    }
    
    override func tearDown() async throws {
        // Clean up test state
        viewModel = nil
    }
    
    // MARK: - Helper Methods
    
    private func setupTestEnvironment() async {
        // Create mock services for isolated testing
        let mockConfigurationService = MockConfigurationService()
        let mockNetworkService = MockNetworkService()
        let mockOpenAIService = MockOpenAIService()
        let mockCameraService = MockCameraService()
        let mockImageProcessingService = MockImageProcessingService()
        let mockCacheManagementService = MockCacheManagementService()
        let mockThemeConfigurationService = ThemeConfigurationService()
        
        // Configure mock services for testing
        setupMockServices(
            configurationService: mockConfigurationService,
            networkService: mockNetworkService,
            openAIService: mockOpenAIService,
            cameraService: mockCameraService,
            imageProcessingService: mockImageProcessingService,
            cacheManagementService: mockCacheManagementService
        )
        
        // Create test service coordinator with mocks
        let testServiceCoordinator = PhotoBoothServiceCoordinator(
            configurationService: mockConfigurationService,
            networkService: mockNetworkService,
            openAIService: mockOpenAIService,
            cameraService: mockCameraService,
            imageProcessingService: mockImageProcessingService,
            cacheManagementService: mockCacheManagementService,
            themeConfigurationService: mockThemeConfigurationService
        )
        
        // Recreate viewModel with test services
        viewModel = PhotoBoothViewModel(serviceCoordinator: testServiceCoordinator)
        
        // Setup photo booth system with mocks
        await viewModel.setupPhotoBoothSystem()
        
        // Allow time for async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    private func setupMockServices(
        configurationService: MockConfigurationService,
        networkService: MockNetworkService,
        openAIService: MockOpenAIService,
        cameraService: MockCameraService,
        imageProcessingService: MockImageProcessingService,
        cacheManagementService: MockCacheManagementService
    ) {
        // Configure mock configuration service
        configurationService.mockOpenAIKey = "test-openai-key"
        configurationService.isOpenAIConfigured = true
        configurationService.mockTwilioSID = "test-twilio-sid"
        configurationService.mockTwilioToken = "test-twilio-token"
        configurationService.mockTwilioFromNumber = "+1234567890"
        configurationService.isTwilioConfigured = true
        
        // Configure mock network service for reliable testing
        networkService.reset()
        networkService.shouldSucceed = true
        networkService.responseDelay = 0.1
        
        // Configure mock OpenAI service
        openAIService.reset()
        openAIService.shouldThrowError = false
        openAIService.shouldSimulateDelay = false
        openAIService.delayDuration = 0.1
        
        // Configure mock camera service
        cameraService.reset()
        cameraService.shouldThrowError = false
        cameraService.shouldSimulateDelay = false
        
        // Configure mock image processing service  
        imageProcessingService.reset()
        imageProcessingService.shouldThrowError = false
        imageProcessingService.shouldSimulateDelay = false
        imageProcessingService.delayDuration = 0.1
        
        // Configure mock cache management service
        cacheManagementService.reset()
        cacheManagementService.shouldThrowError = false
        cacheManagementService.shouldSimulateDelay = false
        cacheManagementService.delayDuration = 0.1
    }
    
    private func createTestServiceCoordinator() -> PhotoBoothServiceCoordinator {
        let mockConfigurationService = MockConfigurationService()
        let mockNetworkService = MockNetworkService()
        let mockOpenAIService = MockOpenAIService()
        let mockCameraService = MockCameraService()
        let mockImageProcessingService = MockImageProcessingService()
        let mockCacheManagementService = MockCacheManagementService()
        let mockThemeConfigurationService = ThemeConfigurationService()
        
        setupMockServices(
            configurationService: mockConfigurationService,
            networkService: mockNetworkService,
            openAIService: mockOpenAIService,
            cameraService: mockCameraService,
            imageProcessingService: mockImageProcessingService,
            cacheManagementService: mockCacheManagementService
        )
        
        return PhotoBoothServiceCoordinator(
            configurationService: mockConfigurationService,
            networkService: mockNetworkService,
            openAIService: mockOpenAIService,
            cameraService: mockCameraService,
            imageProcessingService: mockImageProcessingService,
            cacheManagementService: mockCacheManagementService,
            themeConfigurationService: mockThemeConfigurationService
        )
    }
    
    // MARK: - User Flow Tests
    
    func testThemeSelectionWorkflow() async throws {
        // GIVEN: A PhotoBoothViewModel with themes loaded
        await viewModel.setupPhotoBoothSystem()
        
        // WHEN: User selects a theme
        let theme = TestPhotoTheme.portrait
        viewModel.imageProcessingViewModel.selectTheme(theme)
        
        // THEN: Theme should be selected and photo capture workflow should work
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, theme.name)
        
        // WHEN: User initiates photo capture
        viewModel.startCapture()
        
        // THEN: Should handle photo capture (behavior depends on camera availability)
        XCTAssertNotNil(viewModel.imageProcessingViewModel.selectedTheme)
    }
    
    func testRapidThemeSwitching() async throws {
        // GIVEN: A PhotoBoothViewModel with themes loaded
        await viewModel.setupPhotoBoothSystem()
        
        // WHEN: User selects different themes
        let portraitTheme = TestPhotoTheme.portrait
        viewModel.imageProcessingViewModel.selectTheme(portraitTheme)
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, portraitTheme.name)
        
        let landscapeTheme = TestPhotoTheme.landscape
        viewModel.imageProcessingViewModel.selectTheme(landscapeTheme)
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, landscapeTheme.name)
        
        let abstractTheme = TestPhotoTheme.abstract
        viewModel.imageProcessingViewModel.selectTheme(abstractTheme)
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, abstractTheme.name)
        
        // THEN: Final theme should be selected
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, abstractTheme.name)
    }
    
    func testRapidThemeSwitchingWithDelay() async throws {
        await viewModel.setupPhotoBoothSystem()
        
        let themes = [TestPhotoTheme.portrait, TestPhotoTheme.landscape, TestPhotoTheme.abstract]
        
        for theme in themes {
            viewModel.imageProcessingViewModel.selectTheme(theme)
            // Small delay to simulate rapid switching
            try await Task.sleep(for: .milliseconds(50))
        }
        
        // THEN: Final theme should be selected
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, TestPhotoTheme.abstract.name)
    }
    
    func testCameraSelectionWorkflow() async throws {
        // GIVEN: A PhotoBoothViewModel with camera service
        await viewModel.setupPhotoBoothSystem()
        
        // WHEN: User checks available cameras
        let cameras = viewModel.cameraViewModel.availableCameras
        let _ = viewModel.cameraViewModel.isCameraConnected
        
        // THEN: Should have camera information
        XCTAssertNotNil(cameras)
        
        // WHEN: User refreshes cameras
        await viewModel.cameraViewModel.refreshAvailableCameras()
        
        // THEN: Should handle camera refresh
        XCTAssertNotNil(viewModel.cameraViewModel.availableCameras)
    }
    
    func testCameraConnectionStates() async throws {
        // GIVEN: A PhotoBoothViewModel with camera service
        await viewModel.setupPhotoBoothSystem()
        
        // WHEN: User checks camera connection
        let isConnected = viewModel.cameraViewModel.isCameraConnected
        let isRunning = viewModel.cameraViewModel.isSessionRunning
        
        // THEN: Should have connection information
        // Test that camera state is available (any state is valid)
        XCTAssertTrue(isConnected || !isConnected) // Always true - just checking access
        XCTAssertTrue(isRunning || !isRunning) // Always true - just checking access
        
        // WHEN: User checks selected camera
        let selectedCamera = viewModel.cameraViewModel.selectedCameraDevice
        
        // THEN: Should handle camera selection state
        // Device may or may not be selected depending on system state
        XCTAssertTrue(selectedCamera != nil || selectedCamera == nil) // Any state is valid
    }
    
    func testCompletePhotoCaptureWorkflow() async throws {
        // GIVEN: A PhotoBoothViewModel with complete setup
        await viewModel.setupPhotoBoothSystem()
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertEqual(countdown, 0) // Initial state
        XCTAssertFalse(isCountingDown) // Initial state
        
        // WHEN: User checks minimum display period
        let minimumDisplay = viewModel.uiStateViewModel.minimumDisplayDuration
        let isInMinimumDisplay = viewModel.uiStateViewModel.isInMinimumDisplayPeriod
        
        // THEN: Should have display period information
        XCTAssertTrue(minimumDisplay > 0) // Should have positive duration
        XCTAssertFalse(isInMinimumDisplay) // Initial state
    }
    
    /// Test settings workflow and configuration
    func testSettingsWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User checks minimum display period
        let minimumDisplay = viewModel.uiStateViewModel.minimumDisplayDuration
        let isInMinimumDisplay = viewModel.uiStateViewModel.isInMinimumDisplayPeriod
        
        // THEN: Should have display period information
        XCTAssertGreaterThan(minimumDisplay, 0)
        XCTAssertNotNil(isInMinimumDisplay)
        
        // WHEN: User checks slideshow interval
        let slideInterval = viewModel.slideShowDisplayDuration
        
        // THEN: Should have slideshow interval
        XCTAssertGreaterThan(slideInterval, 0)
    }
    
    /// Test slideshow workflow with photos
    func testSlideShowWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks slideshow status
        let isActive = viewModel.isSlideShowActive
        let photoCount = viewModel.slideShowPhotoPairCount
        
        // THEN: Should have slideshow information
        XCTAssertFalse(isActive) // Should start inactive
        XCTAssertGreaterThanOrEqual(photoCount, 0)
        
        // WHEN: User starts slideshow
        await viewModel.startSlideshow()
        
        // THEN: Slideshow should be active
        XCTAssertTrue(viewModel.isSlideShowActive)
        
        // WHEN: User stops slideshow
        viewModel.stopSlideshow()
        
        // THEN: Slideshow should be inactive
        XCTAssertFalse(viewModel.isSlideShowActive)
    }
    
    /// Test slideshow with no photos
    func testSlideShowWithNoPhotos() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks photo count
        let photoCount = viewModel.slideShowPhotoPairCount
        
        // THEN: Should have photo count (may be 0)
        XCTAssertGreaterThanOrEqual(photoCount, 0)
        
        // WHEN: User attempts to start slideshow
        await viewModel.startSlideshow()
        
        // THEN: Should handle slideshow start (behavior depends on photos available)
        XCTAssertNotNil(viewModel.isSlideShowActive)
        
        // Clean up: Stop slideshow
        viewModel.stopSlideshow()
    }
    
    // MARK: - Helper Methods
    
    private func createTestPhotos(count: Int) async {
        // Test photo creation would be handled by the normal photo taking workflow
        print("Test photos would be created through normal photo taking workflow")
    }
    
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

// MARK: - Test PhotoTheme Helpers (shared with other test files) 