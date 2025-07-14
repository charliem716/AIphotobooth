import Foundation
import AVFoundation
import AppKit
import os.log

/// Service responsible for camera management and photo capture operations
@MainActor
final class CameraService: NSObject, ObservableObject, CameraServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isCameraConnected = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraDevice: AVCaptureDevice?
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let logger = Logger(subsystem: "PhotoBooth", category: "Camera")
    
    // MARK: - Delegation
    weak var captureDelegate: CameraCaptureDelegate?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupInitialState()
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Public Methods
    
    /// Initialize and start the camera session
    func setupCamera() async {
        logger.info("Setting up camera service...")
        
        await requestCameraPermission()
        
        guard authorizationStatus == .authorized else {
            logger.warning("Camera access not authorized")
            return
        }
        
        await setupCaptureSession()
        await discoverCameras()
        await startSession()
    }
    
    /// Request camera permission from the user
    func requestCameraPermission() async {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authorizationStatus {
        case .authorized:
            logger.info("Camera access already authorized")
            return
            
        case .notDetermined:
            logger.info("Requesting camera access...")
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            
            if granted {
                logger.info("Camera access granted")
            } else {
                logger.warning("Camera access denied by user")
            }
            
        case .denied, .restricted:
            logger.warning("Camera access denied or restricted")
            
        @unknown default:
            logger.error("Unknown camera permission status")
        }
    }
    
    /// Discover available cameras, prioritizing Continuity Camera
    func discoverCameras() async {
        logger.info("Discovering available cameras...")
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .continuityCamera,
                .builtInWideAngleCamera,
                .external
            ],
            mediaType: .video,
            position: .unspecified
        )
        
        availableCameras = discoverySession.devices
        logger.info("Found \(availableCameras.count) cameras")
        
        // Log available cameras for debugging
        for camera in availableCameras {
            logger.debug("Camera: \(camera.localizedName) (Type: \(camera.deviceType.rawValue))")
        }
        
        // Auto-select Continuity Camera if available
        if let continuityCam = availableCameras.first(where: { $0.deviceType == .continuityCamera }) {
            await selectCamera(continuityCam)
            logger.info("Auto-selected Continuity Camera: \(continuityCam.localizedName)")
        } else if let firstCamera = availableCameras.first {
            await selectCamera(firstCamera)
            logger.info("Auto-selected first available camera: \(firstCamera.localizedName)")
        }
    }
    
    /// Select a specific camera device
    func selectCamera(_ device: AVCaptureDevice) async {
        guard availableCameras.contains(device) else {
            logger.error("Attempted to select unavailable camera: \(device.localizedName)")
            return
        }
        
        selectedCameraDevice = device
        logger.info("Selected camera: \(device.localizedName)")
        
        if isSessionRunning {
            await reconfigureSessionForSelectedCamera()
        }
    }
    
    /// Capture a photo using the current camera
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            logger.error("Photo output not available")
            captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.photoOutputNotAvailable)
            return
        }
        
        guard isCameraConnected && isSessionRunning else {
            logger.error("Camera not ready for capture")
            captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.cameraNotReady)
            return
        }
        
        logger.info("Capturing photo...")
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /// Start the camera session
    func startSession() async {
        guard let captureSession = captureSession else {
            logger.error("Capture session not available")
            return
        }
        
        guard !captureSession.isRunning else {
            logger.debug("Capture session already running")
            return
        }
        
        logger.info("Starting camera session...")
        captureSession.startRunning()
        isSessionRunning = captureSession.isRunning
        
        if isSessionRunning {
            logger.info("Camera session started successfully")
        } else {
            logger.error("Failed to start camera session")
        }
    }
    
    /// Stop the camera session
    func stopSession() {
        guard let captureSession = captureSession else { return }
        
        logger.info("Stopping camera session...")
        captureSession.stopRunning()
        isSessionRunning = false
        isCameraConnected = false
    }
    
    /// Get the preview layer for camera display
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func setupCaptureSession() async {
        logger.info("Setting up capture session...")
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        // Setup photo output
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput,
           let captureSession = captureSession,
           captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            logger.debug("Photo output added to session")
        }
        
        // Setup preview layer
        if let captureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            logger.debug("Preview layer created")
        }
    }
    
    private func reconfigureSessionForSelectedCamera() async {
        guard let captureSession = captureSession,
              let selectedDevice = selectedCameraDevice else {
            logger.error("Cannot reconfigure session - missing session or device")
            return
        }
        
        logger.info("Reconfiguring session for camera: \(selectedDevice.localizedName)")
        
        captureSession.beginConfiguration()
        
        // Remove existing video input
        let currentInputs = captureSession.inputs
        for input in currentInputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.video) {
                captureSession.removeInput(deviceInput)
                logger.debug("Removed existing video input")
            }
        }
        
        // Add new video input
        do {
            let deviceInput = try AVCaptureDeviceInput(device: selectedDevice)
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
                isCameraConnected = true
                logger.info("Added new video input: \(selectedDevice.localizedName)")
            } else {
                logger.error("Cannot add device input to session")
                isCameraConnected = false
            }
        } catch {
            logger.error("Failed to create device input: \(error.localizedDescription)")
            isCameraConnected = false
        }
        
        captureSession.commitConfiguration()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                logger.error("Photo capture error: \(error.localizedDescription)")
                captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.captureFailed(error))
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = NSImage(data: data) else {
            Task { @MainActor in
                logger.error("Could not get image data from photo")
                captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.imageDataConversionFailed)
            }
            return
        }
        
        Task { @MainActor in
            logger.info("Photo captured successfully, size: \(data.count) bytes")
            captureDelegate?.cameraService(self, didCapturePhoto: image)
        }
    }
}

// MARK: - Supporting Types

/// Delegate protocol for camera capture events
protocol CameraCaptureDelegate: AnyObject {
    func cameraService(_ service: CameraService, didCapturePhoto image: NSImage)
    func cameraService(_ service: CameraService, didFailWithError error: CameraServiceError)
}

/// Errors that can occur during camera operations
enum CameraServiceError: LocalizedError {
    case cameraNotAuthorized
    case cameraNotReady
    case photoOutputNotAvailable
    case captureFailed(Error)
    case imageDataConversionFailed
    case sessionConfigurationFailed
    
    var errorDescription: String? {
        switch self {
        case .cameraNotAuthorized:
            return "Camera access not authorized. Please enable camera access in System Preferences."
        case .cameraNotReady:
            return "Camera is not ready for capture. Please check camera connection."
        case .photoOutputNotAvailable:
            return "Photo capture is not available. Please restart the camera."
        case .captureFailed(let error):
            return "Photo capture failed: \(error.localizedDescription)"
        case .imageDataConversionFailed:
            return "Failed to process captured photo data."
        case .sessionConfigurationFailed:
            return "Failed to configure camera session."
        }
    }
} 