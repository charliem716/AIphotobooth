import SwiftUI
import AVFoundation
import Combine
import os.log

/// ViewModel responsible for camera operations and state management
@MainActor
final class CameraViewModel: ObservableObject, CameraCaptureDelegate {
    
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isCameraConnected = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraDevice: AVCaptureDevice?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var isCapturing = false
    
    // MARK: - Publishers for Events
    private let photoCapturedSubject = PassthroughSubject<NSImage, Never>()
    private let cameraErrorSubject = PassthroughSubject<CameraViewModelError, Never>()
    
    /// Publisher for successful photo captures
    var photoCapturedPublisher: AnyPublisher<NSImage, Never> {
        photoCapturedSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for camera errors
    var cameraErrorPublisher: AnyPublisher<CameraViewModelError, Never> {
        cameraErrorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private let cameraService: any CameraServiceProtocol
    private let logger = Logger(subsystem: "PhotoBooth", category: "CameraViewModel")
    private var cancellables = Set<AnyCancellable>()
    private var isRefreshingCameras = false
    
    // MARK: - Delegation (deprecated - use publishers instead)
    weak var delegate: CameraViewModelDelegate?
    
    // MARK: - Initialization
    init(cameraService: any CameraServiceProtocol) {
        self.cameraService = cameraService
        setupCameraService()
        bindCameraServiceProperties()
    }
    
    // Convenience initializer for main actor context
    @MainActor
    convenience init() {
        self.init(cameraService: CameraService())
    }
    
    // MARK: - Public Methods
    
    /// Initialize camera system
    func setupCamera() async {
        logger.info("Setting up camera system...")
        await cameraService.setupCamera()
        // Sync properties after camera setup
        syncPropertiesFromService()
    }
    
    /// Refresh available cameras
    func refreshAvailableCameras() async {
        guard !isRefreshingCameras else {
            logger.warning("⚠️ Camera refresh already in progress, skipping...")
            return
        }
        
        isRefreshingCameras = true
        logger.info("Refreshing available cameras...")
        
        do {
            await cameraService.discoverCameras()
            // Sync properties after camera discovery
            syncPropertiesFromService()
        } catch {
            logger.error("❌ Error refreshing cameras: \(error)")
        }
        
        isRefreshingCameras = false
    }
    
    /// Select a specific camera device
    func selectCamera(_ device: AVCaptureDevice) async {
        guard !isRefreshingCameras else {
            logger.warning("⚠️ Camera operation already in progress, skipping camera selection...")
            return
        }
        
        isRefreshingCameras = true
        logger.info("Selecting camera: \(device.localizedName)")
        
        do {
            await cameraService.selectCamera(device)
            // Sync properties after camera selection
            syncPropertiesFromService()
        } catch {
            logger.error("❌ Error selecting camera: \(error)")
        }
        
        isRefreshingCameras = false
    }
    
    /// Force continuity camera connection
    func forceContinuityCameraConnection() async {
        guard !isRefreshingCameras else {
            logger.warning("⚠️ Camera operation already in progress, skipping...")
            return
        }
        
        isRefreshingCameras = true
        logger.info("Forcing continuity camera connection...")
        
        do {
            await cameraService.forceContinuityCameraConnection()
            // Sync properties after continuity camera connection attempt
            syncPropertiesFromService()
        } catch {
            logger.error("❌ Error forcing continuity camera connection: \(error)")
        }
        
        isRefreshingCameras = false
    }
    

    
    /// Capture a photo
    func capturePhoto() {
        logger.info("🚀 CameraViewModel.capturePhoto() called")
        
        guard !isCapturing else {
            logger.warning("⚠️ Photo capture already in progress")
            return
        }
        
        guard isCameraConnected && isSessionRunning else {
            logger.error("❌ Camera not ready for capture - Connected: \(self.isCameraConnected), Running: \(self.isSessionRunning)")
            let error = CameraViewModelError.cameraNotReady
            cameraErrorSubject.send(error)
            delegate?.cameraViewModel(self, didFailWithError: error)
            return
        }
        
        logger.info("📸 Starting photo capture...")
        logger.debug("📸 Delegate set: \(self.delegate != nil)")
        isCapturing = true
        cameraService.capturePhoto()
    }
    
    /// Start camera session
    func startSession() async {
        logger.info("Starting camera session...")
        await cameraService.startSession()
    }
    
    /// Stop camera session
    func stopSession() {
        logger.info("Stopping camera session...")
        cameraService.stopSession()
    }
    
    /// Get camera preview layer
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return cameraService.getPreviewLayer()
    }
    
    /// Request camera permission
    func requestCameraPermission() async {
        logger.info("Requesting camera permission...")
        await cameraService.requestCameraPermission()
    }
    
    /// Check if ready for capture
    var isReadyForCapture: Bool {
        return isCameraConnected && 
               isSessionRunning && 
               !isCapturing &&
               authorizationStatus == .authorized
    }
    
    /// Get detailed camera status
    func getCameraStatusSummary() -> CameraStatusSummary {
        return CameraStatusSummary(
            authorizationStatus: authorizationStatus,
            isSessionRunning: isSessionRunning,
            isCameraConnected: isCameraConnected,
            availableCamerasCount: availableCameras.count,
            selectedCamera: selectedCameraDevice?.localizedName,
            isReadyForCapture: isReadyForCapture
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCameraService() {
        cameraService.captureDelegate = self
    }
    
    private func bindCameraServiceProperties() {
        // Bind camera service properties using proper actor-isolated observation
        logDebug("\(LoggingService.Emoji.connection) Setting up camera service property binding", category: .camera)
        
        // Note: Direct service observation simplified due to Swift 6 actor isolation
        // Manual synchronization will be used when needed
        logDebug("\(LoggingService.Emoji.debug) Camera service property binding configured", category: .camera)
        
        // Initial sync
        Task { @MainActor in
            self.syncPropertiesFromService()
        }
    }
    
    /// Manually sync properties from service (useful for initialization)
    private func syncPropertiesFromService() {
        self.isSessionRunning = self.cameraService.isSessionRunning
        self.isCameraConnected = self.cameraService.isCameraConnected
        self.availableCameras = self.cameraService.availableCameras
        self.selectedCameraDevice = self.cameraService.selectedCameraDevice
        self.authorizationStatus = self.cameraService.authorizationStatus
        
        logger.debug("Camera properties synced - Running: \(self.isSessionRunning), Connected: \(self.isCameraConnected), Cameras: \(self.availableCameras.count)")
    }
    
    private func logCameraDetails() {
        logger.debug("Camera Details:")
        for (index, camera) in availableCameras.enumerated() {
            let isConnected = camera.isConnected ? "✅ Connected" : "❌ Disconnected"
            let isSelected = camera == selectedCameraDevice ? " [SELECTED]" : ""
            logger.debug("  \(index + 1). \(camera.localizedName)\(isSelected)")
            logger.debug("     Type: \(camera.deviceType.rawValue)")
            logger.debug("     Status: \(isConnected)")
        }
    }
}

// MARK: - CameraCaptureDelegate
extension CameraViewModel {
    
    func cameraService(_ service: CameraService, didCapturePhoto image: NSImage) {
        logger.info("📸 CameraService didCapturePhoto callback - Photo captured successfully!")
        logger.debug("📸 Image size: \(image.size.width) x \(image.size.height)")
        
        isCapturing = false
        
        // Send through publisher (new approach)
        photoCapturedSubject.send(image)
        
        // Also call delegate for backward compatibility during transition
        delegate?.cameraViewModel(self, didCapturePhoto: image)
    }
    
    func cameraService(_ service: CameraService, didFailWithError error: CameraServiceError) {
        logger.error("❌ Camera capture failed: \(error.localizedDescription)")
        isCapturing = false
        
        // Convert to ViewModel error
        let viewModelError: CameraViewModelError
        switch error {
        case .cameraNotAuthorized:
            viewModelError = .cameraNotAuthorized
        case .cameraNotReady:
            viewModelError = .cameraNotReady
        case .photoOutputNotAvailable:
            viewModelError = .captureSetupFailed
        case .captureFailed(let underlyingError):
            viewModelError = .captureFailed(underlyingError)
        case .imageDataConversionFailed:
            viewModelError = .imageProcessingFailed
        case .sessionConfigurationFailed:
            viewModelError = .sessionConfigurationFailed
        }
        
        // Send through publisher (new approach)
        cameraErrorSubject.send(viewModelError)
        
        // Also call delegate for backward compatibility during transition
        delegate?.cameraViewModel(self, didFailWithError: viewModelError)
    }
}

// MARK: - Supporting Types

/// Delegate protocol for camera view model events
@MainActor
protocol CameraViewModelDelegate: AnyObject {
    func cameraViewModel(_ viewModel: CameraViewModel, didCapturePhoto image: NSImage)
    func cameraViewModel(_ viewModel: CameraViewModel, didFailWithError error: CameraViewModelError)
}

/// Camera view model specific errors
enum CameraViewModelError: LocalizedError {
    case cameraNotAuthorized
    case cameraNotReady
    case captureSetupFailed
    case captureFailed(Error)
    case imageProcessingFailed
    case sessionConfigurationFailed
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAuthorized:
            return "Camera access not authorized. Please enable camera access in System Preferences."
        case .cameraNotReady:
            return "Camera is not ready for capture. Please check camera connection."
        case .captureSetupFailed:
            return "Photo capture setup failed. Please restart the camera."
        case .captureFailed(let error):
            return "Photo capture failed: \(error.localizedDescription)"
        case .imageProcessingFailed:
            return "Failed to process captured photo."
        case .sessionConfigurationFailed:
            return "Failed to configure camera session."
        }
    }
}

/// Summary of camera status for UI display
struct CameraStatusSummary {
    let authorizationStatus: AVAuthorizationStatus
    let isSessionRunning: Bool
    let isCameraConnected: Bool
    let availableCamerasCount: Int
    let selectedCamera: String?
    let isReadyForCapture: Bool
    
    var statusText: String {
        if isReadyForCapture {
            return "Ready for capture"
        } else if authorizationStatus != .authorized {
            return "Camera permission required"
        } else if !isCameraConnected {
            return "No camera connected"
        } else if !isSessionRunning {
            return "Camera session stopped"
        } else {
            return "Camera initializing"
        }
    }
    
    var statusIcon: String {
        if isReadyForCapture {
            return "camera.fill"
        } else if authorizationStatus != .authorized {
            return "camera.circle.fill"
        } else if !isCameraConnected {
            return "camera.fill.badge.ellipsis"
        } else {
            return "camera"
        }
    }
}

// MARK: - Extensions

extension AVCaptureDevice.Position {
    var positionDescription: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .unspecified: return "Unspecified"
        @unknown default: return "Unknown"
        }
    }
} 