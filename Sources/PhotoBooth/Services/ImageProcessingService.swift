import Foundation
import AppKit
import os.log

/// Service responsible for image processing, manipulation, and file management
@MainActor
final class ImageProcessingService: ObservableObject, ImageProcessingServiceProtocol {
    
    // MARK: - Properties
    private let logger = Logger(subsystem: "PhotoBooth", category: "ImageProcessing")
    private let boothDirectory: URL
    
    // MARK: - Published Properties
    @Published var isProcessingImage = false
    
    // MARK: - Initialization
    init() {
        // Setup booth directory in Pictures folder
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        self.boothDirectory = picturesURL.appendingPathComponent("booth")
        
        setupBoothDirectory()
    }
    
    // MARK: - Public Methods
    
    /// Save original image with timestamp
    /// - Parameters:
    ///   - image: The original NSImage to save
    ///   - timestamp: Shared timestamp for photo session
    /// - Returns: URL of the saved original image
    /// - Throws: ImageProcessingError for various failure cases
    func saveOriginalImage(_ image: NSImage, timestamp: TimeInterval) async throws -> URL {
        logger.info("Saving original image with timestamp: \(timestamp)")
        
        let filename = String(format: "original_%.0f.jpg", timestamp)
        let fileURL = boothDirectory.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            logger.error("Failed to convert original image to JPEG")
            throw ImageProcessingError.imageConversionFailed
        }
        
        do {
            try jpegData.write(to: fileURL)
            logger.info("Original image saved to: \(fileURL.path)")
            return fileURL
        } catch {
            logger.error("Failed to save original image: \(error.localizedDescription)")
            throw ImageProcessingError.fileSaveFailed(error)
        }
    }
    
    /// Save themed image with timestamp
    /// - Parameters:
    ///   - image: The themed NSImage to save
    ///   - timestamp: Shared timestamp for photo session
    /// - Returns: URL of the saved themed image
    /// - Throws: ImageProcessingError for various failure cases
    func saveThemedImage(_ image: NSImage, timestamp: TimeInterval) async throws -> URL {
        logger.info("Saving themed image with timestamp: \(timestamp)")
        
        let filename = String(format: "themed_%.0f.jpg", timestamp)
        let fileURL = boothDirectory.appendingPathComponent(filename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            logger.error("Failed to convert themed image to JPEG")
            throw ImageProcessingError.imageConversionFailed
        }
        
        do {
            try jpegData.write(to: fileURL)
            logger.info("Themed image saved to: \(fileURL.path)")
            return fileURL
        } catch {
            logger.error("Failed to save themed image: \(error.localizedDescription)")
            throw ImageProcessingError.fileSaveFailed(error)
        }
    }
    
    /// Resize image to specified dimensions while maintaining aspect ratio
    /// - Parameters:
    ///   - image: Source NSImage to resize
    ///   - targetSize: Target CGSize for the resized image
    /// - Returns: Resized NSImage
    func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        let sourceSize = image.size
        logger.debug("Resizing image from \(sourceSize.width)x\(sourceSize.height) to \(targetSize.width)x\(targetSize.height)")
        
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
    /// Log image dimensions for debugging
    /// - Parameters:
    ///   - image: NSImage to inspect
    ///   - label: Descriptive label for logging
    func logImageDimensions(_ image: NSImage, label: String) {
        let size = image.size
        logger.debug("\(label) dimensions: \(size.width) x \(size.height)")
    }
    
    /// Get booth directory URL
    func getBoothDirectoryURL() -> URL {
        return boothDirectory
    }
    
    /// Clean up old images based on retention policy
    /// - Parameter retentionDays: Number of days to retain images
    func cleanupOldImages(retentionDays: Int = 7) async throws {
        logger.info("Cleaning up images older than \(retentionDays) days")
        
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(retentionDays * 24 * 60 * 60))
        
        guard fileManager.fileExists(atPath: boothDirectory.path) else {
            logger.debug("Booth directory does not exist, nothing to clean")
            return
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: boothDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            var deletedCount = 0
            
            for fileURL in files {
                guard fileURL.pathExtension.lowercased() == "png" else { continue }
                
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date,
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                    logger.debug("Deleted old image: \(fileURL.lastPathComponent)")
                }
            }
            
            logger.info("Cleanup completed - deleted \(deletedCount) old images")
            
        } catch {
            logger.error("Failed to cleanup old images: \(error.localizedDescription)")
            throw ImageProcessingError.cleanupFailed(error)
        }
    }
    
    /// Get cache statistics
    func getCacheStatistics() async -> CacheStatistics {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: boothDirectory.path) else {
            return CacheStatistics(totalFiles: 0, totalSizeBytes: 0, oldestFile: nil, newestFile: nil)
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: boothDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            
            var totalFiles = 0
            var totalSizeBytes: Int64 = 0
            var oldestDate: Date?
            var newestDate: Date?
            
            for fileURL in files {
                guard fileURL.pathExtension.lowercased() == "png" else { continue }
                
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                
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
            
            return CacheStatistics(
                totalFiles: totalFiles,
                totalSizeBytes: totalSizeBytes,
                oldestFile: oldestDate,
                newestFile: newestDate
            )
            
        } catch {
            logger.error("Failed to get cache statistics: \(error.localizedDescription)")
            return CacheStatistics(totalFiles: 0, totalSizeBytes: 0, oldestFile: nil, newestFile: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBoothDirectory() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: boothDirectory.path) {
            do {
                try fileManager.createDirectory(at: boothDirectory, withIntermediateDirectories: true)
                logger.info("Created booth directory at: \(self.boothDirectory.path)")
            } catch {
                logger.error("Failed to create booth directory: \(error.localizedDescription)")
            }
        } else {
            logger.debug("Booth directory already exists at: \(self.boothDirectory.path)")
        }
    }
}

// MARK: - Supporting Types

/// Cache statistics for monitoring
struct CacheStatistics {
    let totalFiles: Int
    let totalSizeBytes: Int64
    let oldestFile: Date?
    let newestFile: Date?
    
    var totalSizeMB: Double {
        return Double(totalSizeBytes) / (1024 * 1024)
    }
}

/// Errors that can occur during image processing operations
enum ImageProcessingError: LocalizedError {
    case imageConversionFailed
    case fileSaveFailed(Error)
    case cleanupFailed(Error)
    case directoryCreationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to required format."
        case .fileSaveFailed(let error):
            return "Failed to save image file: \(error.localizedDescription)"
        case .cleanupFailed(let error):
            return "Failed to cleanup old images: \(error.localizedDescription)"
        case .directoryCreationFailed(let error):
            return "Failed to create directory: \(error.localizedDescription)"
        }
    }
} 