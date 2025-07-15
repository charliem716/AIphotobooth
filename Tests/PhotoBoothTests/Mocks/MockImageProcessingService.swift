import Foundation
import AppKit
import Combine
@testable import PhotoBooth

/// Mock Image Processing Service for testing
@MainActor
final class MockImageProcessingService: ObservableObject, ImageProcessingServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isProcessingImage = false
    
    // MARK: - Mock Configuration
    var shouldThrowError = false
    var shouldSimulateDelay = false
    var delayDuration: TimeInterval = 0.5
    var mockError: Error = MockImageProcessingError.mockSaveError
    var saveOriginalCallCount = 0
    var saveThemedCallCount = 0
    var resizeCallCount = 0
    var logDimensionsCallCount = 0
    var cleanupCallCount = 0
    var getCacheStatsCallCount = 0
    
    // MARK: - Mock Data
    var mockBoothDirectory: URL
    var mockSavedURLs: [URL] = []
    var mockCacheStats = CacheStatistics(totalFiles: 0, totalSizeBytes: 0, oldestFile: nil, newestFile: nil)
    
    // MARK: - Initialization
    init() {
        let tempDir = FileManager.default.temporaryDirectory
        mockBoothDirectory = tempDir.appendingPathComponent("mock-booth")
        
        // Create mock directory
        try? FileManager.default.createDirectory(at: mockBoothDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - ImageProcessingServiceProtocol
    
    func saveOriginalImage(_ image: NSImage, timestamp: TimeInterval) async throws -> URL {
        saveOriginalCallCount += 1
        isProcessingImage = true
        
        if shouldSimulateDelay {
            try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            isProcessingImage = false
            throw mockError
        }
        
        let filename = "original_\(Int(timestamp)).png"
        let fileURL = mockBoothDirectory.appendingPathComponent(filename)
        
        // Simulate saving the image
        let imageData = createMockImageData(image)
        try imageData.write(to: fileURL)
        
        mockSavedURLs.append(fileURL)
        isProcessingImage = false
        
        return fileURL
    }
    
    func saveThemedImage(_ image: NSImage, timestamp: TimeInterval) async throws -> URL {
        saveThemedCallCount += 1
        isProcessingImage = true
        
        if shouldSimulateDelay {
            try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            isProcessingImage = false
            throw mockError
        }
        
        let filename = "themed_\(Int(timestamp)).png"
        let fileURL = mockBoothDirectory.appendingPathComponent(filename)
        
        // Simulate saving the image
        let imageData = createMockImageData(image)
        try imageData.write(to: fileURL)
        
        mockSavedURLs.append(fileURL)
        isProcessingImage = false
        
        return fileURL
    }
    
    func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        resizeCallCount += 1
        
        if shouldThrowError {
            return image // Return original on error
        }
        
        // Create mock resized image
        let resizedImage = NSImage(size: NSSize(width: targetSize.width, height: targetSize.height))
        resizedImage.lockFocus()
        
        // Draw the original image scaled to target size
        image.draw(in: NSRect(origin: .zero, size: NSSize(width: targetSize.width, height: targetSize.height)))
        
        resizedImage.unlockFocus()
        return resizedImage
    }
    
    func logImageDimensions(_ image: NSImage, label: String) {
        logDimensionsCallCount += 1
        print("MOCK LOG: \(label) - Dimensions: \(image.size)")
    }
    
    func getBoothDirectoryURL() -> URL {
        return mockBoothDirectory
    }
    
    func cleanupOldImages(retentionDays: Int) async throws {
        cleanupCallCount += 1
        
        if shouldSimulateDelay {
            try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw mockError
        }
        
        // Simulate cleanup by removing some mock files
        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)
        let filesToRemove = mockSavedURLs.filter { url in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                return false
            }
            return modificationDate < cutoffDate
        }
        
        for fileURL in filesToRemove {
            try? FileManager.default.removeItem(at: fileURL)
            mockSavedURLs.removeAll { $0 == fileURL }
        }
    }
    
    func getCacheStatistics() async -> CacheStatistics {
        getCacheStatsCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        // Update mock cache stats based on current mock files
        updateMockCacheStats()
        
        return mockCacheStats
    }
    
    // MARK: - Mock Helpers
    
    func reset() {
        shouldThrowError = false
        shouldSimulateDelay = false
        delayDuration = 0.5
        mockError = MockImageProcessingError.mockSaveError
        saveOriginalCallCount = 0
        saveThemedCallCount = 0
        resizeCallCount = 0
        logDimensionsCallCount = 0
        cleanupCallCount = 0
        getCacheStatsCallCount = 0
        isProcessingImage = false
        
        // Clear mock files
        mockSavedURLs.removeAll()
        try? FileManager.default.removeItem(at: mockBoothDirectory)
        try? FileManager.default.createDirectory(at: mockBoothDirectory, withIntermediateDirectories: true)
        
        mockCacheStats = CacheStatistics(totalFiles: 0, totalSizeBytes: 0, oldestFile: nil, newestFile: nil)
    }
    
    func configureForError(_ error: Error) {
        shouldThrowError = true
        mockError = error
    }
    
    func configureForDelay(_ duration: TimeInterval) {
        shouldSimulateDelay = true
        delayDuration = duration
    }
    
    func setMockCacheStats(_ stats: CacheStatistics) {
        mockCacheStats = stats
    }
    
    func addMockFile(name: String, sizeBytes: Int64) {
        let fileURL = mockBoothDirectory.appendingPathComponent(name)
        let mockData = Data(repeating: 0, count: Int(sizeBytes))
        try? mockData.write(to: fileURL)
        mockSavedURLs.append(fileURL)
        updateMockCacheStats()
    }
    
    // MARK: - Private Methods
    
    private func createMockImageData(_ image: NSImage) -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            // Fallback to minimal PNG data
            return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG signature
        }
        return pngData
    }
    
    private func updateMockCacheStats() {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(at: mockBoothDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }
        
        var totalFiles = 0
        var totalSizeBytes: Int64 = 0
        var oldestDate: Date?
        var newestDate: Date?
        
        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) else { continue }
            
            if let fileSize = attributes[.size] as? Int64 {
                totalSizeBytes += fileSize
            }
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                if oldestDate == nil || modificationDate < oldestDate! {
                    oldestDate = modificationDate
                }
                if newestDate == nil || modificationDate > newestDate! {
                    newestDate = modificationDate
                }
            }
            
            totalFiles += 1
        }
        
        mockCacheStats = CacheStatistics(
            totalFiles: totalFiles,
            totalSizeBytes: totalSizeBytes,
            oldestFile: oldestDate,
            newestFile: newestDate
        )
    }
}

// MARK: - Mock Errors

enum MockImageProcessingError: Error, LocalizedError {
    case mockSaveError
    case mockResizeError
    case mockCleanupError
    case mockDirectoryError
    
    var errorDescription: String? {
        switch self {
        case .mockSaveError:
            return "Mock image save error"
        case .mockResizeError:
            return "Mock image resize error"
        case .mockCleanupError:
            return "Mock image cleanup error"
        case .mockDirectoryError:
            return "Mock directory error"
        }
    }
} 