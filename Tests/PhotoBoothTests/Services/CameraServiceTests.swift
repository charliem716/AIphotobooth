import XCTest
import AVFoundation
@testable import PhotoBooth

final class CameraServiceTests: XCTestCase {
    
    var mockCameraService: MockCameraService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
    }
    
    override func tearDown() {
        mockCameraService = nil
        super.tearDown()
    }
    
    // MARK: - Basic Tests
    
    @MainActor
    func testInitialization() {
        // Given & When
        let service = MockCameraService()
        
        // Then
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isSessionRunning, "Should not be running initially")
        XCTAssertFalse(service.isCameraConnected, "Should not be connected initially")
        XCTAssertEqual(service.authorizationStatus, .authorized, "Mock should be authorized by default")
    }
    
    @MainActor
    func testSetupCamera() async {
        // Given
        mockCameraService.reset()
        
        // When
        await mockCameraService.setupCamera()
        
        // Then
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected after setup")
        XCTAssertNotNil(mockCameraService.selectedCameraDevice, "Should have selected camera device")
        XCTAssertEqual(mockCameraService.setupCallCount, 1, "Should increment setup call count")
    }
    
    @MainActor
    func testSetupCameraWithError() async {
        // Given
        mockCameraService.configureForError(MockCameraError.mockSetupError)
        
        // When
        await mockCameraService.setupCamera()
        
        // Then
        XCTAssertFalse(mockCameraService.isCameraConnected, "Should not be connected with error")
        XCTAssertEqual(mockCameraService.setupCallCount, 1, "Should still increment setup call count")
    }
    
    @MainActor
    func testRequestCameraPermission() async {
        // Given
        mockCameraService.reset()
        
        // When
        await mockCameraService.requestCameraPermission()
        
        // Then
        XCTAssertEqual(mockCameraService.authorizationStatus, .authorized, "Should be authorized after permission request")
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should increment permission call count")
    }
    
    @MainActor
    func testRequestCameraPermissionWithError() async {
        // Given
        mockCameraService.configureForError(MockCameraError.mockPermissionError)
        
        // When
        await mockCameraService.requestCameraPermission()
        
        // Then
        XCTAssertEqual(mockCameraService.authorizationStatus, .denied, "Should be denied with error")
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should still increment permission call count")
    }
    
    @MainActor
    func testDiscoverCameras() async {
        // Given
        mockCameraService.reset()
        
        // When
        await mockCameraService.discoverCameras()
        
        // Then
        XCTAssertGreaterThan(mockCameraService.availableCameras.count, 0, "Should discover cameras")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected after discovery")
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should increment discovery call count")
    }
    
    @MainActor
    func testDiscoverCamerasWithError() async {
        // Given
        mockCameraService.configureForError(MockCameraError.mockSetupError)
        
        // When
        await mockCameraService.discoverCameras()
        
        // Then
        XCTAssertEqual(mockCameraService.availableCameras.count, 0, "Should not discover cameras with error")
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should still increment discovery call count")
    }
    
    @MainActor
    func testSelectCamera() async {
        // Given
        mockCameraService.reset()
        await mockCameraService.discoverCameras()
        
        // Add a mock camera if none discovered
        if mockCameraService.availableCameras.isEmpty {
            mockCameraService.addMockCamera(name: "Test Camera")
        }
        
        // Only test if we have cameras available
        if let firstCamera = mockCameraService.availableCameras.first {
            // When
            await mockCameraService.selectCamera(firstCamera)
            
            // Then
            XCTAssertEqual(mockCameraService.selectedCameraDevice, firstCamera, "Should select the specified camera")
            XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected after selection")
        } else {
            // If no cameras available, test that the service handles it gracefully
            XCTAssertEqual(mockCameraService.availableCameras.count, 0, "Should have no cameras available")
            XCTAssertFalse(mockCameraService.isCameraConnected, "Should not be connected without cameras")
        }
    }
    
    @MainActor
    func testCapturePhoto() {
        // Given
        mockCameraService.reset()
        
        // When
        mockCameraService.capturePhoto()
        
        // Then
        XCTAssertEqual(mockCameraService.captureCallCount, 1, "Should increment capture call count")
        // Note: Cannot test delegate callback due to type mismatch
    }
    
    @MainActor
    func testCapturePhotoWithError() {
        // Given
        mockCameraService.configureForError(MockCameraError.mockCaptureError)
        
        // When
        mockCameraService.capturePhoto()
        
        // Then
        XCTAssertEqual(mockCameraService.captureCallCount, 1, "Should still increment capture call count")
        // Note: Cannot test delegate callback due to type mismatch
    }
    
    @MainActor
    func testStartSession() async {
        // Given
        mockCameraService.reset()
        
        // When
        await mockCameraService.startSession()
        
        // Then
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should be running after start")
    }
    
    @MainActor
    func testStartSessionWithError() async {
        // Given
        mockCameraService.configureForError(MockCameraError.mockSessionError)
        
        // When
        await mockCameraService.startSession()
        
        // Then
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should not be running with error")
    }
    
    @MainActor
    func testStopSession() {
        // Given
        mockCameraService.reset()
        mockCameraService.isSessionRunning = true
        
        // When
        mockCameraService.stopSession()
        
        // Then
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should not be running after stop")
    }
    
    @MainActor
    func testGetPreviewLayer() {
        // Given & When
        let previewLayer = mockCameraService.getPreviewLayer()
        
        // Then
        // Note: Mock implementation returns nil by default
        XCTAssertNil(previewLayer, "Mock should return nil preview layer")
    }
    
    @MainActor
    func testForceContinuityCameraConnection() async {
        // Given
        mockCameraService.reset()
        let initialCameraCount = mockCameraService.availableCameras.count
        
        // When
        await mockCameraService.forceContinuityCameraConnection()
        
        // Then - Should maintain camera count (mock behavior)
        XCTAssertGreaterThanOrEqual(mockCameraService.availableCameras.count, initialCameraCount, "Should maintain or add cameras")
    }
    
    @MainActor
    func testForceContinuityCameraConnectionWithError() async {
        // Given
        mockCameraService.reset()
        mockCameraService.configureForError(MockCameraError.mockSetupError)
        let initialCameraCount = mockCameraService.availableCameras.count
        
        // When
        await mockCameraService.forceContinuityCameraConnection()
        
        // Then - Should not add camera with error (mock behavior)
        XCTAssertEqual(mockCameraService.availableCameras.count, initialCameraCount, "Should not add camera with error")
    }
    
    // MARK: - Multiple Operations Tests
    
    @MainActor
    func testMultiplePhotoCaptures() {
        // Given
        mockCameraService.reset()
        let captureCount = 5
        
        // When
        for _ in 0..<captureCount {
            mockCameraService.capturePhoto()
        }
        
        // Then
        XCTAssertEqual(mockCameraService.captureCallCount, captureCount, "Should track all capture calls")
    }
    
    @MainActor
    func testCameraWorkflow() async {
        // Given
        mockCameraService.reset()
        
        // When - Full camera workflow
        await mockCameraService.requestCameraPermission()
        await mockCameraService.setupCamera()
        await mockCameraService.discoverCameras()
        await mockCameraService.startSession()
        mockCameraService.capturePhoto()
        
        // Then - Test the method call counts (these always work in mock)
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should request permission")
        XCTAssertEqual(mockCameraService.setupCallCount, 1, "Should setup camera")
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should discover cameras")
        XCTAssertEqual(mockCameraService.captureCallCount, 1, "Should capture photo")
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should be running")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected")
    }
    
    // MARK: - Delay Tests
    
    @MainActor
    func testOperationsWithDelay() async {
        // Given
        mockCameraService.configureForDelay(0.1)
        
        // When
        let start = Date()
        await mockCameraService.setupCamera()
        let end = Date()
        
        // Then
        XCTAssertGreaterThan(end.timeIntervalSince(start), 0.05, "Should have simulated delay")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should still complete operation")
    }
    
    // MARK: - Reset Tests
    
    @MainActor
    func testReset() {
        // Given
        mockCameraService.configureForError(MockCameraError.mockCaptureError)
        mockCameraService.configureForDelay(1.0)
        mockCameraService.isSessionRunning = true
        mockCameraService.isCameraConnected = true
        
        // When
        mockCameraService.reset()
        
        // Then
        XCTAssertFalse(mockCameraService.shouldThrowError, "Should not throw error after reset")
        XCTAssertFalse(mockCameraService.shouldSimulateDelay, "Should not simulate delay after reset")
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should not be running after reset")
        XCTAssertFalse(mockCameraService.isCameraConnected, "Should not be connected after reset")
        XCTAssertEqual(mockCameraService.setupCallCount, 0, "Should reset setup call count")
        XCTAssertEqual(mockCameraService.captureCallCount, 0, "Should reset capture call count")
        XCTAssertEqual(mockCameraService.permissionCallCount, 0, "Should reset permission call count")
        XCTAssertEqual(mockCameraService.discoveryCallCount, 0, "Should reset discovery call count")
        XCTAssertEqual(mockCameraService.authorizationStatus, .authorized, "Should reset to authorized")
    }
    
    // MARK: - Camera Management Tests
    
    @MainActor
    func testAddMockCamera() {
        // Given
        mockCameraService.reset()
        let initialCount = mockCameraService.availableCameras.count
        
        // When
        mockCameraService.addMockCamera(name: "Test Camera", type: .builtInWideAngleCamera)
        
        // Then
        XCTAssertEqual(mockCameraService.availableCameras.count, initialCount + 1, "Should add mock camera")
    }
    
    @MainActor
    func testMultipleCameraTypes() {
        // Given
        mockCameraService.reset()
        let cameraTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .continuityCamera,
            .external
        ]
        
        // When
        for (index, type) in cameraTypes.enumerated() {
            mockCameraService.addMockCamera(name: "Camera \(index)", type: type)
        }
        
        // Then
        XCTAssertGreaterThanOrEqual(mockCameraService.availableCameras.count, cameraTypes.count, "Should add all camera types")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testCameraSetupPerformance() async {
        // Given
        mockCameraService.reset()
        mockCameraService.configureForDelay(0.01)
        
        // When & Then - Test performance without async in measure block
        let iterations = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            mockCameraService.reset()
            mockCameraService.configureForDelay(0.01)
            await mockCameraService.setupCamera()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        // Assert reasonable performance (should be under 1 second per operation)
        XCTAssertLessThan(averageTime, 1.0, "Average setup time should be under 1 second")
        
        // Log performance for debugging
        print("🔍 Performance: \(averageTime) seconds average per camera setup")
    }
    
    // MARK: - Concurrent Operations Tests
    
    @MainActor
    func testConcurrentCameraOperations() async {
        // Given
        mockCameraService.reset()
        
        // When
        await withTaskGroup(of: Void.self) { group in
            // Test concurrent discovery and setup
            group.addTask {
                await self.mockCameraService.discoverCameras()
            }
            
            group.addTask {
                await self.mockCameraService.setupCamera()
            }
            
            group.addTask {
                await self.mockCameraService.requestCameraPermission()
            }
            
            await group.waitForAll()
        }
        
        // Then
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should handle concurrent discovery")
        XCTAssertEqual(mockCameraService.setupCallCount, 1, "Should handle concurrent setup")
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should handle concurrent permission")
    }
} 