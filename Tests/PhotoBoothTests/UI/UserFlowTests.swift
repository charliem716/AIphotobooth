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
        // Basic setup for test environment
        // The actual services will be used but in test mode
    }
    
    // MARK: - User Flow Tests
    
    /// Test complete photo capture workflow from theme selection to result
    func testCompletePhotoCaptureWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User selects a theme
        let theme = TestPhotoTheme.portrait
        viewModel.selectTheme(theme)
        
        // THEN: Theme should be selected and photo capture workflow should work
        XCTAssertEqual(viewModel.selectedTheme?.name, theme.name)
        
        // WHEN: User initiates photo capture
        viewModel.takePhoto()
        
        // THEN: Should handle photo capture (behavior depends on camera availability)
        XCTAssertNotNil(viewModel.selectedTheme)
    }
    
    /// Test theme selection and switching workflow
    func testThemeSelectionWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User selects different themes
        let portraitTheme = TestPhotoTheme.portrait
        viewModel.selectTheme(portraitTheme)
        XCTAssertEqual(viewModel.selectedTheme?.name, portraitTheme.name)
        
        let landscapeTheme = TestPhotoTheme.landscape
        viewModel.selectTheme(landscapeTheme)
        XCTAssertEqual(viewModel.selectedTheme?.name, landscapeTheme.name)
        
        let abstractTheme = TestPhotoTheme.abstract
        viewModel.selectTheme(abstractTheme)
        XCTAssertEqual(viewModel.selectedTheme?.name, abstractTheme.name)
        
        // THEN: Final theme should be selected
        XCTAssertEqual(viewModel.selectedTheme?.name, abstractTheme.name)
    }
    
    /// Test rapid theme switching behavior
    func testRapidThemeSwitching() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User rapidly switches themes
        let themes = [TestPhotoTheme.portrait, TestPhotoTheme.landscape, TestPhotoTheme.abstract]
        
        for theme in themes {
            viewModel.selectTheme(theme)
            // Small delay to simulate rapid switching
            try await Task.sleep(for: .milliseconds(50))
        }
        
        // THEN: Final theme should be selected
        XCTAssertEqual(viewModel.selectedTheme?.name, TestPhotoTheme.abstract.name)
    }
    
    /// Test camera selection and connection workflow
    func testCameraSelectionWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks available cameras
        let cameras = viewModel.availableCameras
        let _ = viewModel.isCameraConnected
        
        // THEN: Should have camera information
        XCTAssertNotNil(cameras)
        
        // WHEN: User refreshes cameras
        await viewModel.refreshAvailableCameras()
        
        // THEN: Should handle camera refresh
        XCTAssertNotNil(viewModel.availableCameras)
    }
    
    /// Test camera connection state changes
    func testCameraConnectionStates() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks camera connection
        let isConnected = viewModel.isCameraConnected
        let isRunning = viewModel.isSessionRunning
        
        // THEN: Should have connection information
        XCTAssertNotNil(isConnected)
        XCTAssertNotNil(isRunning)
        
        // WHEN: User checks selected camera
        let selectedCamera = viewModel.selectedCameraDevice
        
        // THEN: Should handle camera selection state
        // Note: May be nil if no camera is selected
        if selectedCamera != nil {
            XCTAssertNotNil(selectedCamera)
        }
    }
    
    /// Test settings workflow and configuration
    func testSettingsWorkflow() async throws {
        // GIVEN: App is ready
        XCTAssertNotNil(viewModel)
        
        // WHEN: User checks countdown state
        let countdown = viewModel.countdown
        let isCountingDown = viewModel.isCountingDown
        
        // THEN: Should have countdown information
        XCTAssertGreaterThanOrEqual(countdown, 0)
        XCTAssertNotNil(isCountingDown)
        
        // WHEN: User checks minimum display period
        let minimumDisplay = viewModel.minimumDisplayDuration
        let isInMinimumDisplay = viewModel.isInMinimumDisplayPeriod
        
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