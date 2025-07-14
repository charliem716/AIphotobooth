import Foundation
import AppKit
import AVFoundation

// MARK: - Configuration Service Protocol

/// Protocol for configuration management services
protocol ConfigurationServiceProtocol: ObservableObject {
    var isOpenAIConfigured: Bool { get }
    var isTwilioConfigured: Bool { get }
    var isFullyConfigured: Bool { get }
    var configurationSummary: String { get }
    
    func getOpenAIKey() -> String?
    func getTwilioSID() -> String?
    func getTwilioToken() -> String?
    func getTwilioFromNumber() -> String?
    func getOpenAIHost() -> String
    func getOpenAIPort() -> Int
    func getOpenAIScheme() -> String
    func validateConfiguration()
}

// MARK: - OpenAI Service Protocol

/// Protocol for OpenAI image generation services
protocol OpenAIServiceProtocol: ObservableObject {
    var isConfigured: Bool { get }
    
    func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage
}

// MARK: - Camera Service Protocol

/// Protocol for camera management services
protocol CameraServiceProtocol: ObservableObject {
    var isSessionRunning: Bool { get }
    var isCameraConnected: Bool { get }
    var availableCameras: [AVCaptureDevice] { get }
    var selectedCameraDevice: AVCaptureDevice? { get }
    var authorizationStatus: AVAuthorizationStatus { get }
    var captureDelegate: CameraCaptureDelegate? { get set }
    
    func setupCamera() async
    func requestCameraPermission() async
    func discoverCameras() async
    func selectCamera(_ device: AVCaptureDevice) async
    func capturePhoto()
    func startSession() async
    func stopSession()
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer?
}

// MARK: - Image Processing Service Protocol

/// Protocol for image processing services
protocol ImageProcessingServiceProtocol: ObservableObject {
    var isProcessingImage: Bool { get }
    
    func saveOriginalImage(_ image: NSImage, timestamp: TimeInterval) async throws -> URL
    func saveThemedImage(_ image: NSImage, timestamp: TimeInterval) async throws -> URL
    func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage
    func logImageDimensions(_ image: NSImage, label: String)
    func getBoothDirectoryURL() -> URL
    func cleanupOldImages(retentionDays: Int) async throws
    func getCacheStatistics() async -> CacheStatistics
}

// MARK: - Service Coordinator Protocol

/// Protocol for coordinating between multiple services
protocol PhotoBoothServiceCoordinator: ObservableObject {
    var configurationService: ConfigurationServiceProtocol { get }
    var openAIService: OpenAIServiceProtocol { get }
    var cameraService: CameraServiceProtocol { get }
    var imageProcessingService: ImageProcessingServiceProtocol { get }
    
    func setupAllServices() async
    func validateServicesConfiguration() -> Bool
}

// MARK: - Default Protocol Extensions

/// Default implementations for configuration service
extension ConfigurationServiceProtocol {
    var isFullyConfigured: Bool {
        return isOpenAIConfigured
        // Note: Excluding Twilio as requested in requirements
    }
}

/// Default implementations for camera service
extension CameraServiceProtocol {
    func refreshCameras() async {
        await discoverCameras()
    }
}

/// Default implementations for image processing service
extension ImageProcessingServiceProtocol {
    func cleanupOldImages() async throws {
        try await cleanupOldImages(retentionDays: 7)
    }
}

// MARK: - Error Handling Protocols

/// Protocol for services that can report errors
protocol ErrorReportingService {
    associatedtype ServiceError: LocalizedError
    var lastError: ServiceError? { get }
    func clearLastError()
}

/// Protocol for services that support retry operations
protocol RetryableService {
    func retryLastOperation() async throws
    var maxRetryAttempts: Int { get }
    var retryDelay: TimeInterval { get }
}

// MARK: - Logging Protocol

/// Protocol for services with structured logging
protocol LoggingService {
    var logCategory: String { get }
    func logInfo(_ message: String)
    func logWarning(_ message: String)
    func logError(_ message: String)
    func logDebug(_ message: String)
} 