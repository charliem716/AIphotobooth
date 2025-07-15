import Foundation
import AppKit
import AVFoundation

// MARK: - Configuration Service Protocol

/// Protocol for configuration management services
@MainActor
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
@MainActor
protocol OpenAIServiceProtocol: ObservableObject {
    var isConfigured: Bool { get }
    
    func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage
}

// MARK: - Camera Service Protocol

/// Protocol for camera management services
@MainActor
protocol CameraServiceProtocol: ObservableObject {
    var isSessionRunning: Bool { get }
    var isCameraConnected: Bool { get }
    var availableCameras: [AVCaptureDevice] { get }
    var selectedCameraDevice: AVCaptureDevice? { get }
    var authorizationStatus: AVAuthorizationStatus { get }
    var captureDelegate: (any CameraCaptureDelegate)? { get set }
    
    func setupCamera() async
    func requestCameraPermission() async
    func discoverCameras() async
    func selectCamera(_ device: AVCaptureDevice) async
    func capturePhoto()
    func startSession() async
    func stopSession()
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer?
    func forceContinuityCameraConnection() async
}

// MARK: - Image Processing Service Protocol

/// Protocol for image processing services
@MainActor
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

// MARK: - Cache Management Service Protocol

/// Protocol for cache management services
@MainActor
protocol CacheManagementServiceProtocol: ObservableObject {
    var cacheStatistics: CacheStatistics { get }
    var isCleaningUp: Bool { get }
    var automaticCleanupEnabled: Bool { get set }
    var automaticCleanupRetentionDays: Int { get set }
    var lastCleanupDate: Date? { get }
    
    func refreshCacheStatistics() async
    func cleanupCache(retentionDays: Int) async throws
    func performAutomaticCleanup() async throws
    func scheduleAutomaticCleanup()
    func cancelAutomaticCleanup()
    func getCacheSize() async -> Int64
    func getCacheFileCount() async -> Int
    func getOldestCacheFile() async -> Date?
    func getNewestCacheFile() async -> Date?
    func exportCacheCleanupScript() throws -> URL
}

// MARK: - Service Coordinator Protocol

/// Protocol for coordinating between multiple services
@MainActor
protocol PhotoBoothServiceCoordinatorProtocol: ObservableObject {
    var configurationService: any ConfigurationServiceProtocol { get }
    var openAIService: any OpenAIServiceProtocol { get }
    var cameraService: any CameraServiceProtocol { get }
    var imageProcessingService: any ImageProcessingServiceProtocol { get }
    var cacheManagementService: any CacheManagementServiceProtocol { get }
    
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
    
    func forceContinuityCameraConnection() async {
        await discoverCameras()
    }
}

/// Default implementations for image processing service
extension ImageProcessingServiceProtocol {
    func cleanupOldImages() async throws {
        try await cleanupOldImages(retentionDays: 7)
    }
}

/// Default implementations for cache management service
extension CacheManagementServiceProtocol {
    func performAutomaticCleanup() async throws {
        if automaticCleanupEnabled {
            try await cleanupCache(retentionDays: automaticCleanupRetentionDays)
        }
    }
    
    var automaticCleanupRetentionDays: Int {
        get { 7 }
        set { }
    }
    
    var automaticCleanupEnabled: Bool {
        get { false }
        set { }
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

 