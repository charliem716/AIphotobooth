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
    weak var captureDelegate: (any CameraCaptureDelegate)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupInitialState()
    }
    
    deinit {
        // Can't call stopSession in deinit for actor-isolated methods
        captureSession?.stopRunning()
    }
    
    // MARK: - Public Methods
    
    /// Initialize and start the camera session
    func setupCamera() async {
        logger.info("Setting up camera service...")
        
        await requestCameraPermission()
        
        guard authorizationStatus == .authorized else {
            logger.warning("Camera access not authorized")
            isCameraConnected = false
            return
        }
        
        await setupCaptureSession()
        await discoverCameras()
        // Note: startSession() will be called when a camera is selected in setupCameraSession
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
        logger.info("🔍 [DEBUG] Starting comprehensive camera discovery...")
        
        // Try multiple discovery approaches for better iPhone detection
        let allDeviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .continuityCamera,
            .external
        ]
        
        logger.info("🔍 [DEBUG] Searching for device types: \(allDeviceTypes.map { $0.rawValue })")
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: allDeviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        availableCameras = discoverySession.devices
        
        // Also try the default video devices approach for additional detection
        let defaultDevices = AVCaptureDevice.devices(for: .video)
        logger.info("🔍 [DEBUG] Default video devices: \(defaultDevices.count)")
        for device in defaultDevices {
            if !availableCameras.contains(device) {
                logger.info("   Additional device: \(device.localizedName) (Type: \(device.deviceType.rawValue))")
                availableCameras.append(device)
            }
        }
        
        logger.info("🔍 [DEBUG] Found \(self.availableCameras.count) total cameras:")
        
        for (index, device) in self.availableCameras.enumerated() {
            let isConnected = device.isConnected ? "✅ Connected" : "❌ Disconnected"
            let position = device.position.description
            logger.info("   \(index + 1). \(device.localizedName)")
            logger.info("      Type: \(device.deviceType.rawValue)")
            logger.info("      Position: \(position)")
            logger.info("      Status: \(isConnected)")
            logger.info("      Unique ID: \(device.uniqueID)")
            
            // Special detection for potential iPhones
            if device.localizedName.lowercased().contains("iphone") ||
               device.localizedName.lowercased().contains("charlie") ||
               device.localizedName.contains("15 Pro") ||
               device.deviceType == .continuityCamera ||
               device.deviceType == .external {
                logger.info("      ⭐ POTENTIAL CONTINUITY CAMERA DETECTED!")
            }
        }
        
        logger.info("🔍 [DEBUG] Total cameras after comprehensive search: \(self.availableCameras.count)")
        
        // Check if we have any continuity cameras specifically
        let continuityCameras = availableCameras.filter { $0.deviceType == .continuityCamera }
        logger.info("🔍 [DEBUG] Continuity cameras found: \(continuityCameras.count)")
        for camera in continuityCameras {
            logger.info("🔍 [DEBUG] Continuity camera: \(camera.localizedName), connected: \(camera.isConnected)")
        }
        
        // Auto-select best camera using the working logic
        await selectBestAvailableCamera()
    }
    
    /// Select the best available camera using the working logic
    private func selectBestAvailableCamera() async {
        var selectedCamera: AVCaptureDevice?
        
        // First look for Charlie's iPhone specifically
        if let charlieCamera = self.availableCameras.first(where: { 
            $0.localizedName.contains("Charlie") || $0.localizedName.contains("15 Pro")
        }) {
            logger.info("📱 Found Charlie's iPhone: \(charlieCamera.localizedName)")
            selectedCamera = charlieCamera
        }
        // Then try continuity camera type
        else if let continuityCamera = self.availableCameras.first(where: { $0.deviceType == .continuityCamera }) {
            logger.info("📱 Found Continuity Camera: \(continuityCamera.localizedName)")
            selectedCamera = continuityCamera
        }
        // Then try external cameras (needed for continuity cameras until Info.plist is properly configured)
        else if let externalCamera = self.availableCameras.first(where: { $0.deviceType == .external }) {
            logger.info("📱 Found external camera: \(externalCamera.localizedName)")
            selectedCamera = externalCamera
        }
        // Fallback to built-in camera
        else if let builtInCamera = self.availableCameras.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            logger.info("💻 Using built-in camera: \(builtInCamera.localizedName)")
            selectedCamera = builtInCamera
        }
        
        if let camera = selectedCamera {
            await selectCamera(camera)
        } else {
            logger.warning("❌ No camera found")
        }
    }
    
    /// Select a specific camera device
    func selectCamera(_ device: AVCaptureDevice) async {
        guard availableCameras.contains(device) else {
            logger.error("Attempted to select unavailable camera: \(device.localizedName)")
            return
        }
        
        selectedCameraDevice = device
        logger.info("📱 [DEBUG] Selecting camera: \(device.localizedName)")
        logger.info("📱 [DEBUG] Camera type: \(device.deviceType.rawValue)")
        logger.info("📱 [DEBUG] Camera connected: \(device.isConnected)")
        
        await setupCameraSession(with: device)
    }
    
    /// Setup camera session with the selected device using the working approach
    private func setupCameraSession(with device: AVCaptureDevice) async {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
                
                // Setup photo output
                let output = AVCapturePhotoOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    photoOutput = output
                }
                
                logger.info("✅ Camera setup complete: \(device.localizedName)")
                
            } else {
                throw PhotoBoothError.cameraNotFound
            }
        } catch {
            logger.error("Failed to setup camera: \(error.localizedDescription)")
            isCameraConnected = false
        }
        
        session.commitConfiguration()
        
        // Start the session and update connection status
        await startSession()
        
        // Give the session a moment to fully initialize and update status once more
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Final connection status update
        if let session = captureSession {
            let hasValidSetup = !session.inputs.isEmpty && selectedCameraDevice != nil && session.isRunning
            isCameraConnected = hasValidSetup
            logger.info("📱 Final connection status - Connected: \(hasValidSetup)")
        }
    }
    
    /// Capture a photo using the current camera
    func capturePhoto() {
        logger.info("🚀 CameraService.capturePhoto() called")
        
        guard let photoOutput = photoOutput else {
            logger.error("❌ Photo output not available")
            captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.photoOutputNotAvailable)
            return
        }
        
        guard isCameraConnected && isSessionRunning else {
            logger.error("❌ Camera not ready for capture - Connected: \(self.isCameraConnected), Running: \(self.isSessionRunning)")
            captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.cameraNotReady)
            return
        }
        
        logger.info("📸 Capturing photo with AVCapturePhotoOutput...")
        logger.debug("📸 Delegate set: \(self.captureDelegate != nil)")
        
        let settings = AVCapturePhotoSettings()
        // Use completely default settings to avoid any crashes
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        logger.debug("📸 capturePhoto() call completed")
    }
    
    /// Refresh and rediscover available cameras
    func refreshCameras() async {
        logger.info("🔄 Refreshing camera list...")
        await discoverCameras()
    }
    
    /// Force continuity camera connection using the working approach
    func forceContinuityCameraConnection() async {
        logger.info("📱 [DEBUG] Forcing Continuity Camera connection...")
        await discoverCameras()
        
        // Look for Charlie's iPhone specifically first
        if let charlieCamera = self.availableCameras.first(where: { 
            $0.localizedName.contains("Charlie") || $0.localizedName.contains("15 Pro")
        }) {
            logger.info("📱 Found Charlie's iPhone: \(charlieCamera.localizedName)")
            await selectCamera(charlieCamera)
        }
        // Then look for continuity camera type
        else if let continuityCamera = self.availableCameras.first(where: { $0.deviceType == .continuityCamera }) {
            logger.info("📱 Found Continuity Camera: \(continuityCamera.localizedName)")
            await selectCamera(continuityCamera)
        }
        // Then look for external cameras (needed for continuity cameras)
        else if let externalCamera = self.availableCameras.first(where: { $0.deviceType == .external }) {
            logger.info("📱 Found external camera: \(externalCamera.localizedName)")
            await selectCamera(externalCamera)
        }
        else {
            logger.warning("❌ No Continuity Camera found")
        }
    }
    

    
    /// Start the camera session
    func startSession() async {
        guard let captureSession = captureSession else {
            logger.error("Capture session not available")
            isCameraConnected = false
            return
        }
        
        guard !captureSession.isRunning else {
            logger.debug("Capture session already running")
            // Check if we have a valid input and set connection status
            let hasValidSetup = !captureSession.inputs.isEmpty && selectedCameraDevice != nil
            isCameraConnected = hasValidSetup
            logger.info("📱 Session already running - Connected: \(hasValidSetup)")
            return
        }
        
        logger.info("Starting camera session...")
        captureSession.startRunning()
        
        // Give the session a moment to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        isSessionRunning = captureSession.isRunning
        
        if isSessionRunning {
            // Set connection status based on session state
            let hasValidSetup = !captureSession.inputs.isEmpty && selectedCameraDevice != nil
            isCameraConnected = hasValidSetup
            logger.info("✅ Camera session started successfully - Connected: \(hasValidSetup)")
        } else {
            self.isCameraConnected = false
            logger.error("❌ Failed to start camera session")
        }
    }
    
    /// Stop the camera session
    func stopSession() {
        guard let captureSession = captureSession else { return }
        
        logger.info("Stopping camera session...")
        captureSession.stopRunning()
        isSessionRunning = false
        self.isCameraConnected = false
        logger.info("❌ Camera session stopped - Connected: \(self.isCameraConnected)")
    }
    
    /// Update connection status based on actual session state
    private func updateConnectionStatus() {
        guard let captureSession = captureSession else {
            isCameraConnected = false
            logger.info("📱 Connection status: No capture session")
            return
        }
        
        // Check if session is running and has valid inputs
        let hasValidInputs = !captureSession.inputs.isEmpty
        let sessionRunning = captureSession.isRunning
        let hasDevice = selectedCameraDevice != nil
        let deviceName = selectedCameraDevice?.localizedName ?? "none"
        
        let isConnected = hasValidInputs && sessionRunning && hasDevice
        
        isCameraConnected = isConnected
        isSessionRunning = sessionRunning
        logger.info("📱 Connection status updated - Connected: \(isConnected), Running: \(sessionRunning), Device: \(hasDevice) (\(deviceName)), Inputs: \(hasValidInputs)")
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
    

    
    // MARK: - Image Processing Helpers
    
    /// Crop image to 3:2 landscape aspect ratio (standard photo booth format)
    private func cropToLandscape(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let originalAspectRatio = originalWidth / originalHeight
        let targetAspectRatio: CGFloat = 1536.0 / 1024.0 // 3:2 = 1.5
        
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        
        if originalAspectRatio > targetAspectRatio {
            // Image is wider than target - crop width (use full height)
            cropHeight = originalHeight
            cropWidth = cropHeight * targetAspectRatio
        } else {
            // Image is taller than target - crop height (use full width)
            cropWidth = originalWidth
            cropHeight = cropWidth / targetAspectRatio
        }
        
        // Calculate crop origin to center the crop
        let cropX = (originalWidth - cropWidth) / 2
        let cropY = (originalHeight - cropHeight) / 2
        
        // Create crop rectangle
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Crop the image
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        // Create new NSImage from cropped image
        let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropWidth, height: cropHeight))
        
        logger.debug("Cropped to 3:2 aspect ratio: \(Int(cropWidth)) × \(Int(cropHeight))")
        return croppedImage
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            logger.info("📸 photoOutput delegate callback triggered")
        }
        
        if let error = error {
            Task { @MainActor in
                logger.error("❌ Photo capture error: \(error.localizedDescription)")
                captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.captureFailed(error))
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let rawImage = NSImage(data: data) else {
            Task { @MainActor in
                logger.error("❌ Could not get image data from photo")
                captureDelegate?.cameraService(self, didFailWithError: CameraServiceError.imageDataConversionFailed)
            }
            return
        }
        
        Task { @MainActor in
            logger.info("✅ Photo captured successfully, size: \(data.count) bytes")
            logger.debug("📸 Raw captured image: \(rawImage.size.width) x \(rawImage.size.height)")
            
            // 🔧 FIX: Crop to 3:2 aspect ratio immediately after capture (standard photo booth format)
            let croppedImage = cropToLandscape(rawImage) ?? rawImage
            logger.debug("📸 Final image: \(croppedImage.size.width) x \(croppedImage.size.height)")
            
            logger.debug("📸 Calling captureDelegate with cropped image")
            captureDelegate?.cameraService(self, didCapturePhoto: croppedImage)
        }
    }
}

// MARK: - Supporting Types

/// Delegate protocol for camera capture events
@MainActor
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