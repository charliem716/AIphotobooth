import Foundation
import AppKit
import AVFoundation
import Combine
@testable import PhotoBooth

/// Mock Camera Service for testing
@MainActor
final class MockCameraService: ObservableObject, CameraServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isCameraConnected = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraDevice: AVCaptureDevice?
    @Published var authorizationStatus: AVAuthorizationStatus = .authorized
    
    // MARK: - Delegation
    weak var captureDelegate: (any CameraCaptureDelegate)?
    
    // MARK: - Mock Configuration
    var shouldThrowError = false
    var shouldSimulateDelay = false
    var delayDuration: TimeInterval = 0.5
    var mockError: Error = MockCameraError.mockCaptureError
    var setupCallCount = 0
    var captureCallCount = 0
    var permissionCallCount = 0
    var discoveryCallCount = 0
    var mockPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Mock Camera Devices
    private var mockCameras: [AVCaptureDevice] = []
    
    // MARK: - Initialization
    init() {
        setupMockCameras()
    }
    
    // MARK: - CameraServiceProtocol
    
    func setupCamera() async {
        setupCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            // Note: Can't pass MockCameraService to CameraCaptureDelegate protocol method
            // In real implementation, would need proper protocol design
            return
        }
        
        // Simulate successful camera setup
        isCameraConnected = true
        // Ensure we have a device for testing - use system default or nil (to be handled by tests)
        selectedCameraDevice = mockCameras.first ?? AVCaptureDevice.default(for: .video)
        authorizationStatus = .authorized
    }
    
    func requestCameraPermission() async {
        permissionCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            authorizationStatus = .denied
        } else {
            authorizationStatus = .authorized
        }
    }
    
    func discoverCameras() async {
        discoveryCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if !shouldThrowError {
            availableCameras = mockCameras
            if !mockCameras.isEmpty {
                selectedCameraDevice = mockCameras.first
                isCameraConnected = true
            }
        } else {
            // On error, don't discover any cameras
            availableCameras = []
            selectedCameraDevice = nil
            isCameraConnected = false
        }
    }
    
    func selectCamera(_ device: AVCaptureDevice) async {
        selectedCameraDevice = device
        isCameraConnected = true
    }
    
    func capturePhoto() {
        captureCallCount += 1
        
        if shouldThrowError {
            // Note: Can't pass MockCameraService to CameraCaptureDelegate protocol method
            // In real implementation, would need proper protocol design
            return
        }
        
        // Simulate successful photo capture
        _ = createMockCapturedImage()
        // Note: Can't pass MockCameraService to CameraCaptureDelegate protocol method
    }
    
    func startSession() async {
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if !shouldThrowError {
            isSessionRunning = true
        }
    }
    
    func stopSession() {
        isSessionRunning = false
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return mockPreviewLayer
    }
    
    func forceContinuityCameraConnection() async {
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        // Add a mock continuity camera to available cameras
        if !shouldThrowError {
            if let mockContinuityCamera = MockCaptureDevice.createMockDevice(
                uniqueID: "continuity-camera-mock",
                localizedName: "Charlie's iPhone",
                deviceType: .continuityCamera,
                position: .front
            ) {
                mockCameras.append(mockContinuityCamera)
                availableCameras = mockCameras
            }
        }
    }
    
    // MARK: - Mock Helpers
    
    func reset() {
        shouldThrowError = false
        shouldSimulateDelay = false
        delayDuration = 0.5
        mockError = MockCameraError.mockCaptureError
        setupCallCount = 0
        captureCallCount = 0
        permissionCallCount = 0
        discoveryCallCount = 0
        isSessionRunning = false
        isCameraConnected = false
        selectedCameraDevice = nil
        authorizationStatus = .authorized
        setupMockCameras()
        mockPreviewLayer = nil
    }
    
    func configureForError(_ error: Error) {
        shouldThrowError = true
        mockError = error
    }
    
    func configureForDelay(_ duration: TimeInterval) {
        shouldSimulateDelay = true
        delayDuration = duration
    }
    
    func addMockCamera(name: String, type: AVCaptureDevice.DeviceType = .builtInWideAngleCamera) {
        if let mockCamera = MockCaptureDevice.createMockDevice(
            uniqueID: "mock-\(name.lowercased())",
            localizedName: name,
            deviceType: type,
            position: .back
        ) {
            mockCameras.append(mockCamera)
            availableCameras = mockCameras
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMockCameras() {
        mockCameras = []
        
        // Always create at least one mock camera for testing
        // First, try to get a real system camera if available
        if let systemCamera = AVCaptureDevice.default(for: .video) {
            mockCameras.append(systemCamera)
        }
        
        // For testing reliability, always add a mock camera representation
        // This ensures tests work regardless of hardware availability
        if mockCameras.isEmpty {
            // Create mock cameras using system discovery as fallback
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            
            if let firstDevice = discoverySession.devices.first {
                mockCameras.append(firstDevice)
            } else {
                // If absolutely no cameras available, create a minimal test representation
                // This will be handled gracefully in tests
                print("⚠️ No cameras available for testing - tests will use fallback behavior")
            }
        }
        
        availableCameras = mockCameras
    }
    
    private func createMockCapturedImage() -> NSImage {
        let size = NSSize(width: 1536, height: 1024)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Create a gradient background
        let gradient = NSGradient(colors: [NSColor.systemBlue, NSColor.systemGreen])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        // Add "MOCK PHOTO" text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -2
        ]
        
        let text = "MOCK PHOTO"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        // Add timestamp
        let timestamp = Date().formatted()
        let timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.white
        ]
        
        let timestampSize = timestamp.size(withAttributes: timestampAttributes)
        let timestampRect = NSRect(
            x: size.width - timestampSize.width - 20,
            y: 20,
            width: timestampSize.width,
            height: timestampSize.height
        )
        
        timestamp.draw(in: timestampRect, withAttributes: timestampAttributes)
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Mock Capture Device

class MockCaptureDevice: AVCaptureDevice {
    private let mockUniqueID: String
    private let mockLocalizedName: String
    private let mockDeviceType: AVCaptureDevice.DeviceType
    private let mockPosition: AVCaptureDevice.Position
    
    // Note: AVCaptureDevice mocking is complex due to AV_INIT_UNAVAILABLE
    // In a real test environment, we would use actual devices or a different approach
    static func createMockDevice(uniqueID: String, localizedName: String, deviceType: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // This would return a properly configured mock device
        // For now, return a system default device or nil
        return AVCaptureDevice.default(for: .video)
    }
}

// MARK: - Mock Errors

enum MockCameraError: Error, LocalizedError {
    case mockCaptureError
    case mockPermissionError
    case mockSetupError
    case mockSessionError
    
    var errorDescription: String? {
        switch self {
        case .mockCaptureError:
            return "Mock camera capture error"
        case .mockPermissionError:
            return "Mock camera permission error"
        case .mockSetupError:
            return "Mock camera setup error"
        case .mockSessionError:
            return "Mock camera session error"
        }
    }
} 