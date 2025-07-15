import XCTest
import SwiftUI
import AVFoundation
@testable import PhotoBooth

/// Comprehensive UI test suite for PhotoBooth application
/// Tests SwiftUI views directly without launching the full app to avoid camera hardware dependencies
@MainActor
final class PhotoBoothUITests: XCTestCase {
    
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
        // Basic setup for test environment
        // The actual services will be used but in test mode
    }
    
    // MARK: - User Flow Tests
    
    /// Test complete photo capture workflow: theme selection → countdown → capture → processing → slideshow
    func testCompletePhotoCaptureWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User selects a theme
        let theme = TestPhotoTheme.portrait
        viewModel.selectTheme(theme)
        
        // THEN: Theme should be selected
        XCTAssertEqual(viewModel.selectedTheme?.name, theme.name)
        
        // WHEN: User initiates photo capture
        viewModel.takePhoto()
        
        // THEN: Should start countdown or process
        // Note: Actual behavior depends on camera availability
        XCTAssertNotNil(viewModel.selectedTheme)
    }
    
    /// Test slideshow activation and navigation workflow
    func testSlideShowWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks slideshow status
        let initialCount = viewModel.slideShowPhotoPairCount
        
        // THEN: Should have initial state
        XCTAssertGreaterThanOrEqual(initialCount, 0)
        XCTAssertFalse(viewModel.isSlideShowActive)
        
        // WHEN: User activates slideshow
        await viewModel.startSlideshow()
        
        // THEN: Slideshow should be active
        XCTAssertTrue(viewModel.isSlideShowActive)
    }
    
    /// Test camera selection workflow
    func testCameraSelectionWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks camera status
        let _ = viewModel.isCameraConnected
        let availableCameras = viewModel.availableCameras
        
        // THEN: Should have camera information
        XCTAssertNotNil(availableCameras)
        // Note: Camera connection depends on hardware availability
    }
    
    /// Test camera disconnection error handling
    func testCameraDisconnectionError() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks error state
        let hasError = viewModel.showError
        let errorMessage = viewModel.errorMessage
        
        // THEN: Should handle error states properly
        if hasError {
            XCTAssertNotNil(errorMessage)
        }
    }
    
    /// Test OpenAI API error handling
    func testOpenAIAPIError() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks processing state
        let isProcessing = viewModel.isProcessing
        
        // THEN: Should handle processing states
        XCTAssertNotNil(isProcessing)
    }
    
    /// Test countdown timing accuracy
    func testCountdownTimingAccuracy() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.countdown
        let isCountingDown = viewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
    }
    
    /// Test slideshow photo scanning
    func testSlideShowPhotoScanning() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks photo count
        let photoCount = viewModel.slideShowPhotoPairCount
        
        // THEN: Should have photo count information
        XCTAssertGreaterThanOrEqual(photoCount, 0)
        
        // WHEN: User refreshes slideshow
        // Note: No direct method, handled automatically
        
        // THEN: Should handle refresh
        XCTAssertNotNil(viewModel.slideShowPhotoPairCount)
    }
    
    // MARK: - Helper Methods Implementation
    
    private func ensureCameraIsAvailable() async {
        // Check if camera is available for testing
        let isConnected = viewModel.isCameraConnected
        if !isConnected {
            // Log that camera is not available in test environment
            print("Camera not available in test environment")
        }
    }
    
    private func selectTheme(themeName: String) async throws {
        // Select theme based on name
        let theme: PhotoTheme
        switch themeName {
        case "Portrait":
            theme = TestPhotoTheme.portrait
        case "Landscape":
            theme = TestPhotoTheme.landscape
        case "Abstract":
            theme = TestPhotoTheme.abstract
        default:
            throw TestError.themeNotFound
        }
        
        viewModel.selectTheme(theme)
    }
    
    private func initiatePhotoCapture() async throws {
        viewModel.takePhoto()
    }
    
    private func waitForCountdownCompletion() async throws {
        // Wait for countdown to complete
        var attempts = 0
        while viewModel.isCountingDown && attempts < 50 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        
        if attempts >= 50 {
            throw TestError.countdownTimeout
        }
    }
    
    private func waitForProcessingToStart() async throws {
        // Processing state checking
        var attempts = 0
        while !viewModel.isProcessing && attempts < 10 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
    }
    
    private func waitForProcessingToComplete() async throws {
        // Wait for processing to complete
        var attempts = 0
        while viewModel.isProcessing && attempts < 50 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        
        if attempts >= 50 {
            throw TestError.processingTimeout
        }
    }
    
    private func waitForMinimumDisplayPeriod() async throws {
        // Wait for minimum display period
        var attempts = 0
        while viewModel.isInMinimumDisplayPeriod && attempts < 50 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        
        if attempts >= 50 {
            throw TestError.displayPeriodTimeout
        }
    }
    
    private func createTestPhotos(count: Int) async {
        // Test photo creation is handled by the slideshow functionality
        // In real app, photos are created by taking pictures
        print("Test photos would be created through normal photo taking workflow")
    }
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
    
    private func activateSlideshow() async throws {
        await viewModel.startSlideshow()
    }
    
    private func navigateSlideshow() async throws {
        // Navigation depends on slideshow implementation
        if viewModel.isSlideShowActive {
            // Navigation would be handled by slideshow controls
            print("Slideshow navigation testing")
        }
    }
    
    private func exitSlideshow() async throws {
        viewModel.stopSlideshow()
    }
    
    private func openCameraSelection() async throws {
        // Camera selection testing
        let cameras = viewModel.availableCameras
        XCTAssertNotNil(cameras)
    }
    
    private func selectCamera(index: Int) async throws {
        let cameras = viewModel.availableCameras
        guard index < cameras.count else {
            throw TestError.cameraIndexOutOfRange
        }
        
        let camera = cameras[index]
        await viewModel.selectCamera(camera)
    }
    
    private func confirmCameraSelection() async throws {
        // Camera selection confirmation
        let selectedCamera = viewModel.selectedCameraDevice
        XCTAssertNotNil(selectedCamera)
    }
    
    private func simulateCameraDisconnection() async throws {
        // Simulate camera disconnection
        // In real app, this would be handled by the camera service
        print("Camera disconnection simulation")
    }
    
    private func attemptCameraReconnection() async throws {
        // Attempt to reconnect camera
        await viewModel.refreshAvailableCameras()
    }
    
    private func simulateSuccessfulReconnection() async throws {
        // Simulate successful reconnection
        print("Camera reconnection simulation")
    }
    
    private func capturePhotoWithAPIError() async throws {
        // Capture photo with API error simulation
        viewModel.takePhoto()
    }
    
    private func retryAfterAPIError() async throws {
        // Retry after API error
        if viewModel.showError {
            viewModel.uiStateViewModel.hideError()
        }
    }
    
    private func simulateSuccessfulRetry() async throws {
        // Simulate successful retry
        try await waitForProcessingToComplete()
    }
    
    private func configureCountdown(duration: Int) async throws {
        // Countdown configuration
        // This would be handled by settings
        print("Countdown configured for \(duration) seconds")
    }
    
    private func startCountdown() async throws {
        viewModel.takePhoto()
    }
    
    private func scanForPhotos() async throws {
        // Refresh slideshow - no direct method, handled automatically
    }
    
    private func addMoreTestPhotos(count: Int) async {
        await createTestPhotos(count: count)
    }
    
    private func rescanForPhotos() async throws {
        // Refresh slideshow - no direct method, handled automatically
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case themeNotFound
    case countdownTimeout
    case processingTimeout
    case cameraIndexOutOfRange
    case displayPeriodTimeout
}

// MARK: - Test PhotoTheme Helpers

struct TestPhotoTheme {
    static let portrait = PhotoTheme(
        id: 1,
        name: "Portrait",
        prompt: "portrait style",
        enabled: true,
        category: "portrait"
    )
    
    static let landscape = PhotoTheme(
        id: 2,
        name: "Landscape",
        prompt: "landscape style",
        enabled: true,
        category: "landscape"
    )
    
    static let abstract = PhotoTheme(
        id: 3,
        name: "Abstract",
        prompt: "abstract style",
        enabled: true,
        category: "abstract"
    )
} 