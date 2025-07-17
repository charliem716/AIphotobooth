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
    
    // MARK: - Continuity Camera Comprehensive Tests
    
    @MainActor
    func testContinuityCameraDeviceTypes() {
        // Given
        mockCameraService.reset()
        
        // When - Add cameras of different types that should be detected
        let continuityCamera = mockCameraService.addMockCamera(name: "iPhone Camera", type: .continuityCamera)
        let externalCamera = mockCameraService.addMockCamera(name: "External Camera", type: .external)
        let builtInCamera = mockCameraService.addMockCamera(name: "Built-in Camera", type: .builtInWideAngleCamera)
        
        // Then - All device types should be available for continuity camera detection
        XCTAssertTrue(mockCameraService.availableCameras.contains(continuityCamera), "Should include continuity camera")
        XCTAssertTrue(mockCameraService.availableCameras.contains(externalCamera), "Should include external camera (required for continuity)")
        XCTAssertTrue(mockCameraService.availableCameras.contains(builtInCamera), "Should include built-in camera")
    }
    
    @MainActor
    func testCharliePhoneDetection() {
        // Given
        mockCameraService.reset()
        
        // When - Add Charlie's iPhone variations
        let charliePhone1 = mockCameraService.addMockCamera(name: "Charlie's iPhone", type: .continuityCamera)
        let charliePhone2 = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        let otherPhone = mockCameraService.addMockCamera(name: "Other iPhone", type: .continuityCamera)
        
        // Then - Charlie's phones should be available
        XCTAssertTrue(mockCameraService.availableCameras.contains(charliePhone1), "Should detect Charlie's iPhone")
        XCTAssertTrue(mockCameraService.availableCameras.contains(charliePhone2), "Should detect Charlie's 15 Pro")
        XCTAssertTrue(mockCameraService.availableCameras.contains(otherPhone), "Should detect other iPhones")
    }
    
    @MainActor
    func testContinuityCameraSelectionPriority() async {
        // Given
        mockCameraService.reset()
        
        // When - Add cameras in reverse priority order
        let builtInCamera = mockCameraService.addMockCamera(name: "Built-in Camera", type: .builtInWideAngleCamera)
        let externalCamera = mockCameraService.addMockCamera(name: "External Camera", type: .external)
        let continuityCamera = mockCameraService.addMockCamera(name: "Continuity Camera", type: .continuityCamera)
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        
        // Simulate camera selection process
        await mockCameraService.discoverCameras()
        
        // Then - All cameras should be available for priority selection
        XCTAssertTrue(mockCameraService.availableCameras.contains(charliePhone), "Should detect Charlie's phone")
        XCTAssertTrue(mockCameraService.availableCameras.contains(continuityCamera), "Should detect continuity camera")
        XCTAssertTrue(mockCameraService.availableCameras.contains(externalCamera), "Should detect external camera")
        XCTAssertTrue(mockCameraService.availableCameras.contains(builtInCamera), "Should detect built-in camera")
    }
    
    @MainActor
    func testContinuityCameraWorkflow() async {
        // Given
        mockCameraService.reset()
        
        // When - Full continuity camera workflow
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        
        await mockCameraService.requestCameraPermission()
        await mockCameraService.setupCamera() 
        await mockCameraService.discoverCameras()
        await mockCameraService.selectCamera(charliePhone)
        await mockCameraService.forceContinuityCameraConnection()
        await mockCameraService.startSession()
        
        // Then - Continuity camera workflow should complete successfully
        XCTAssertEqual(mockCameraService.authorizationStatus, .authorized, "Should have camera permission")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected to camera")
        XCTAssertEqual(mockCameraService.selectedCameraDevice, charliePhone, "Should select Charlie's phone")
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should have running session")
        XCTAssertGreaterThan(mockCameraService.availableCameras.count, 0, "Should have detected cameras")
    }
    
    @MainActor
    func testContinuityCameraReconnection() async {
        // Given
        mockCameraService.reset()
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's iPhone", type: .continuityCamera)
        
        // When - Simulate connection loss and reconnection
        await mockCameraService.selectCamera(charliePhone)
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be initially connected")
        
        // Simulate disconnection
        mockCameraService.isCameraConnected = false
        
        // Force reconnection
        await mockCameraService.forceContinuityCameraConnection()
        
        // Then - Should attempt to reconnect
        XCTAssertTrue(mockCameraService.availableCameras.contains(charliePhone), "Should maintain Charlie's phone in available cameras")
    }
    
    @MainActor
    func testDeprecatedExternalDeviceTypeSupport() {
        // Given
        mockCameraService.reset()
        
        // When - Add external device type (deprecated but required for continuity cameras)
        let externalContinuityCamera = mockCameraService.addMockCamera(name: "Continuity Camera (External)", type: .external)
        
        // Then - Should support deprecated .external type for continuity cameras
        XCTAssertTrue(mockCameraService.availableCameras.contains(externalContinuityCamera), "Should support deprecated .external type")
        XCTAssertGreaterThan(mockCameraService.availableCameras.count, 0, "Should have available cameras")
    }
    
    // MARK: - Enhanced Photo Capture Tests
    
    @MainActor
    func testPhotoCaptureSequence() async {
        // Given
        mockCameraService.reset()
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        
        // When - Complete photo capture sequence
        await mockCameraService.setupCamera()
        await mockCameraService.selectCamera(charliePhone)
        await mockCameraService.startSession()
        
        // Capture multiple photos
        mockCameraService.capturePhoto()
        mockCameraService.capturePhoto()
        mockCameraService.capturePhoto()
        
        // Then - Should handle multiple captures
        XCTAssertEqual(mockCameraService.captureCallCount, 3, "Should capture 3 photos")
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should maintain session")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should stay connected")
    }
    
    @MainActor
    func testPhotoCaptureWithLandscapeResolution() async {
        // Given - User prefers landscape resolution (1536x1024) for group photos
        mockCameraService.reset()
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        
        // When - Setup camera for landscape captures
        await mockCameraService.setupCamera()
        await mockCameraService.selectCamera(charliePhone)
        await mockCameraService.startSession()
        
        // Capture photo (mock doesn't test resolution but tests workflow)
        mockCameraService.capturePhoto()
        
        // Then - Should complete capture workflow for landscape photos
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should maintain connection for landscape photos")
        XCTAssertEqual(mockCameraService.captureCallCount, 1, "Should capture landscape photo")
    }
    
    @MainActor
    func testPhotoCaptureErrorRecovery() async {
        // Given
        mockCameraService.reset()
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's iPhone", type: .continuityCamera)
        
        // When - Setup camera then simulate capture error
        await mockCameraService.setupCamera()
        await mockCameraService.selectCamera(charliePhone)
        await mockCameraService.startSession()
        
        // Simulate capture error
        mockCameraService.configureForError(MockCameraError.mockCaptureError)
        mockCameraService.capturePhoto()
        
        // Then - Should handle error and allow recovery
        XCTAssertEqual(mockCameraService.captureCallCount, 1, "Should attempt capture")
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should maintain session despite error")
        
        // Reset error and retry
        mockCameraService.configureForSuccess()
        mockCameraService.capturePhoto()
        XCTAssertEqual(mockCameraService.captureCallCount, 2, "Should retry capture after error")
    }
    
    // MARK: - Camera Session Management Tests
    
    @MainActor
    func testCameraSessionLifecycle() async {
        // Given
        mockCameraService.reset()
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        
        // When - Complete session lifecycle
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should not be running initially")
        
        await mockCameraService.setupCamera()
        await mockCameraService.selectCamera(charliePhone)
        await mockCameraService.startSession()
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should be running after start")
        
        mockCameraService.stopSession()
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should not be running after stop")
        
        // Restart session
        await mockCameraService.startSession()
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should be running after restart")
    }
    
    @MainActor
    func testCameraSessionErrorHandling() async {
        // Given
        mockCameraService.reset()
        
        // When - Simulate session startup error
        mockCameraService.configureForError(MockCameraError.mockSessionError)
        await mockCameraService.startSession()
        
        // Then - Should handle session error gracefully
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should not be running with session error")
        
        // Recovery - Reset error and retry
        mockCameraService.configureForSuccess()
        await mockCameraService.startSession()
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should recover from session error")
    }
    
    // MARK: - Camera Permission Tests
    
    @MainActor
    func testCameraPermissionFlow() async {
        // Given
        mockCameraService.reset()
        mockCameraService.authorizationStatus = .notDetermined
        
        // When - Request permission
        await mockCameraService.requestCameraPermission()
        
        // Then - Should have requested permission
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should request permission")
        XCTAssertEqual(mockCameraService.authorizationStatus, .authorized, "Mock should grant permission")
    }
    
    @MainActor
    func testCameraPermissionDenied() async {
        // Given
        mockCameraService.reset()
        mockCameraService.configureForError(MockCameraError.mockPermissionError)
        
        // When - Request permission with error
        await mockCameraService.requestCameraPermission()
        
        // Then - Should handle denied permission
        XCTAssertEqual(mockCameraService.authorizationStatus, .denied, "Should be denied with error")
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should attempt permission request")
    }
    
    // MARK: - Camera Discovery Enhancement Tests
    
    @MainActor
    func testEnhancedCameraDiscovery() async {
        // Given
        mockCameraService.reset()
        
        // When - Add various camera types for discovery
        let _ = mockCameraService.addMockCamera(name: "Charlie's iPhone", type: .continuityCamera)
        let _ = mockCameraService.addMockCamera(name: "External Camera", type: .external)
        let _ = mockCameraService.addMockCamera(name: "Built-in Camera", type: .builtInWideAngleCamera)
        
        await mockCameraService.discoverCameras()
        
        // Then - Should discover all camera types
        XCTAssertGreaterThanOrEqual(mockCameraService.availableCameras.count, 3, "Should discover multiple camera types")
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should perform discovery")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected after discovery")
    }
    
    @MainActor
    func testCameraDiscoveryWithNoDevices() async {
        // Given
        mockCameraService.reset()
        mockCameraService.availableCameras = [] // Start with no cameras
        
        // When - Discover cameras with no devices
        await mockCameraService.discoverCameras()
        
        // Then - Should handle no cameras gracefully
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should attempt discovery")
        // Mock will add at least one camera during discovery
    }
    
    // MARK: - Performance and Timing Tests
    
    @MainActor
    func testContinuityCameraConnectionSpeed() async {
        // Given
        mockCameraService.reset()
        let charliePhone = mockCameraService.addMockCamera(name: "Charlie's 15 Pro Camera", type: .external)
        
        // When - Time the connection process
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await mockCameraService.setupCamera()
        await mockCameraService.selectCamera(charliePhone)
        await mockCameraService.forceContinuityCameraConnection()
        
        let connectionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Should connect within reasonable time
        XCTAssertLessThan(connectionTime, 2.0, "Continuity camera connection should be fast")
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected")
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testFullCameraWorkflowIntegration() async {
        // Given
        mockCameraService.reset()
        
        // When - Complete end-to-end workflow
        // 1. Request permissions
        await mockCameraService.requestCameraPermission()
        XCTAssertEqual(mockCameraService.authorizationStatus, .authorized, "Should have permission")
        
        // 2. Setup camera
        await mockCameraService.setupCamera()
        XCTAssertTrue(mockCameraService.isCameraConnected, "Should be connected")
        
        // 3. Discover cameras
        await mockCameraService.discoverCameras()
        XCTAssertGreaterThan(mockCameraService.availableCameras.count, 0, "Should discover cameras")
        
        // 4. Select Charlie's phone if available
        if let charliePhone = mockCameraService.availableCameras.first {
            await mockCameraService.selectCamera(charliePhone)
            XCTAssertEqual(mockCameraService.selectedCameraDevice, charliePhone, "Should select camera")
        }
        
        // 5. Force continuity camera connection
        await mockCameraService.forceContinuityCameraConnection()
        
        // 6. Start session
        await mockCameraService.startSession()
        XCTAssertTrue(mockCameraService.isSessionRunning, "Should be running")
        
        // 7. Capture photos
        for _ in 0..<3 {
            mockCameraService.capturePhoto()
        }
        XCTAssertEqual(mockCameraService.captureCallCount, 3, "Should capture all photos")
        
        // 8. Stop session
        mockCameraService.stopSession()
        XCTAssertFalse(mockCameraService.isSessionRunning, "Should stop running")
        
        // Then - All workflow steps should complete successfully
        XCTAssertEqual(mockCameraService.setupCallCount, 1, "Should setup once")
        XCTAssertEqual(mockCameraService.discoveryCallCount, 1, "Should discover once")
        XCTAssertEqual(mockCameraService.permissionCallCount, 1, "Should request permission once")
    }
} 