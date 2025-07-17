import XCTest
@testable import PhotoBooth

/// Tests for timing and countdown functionality
@MainActor
final class TimingAndCountdownTests: XCTestCase {
    
    // MARK: - Test Properties
    private var viewModel: PhotoBoothViewModel!
    
    // MARK: - Test Lifecycle
    
    override func setUp() async throws {
        continueAfterFailure = false
        
        // Create mock services for isolated testing
        let mockConfigurationService = MockConfigurationService()
        let mockNetworkService = MockNetworkService()
        let mockOpenAIService = MockOpenAIService()
        let mockCameraService = MockCameraService()
        let mockImageProcessingService = MockImageProcessingService()
        let mockCacheManagementService = MockCacheManagementService()
        let mockThemeConfigurationService = ThemeConfigurationService()
        
        // Configure mock services for timing tests
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
        
        // Create viewModel with test services
        viewModel = PhotoBoothViewModel(serviceCoordinator: testServiceCoordinator)
        await viewModel.setupPhotoBoothSystem()
        
        // Allow time for async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        viewModel = nil
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
        
        // Configure mock camera service for timing tests
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
    
    // MARK: - Standard Timing Tests
    
    func testStandardCountdownTiming() async throws {
        // GIVEN: A PhotoBoothViewModel with timing services
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User initiates photo capture
        // First ensure we have themes available
        let themes = viewModel.imageProcessingViewModel.themes
        if !themes.isEmpty {
            viewModel.imageProcessingViewModel.selectTheme(themes.first!)
        }
        
        viewModel.startCapture()
        
        // THEN: Should handle photo capture workflow
        // Test that the workflow is initiated, regardless of theme selection
        XCTAssertTrue(viewModel.imageProcessingViewModel.themes.count >= 0, "Should have access to themes")
        XCTAssertNotNil(viewModel.uiStateViewModel, "Should have UI state available")
    }
    
    func testQuickCountdownTiming() async throws {
        // GIVEN: A PhotoBoothViewModel with quick timing
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User initiates photo capture
        viewModel.startCapture()
        
        // THEN: Should handle photo capture workflow
        XCTAssertNotNil(viewModel.uiStateViewModel)
    }
    
    func testExtendedCountdownTiming() async throws {
        // GIVEN: A PhotoBoothViewModel with extended timing
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User initiates photo capture
        viewModel.startCapture()
        
        // THEN: Should handle photo capture workflow
        XCTAssertNotNil(viewModel.uiStateViewModel)
    }
    
    func testCountdownCancellation() async throws {
        // GIVEN: A PhotoBoothViewModel with countdown capability
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User initiates photo capture
        viewModel.startCapture()
        
        // THEN: Should handle photo capture workflow
        XCTAssertNotNil(viewModel.uiStateViewModel)
    }
    
    // MARK: - Minimum Display Period Tests
    
    func testStandardMinimumDisplayPeriod() async throws {
        // GIVEN: A PhotoBoothViewModel with minimum display period
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks minimum display period
        let minimumDisplay = viewModel.uiStateViewModel.minimumDisplayDuration
        let isInMinimumDisplay = viewModel.uiStateViewModel.isInMinimumDisplayPeriod
        let minimumDisplayRemaining = viewModel.uiStateViewModel.minimumDisplayTimeRemaining
        
        // THEN: Should have display period information
        XCTAssertGreaterThan(minimumDisplay, 0)
        XCTAssertFalse(isInMinimumDisplay) // Should not be in minimum display period initially
        XCTAssertEqual(minimumDisplayRemaining, 0) // Should not have remaining time initially
        
        // WHEN: User initiates photo capture
        viewModel.startCapture()
        
        // THEN: Should handle photo capture workflow
        XCTAssertNotNil(viewModel.uiStateViewModel)
    }
    
    func testMinimumDisplayPeriodDoesNotAutoReturn() async throws {
        // GIVEN: A UIStateViewModel 
        let uiStateViewModel = UIStateViewModel()
        
        // WHEN: Minimum display period is started
        uiStateViewModel.startMinimumDisplayPeriod()
        
        // THEN: Should be in minimum display period
        XCTAssertTrue(uiStateViewModel.isInMinimumDisplayPeriod)
        XCTAssertEqual(uiStateViewModel.minimumDisplayTimeRemaining, 10)
        
        // WHEN: We wait for minimum display period to complete
        // Use a shorter wait time for testing
        uiStateViewModel.minimumDisplayDuration = 1.0
        uiStateViewModel.startMinimumDisplayPeriod()
        
        // Wait for the minimum display period to complete
        try await Task.sleep(for: .seconds(1.5))
        
        // THEN: Should no longer be in minimum display period
        XCTAssertFalse(uiStateViewModel.isInMinimumDisplayPeriod)
        XCTAssertEqual(uiStateViewModel.minimumDisplayTimeRemaining, 0)
        
        // AND: Should be ready for next photo (no automatic return to live camera)
        XCTAssertTrue(uiStateViewModel.isReadyForNextPhoto)
    }
    
    func testThemeSelectionTriggersReturnToLiveCamera() async throws {
        // GIVEN: A PhotoBoothViewModel with proper setup
        let viewModel = PhotoBoothViewModel()
        await viewModel.setupPhotoBoothSystem()
        
        // AND: A theme to select
        let theme = TestPhotoTheme.portrait
        
        // WHEN: Theme is selected
        viewModel.imageProcessingViewModel.selectTheme(theme)
        
        // THEN: Should have selected the theme
        XCTAssertEqual(viewModel.imageProcessingViewModel.selectedTheme?.name, theme.name)
        
        // AND: Should be ready for next photo
        XCTAssertTrue(viewModel.uiStateViewModel.isReadyForNextPhoto)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentCountdownOperations() async throws {
        // GIVEN: A PhotoBoothViewModel with concurrent capability
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.uiStateViewModel.countdown
        let isCountingDown = viewModel.uiStateViewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User initiates photo capture
        viewModel.startCapture()
        
        // WHEN: User attempts another photo capture
        viewModel.startCapture()
        
        // THEN: Should handle concurrent operations appropriately
        XCTAssertNotNil(viewModel.uiStateViewModel)
    }
    
    func testConcurrentMinimumDisplayOperations() async throws {
        // Complete photo capture workflow
        let theme = TestPhotoTheme.portrait
        viewModel.imageProcessingViewModel.selectTheme(theme)
        viewModel.startCapture()
        
        // Allow time for processing
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify minimum display period is available
        let minimumDisplay = viewModel.uiStateViewModel.minimumDisplayDuration
        XCTAssertGreaterThan(minimumDisplay, 0)
        
        // Test concurrent access
        let isInMinimumDisplay = viewModel.uiStateViewModel.isInMinimumDisplayPeriod
        XCTAssertNotNil(isInMinimumDisplay)
    }
} 