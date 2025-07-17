import Foundation
import SwiftUI
import os.log

// MARK: - Cache Statistics Extensions

/// Extensions for CacheStatistics with additional functionality
extension CacheStatistics {
    /// Human-readable size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
    
    /// Cache age in days
    var cacheAgeDays: Int {
        guard let oldestFile = oldestFile else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: oldestFile, to: Date()).day ?? 0
        return days
    }
    
    /// Whether cache needs cleanup based on size or age
    var needsCleanup: Bool {
        let maxSizeBytes: Int64 = 1024 * 1024 * 1024 // 1GB
        let maxAgeDays = 30
        return totalSizeBytes > maxSizeBytes || cacheAgeDays > maxAgeDays
    }
}

// MARK: - Cache Management Service

/// Service for managing PhotoBooth cache operations
@MainActor
final class CacheManagementService: ObservableObject, CacheManagementServiceProtocol {
    
    // MARK: - Properties
    
    @Published var cacheStatistics = CacheStatistics(totalFiles: 0, totalSizeBytes: 0, oldestFile: nil, newestFile: nil)
    @Published var isCleaningUp = false
    @Published var automaticCleanupEnabled = false {
        didSet {
            if automaticCleanupEnabled {
                scheduleAutomaticCleanup()
            } else {
                cancelAutomaticCleanup()
            }
        }
    }
    @Published var automaticCleanupRetentionDays = 7 {
        didSet {
            if automaticCleanupEnabled {
                scheduleAutomaticCleanup()
            }
        }
    }
    @Published var lastCleanupDate: Date?
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.photobooth.cache", category: "CacheManagement")
    private var cleanupTimer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // Cache directory URL
    private var cacheDirectoryURL: URL {
        let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
        return picturesURL.appendingPathComponent("booth")
    }
    
    // UserDefaults keys
    private enum UserDefaultsKeys {
        static let lastCleanupDate = "CacheManagementService.lastCleanupDate"
        static let automaticCleanupEnabled = "CacheManagementService.automaticCleanupEnabled"
        static let automaticCleanupRetentionDays = "CacheManagementService.automaticCleanupRetentionDays"
    }
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        
        // Start monitoring cache in background
        Task {
            await refreshCacheStatistics()
            if automaticCleanupEnabled {
                scheduleAutomaticCleanup()
            }
        }
    }
    
    deinit {
        // Timer will be automatically invalidated when the object is deallocated
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Protocol Implementation
    
    func refreshCacheStatistics() async {
        logger.info("Refreshing cache statistics")
        
        do {
            let statistics = try await calculateCacheStatistics()
            
            await MainActor.run {
                self.cacheStatistics = statistics
            }
            
            logger.info("Cache statistics updated: \(statistics.formattedSize), \(statistics.totalFiles) files")
        } catch {
            logger.error("Failed to refresh cache statistics: \(error.localizedDescription)")
        }
    }
    
    func cleanupCache(retentionDays: Int) async throws {
        logger.info("Starting cache cleanup with retention: \(retentionDays) days")
        
        await MainActor.run {
            self.isCleaningUp = true
        }
        
        defer {
            Task { @MainActor in
                self.isCleaningUp = false
            }
        }
        
        do {
            let cleanupResult = try await performCleanupOperation(retentionDays: retentionDays)
            
            await MainActor.run {
                self.lastCleanupDate = Date()
                self.saveSettings()
            }
            
            // Refresh statistics after cleanup
            await refreshCacheStatistics()
            
            logger.info("Cache cleanup completed: \(cleanupResult.deletedFiles) files deleted, \(cleanupResult.freedSpace) bytes freed")
            
        } catch {
            logger.error("Cache cleanup failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func performAutomaticCleanup() async throws {
        guard automaticCleanupEnabled else { return }
        
        logger.info("Performing automatic cache cleanup")
        try await cleanupCache(retentionDays: automaticCleanupRetentionDays)
    }
    
    func scheduleAutomaticCleanup() {
        cancelAutomaticCleanup()
        
        // Schedule cleanup every 24 hours
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.performAutomaticCleanup()
            }
        }
        
        logger.info("Automatic cleanup scheduled for every 24 hours")
    }
    
    func cancelAutomaticCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        logger.info("Automatic cleanup cancelled")
    }
    
    func getCacheSize() async -> Int64 {
        return cacheStatistics.totalSizeBytes
    }
    
    func getCacheFileCount() async -> Int {
        return cacheStatistics.totalFiles
    }
    
    func getOldestCacheFile() async -> Date? {
        return cacheStatistics.oldestFile
    }
    
    func getNewestCacheFile() async -> Date? {
        return cacheStatistics.newestFile
    }
    
    func exportCacheCleanupScript() throws -> URL {
        let scriptContent = generateCleanupScript()
        let scriptURL = cacheDirectoryURL.appendingPathComponent("cleanup_cache.swift")
        
        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // Make the script executable
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        
        logger.info("Cache cleanup script exported to: \(scriptURL.path)")
        return scriptURL
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        lastCleanupDate = userDefaults.object(forKey: UserDefaultsKeys.lastCleanupDate) as? Date
        automaticCleanupEnabled = userDefaults.bool(forKey: UserDefaultsKeys.automaticCleanupEnabled)
        automaticCleanupRetentionDays = userDefaults.integer(forKey: UserDefaultsKeys.automaticCleanupRetentionDays)
        
        // Set default retention days if not set
        if automaticCleanupRetentionDays == 0 {
            automaticCleanupRetentionDays = 7
        }
    }
    
    private func saveSettings() {
        userDefaults.set(lastCleanupDate, forKey: UserDefaultsKeys.lastCleanupDate)
        userDefaults.set(automaticCleanupEnabled, forKey: UserDefaultsKeys.automaticCleanupEnabled)
        userDefaults.set(automaticCleanupRetentionDays, forKey: UserDefaultsKeys.automaticCleanupRetentionDays)
    }
    
    private func calculateCacheStatistics() async throws -> CacheStatistics {
        let cacheDirectoryURL = self.cacheDirectoryURL
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create sendable wrapper for FileManager
                struct SendableFileManager: @unchecked Sendable {
                    let fileManager: FileManager
                    init() {
                        self.fileManager = FileManager.default
                    }
                }
                let sendableFileManager = SendableFileManager()
                
                do {
                    // Create cache directory if it doesn't exist
                    if !sendableFileManager.fileManager.fileExists(atPath: cacheDirectoryURL.path) {
                        try sendableFileManager.fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
                        continuation.resume(returning: CacheStatistics(totalFiles: 0, totalSizeBytes: 0, oldestFile: nil, newestFile: nil))
                        return
                    }
                    
                    let resourceKeys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
                    let files = try sendableFileManager.fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: resourceKeys)
                    
                    var totalSize: Int64 = 0
                    var totalFiles = 0
                    var oldestDate: Date?
                    var newestDate: Date?
                    
                    for file in files {
                        do {
                            let resourceValues = try file.resourceValues(forKeys: Set(resourceKeys))
                            
                            if let fileSize = resourceValues.fileSize {
                                totalSize += Int64(fileSize)
                                totalFiles += 1
                            }
                            
                            let fileDate = resourceValues.creationDate ?? resourceValues.contentModificationDate
                            if let date = fileDate {
                                if oldestDate == nil || date < oldestDate! {
                                    oldestDate = date
                                }
                                if newestDate == nil || date > newestDate! {
                                    newestDate = date
                                }
                            }
                        } catch {
                            // Skip files that can't be read
                            continue
                        }
                    }
                    
                    let statistics = CacheStatistics(
                        totalFiles: totalFiles,
                        totalSizeBytes: totalSize,
                        oldestFile: oldestDate,
                        newestFile: newestDate
                    )
                    
                    continuation.resume(returning: statistics)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func performCleanupOperation(retentionDays: Int) async throws -> CleanupResult {
        let cacheDirectoryURL = self.cacheDirectoryURL
        let logger = self.logger
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create sendable wrapper for FileManager
                struct SendableFileManager: @unchecked Sendable {
                    let fileManager: FileManager
                    init() {
                        self.fileManager = FileManager.default
                    }
                }
                let sendableFileManager = SendableFileManager()
                
                do {
                    let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 24 * 60 * 60))
                    
                    guard sendableFileManager.fileManager.fileExists(atPath: cacheDirectoryURL.path) else {
                        continuation.resume(returning: CleanupResult(deletedFiles: 0, freedSpace: 0))
                        return
                    }
                    
                    let files = try sendableFileManager.fileManager.contentsOfDirectory(at: cacheDirectoryURL, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
                    
                    var deletedCount = 0
                    var freedSpace: Int64 = 0
                    
                    for file in files {
                        do {
                            let resourceValues = try file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                            
                            if let creationDate = resourceValues.creationDate,
                               creationDate < cutoffDate {
                                
                                let fileSize = Int64(resourceValues.fileSize ?? 0)
                                try sendableFileManager.fileManager.removeItem(at: file)
                                
                                deletedCount += 1
                                freedSpace += fileSize
                                
                                logger.info("Deleted cache file: \(file.lastPathComponent)")
                            }
                        } catch {
                            logger.error("Failed to process file \(file.lastPathComponent): \(error)")
                        }
                    }
                    
                    let result = CleanupResult(deletedFiles: deletedCount, freedSpace: freedSpace)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func generateCleanupScript() -> String {
        let scriptPath = Bundle.main.path(forResource: "cleanup_cache", ofType: "swift", inDirectory: "Scripts") ?? ""
        
        if let scriptContent = try? String(contentsOfFile: scriptPath) {
            return scriptContent
        }
        
        // Fallback: generate a basic cleanup script
        return """
        #!/usr/bin/env swift
        
        import Foundation
        
        // PhotoBooth Cache Cleanup Script
        // Generated by CacheManagementService
        
        let fileManager = FileManager.default
        let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let boothURL = picturesURL.appendingPathComponent("booth")
        
        // Default retention: 7 days
        let retentionDays = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 7 : 7
        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 24 * 60 * 60))
        
        print("🧹 PhotoBooth Cache Cleanup")
        print("📁 Cache directory: \\(boothURL.path)")
        print("🗓️  Removing files older than \\(retentionDays) days")
        print("")
        
        do {
            guard fileManager.fileExists(atPath: boothURL.path) else {
                print("No cache directory found. Nothing to clean.")
                exit(0)
            }
            
            let files = try fileManager.contentsOfDirectory(at: boothURL, includingPropertiesForKeys: [.creationDateKey])
            var deletedCount = 0
            var totalSize: Int64 = 0
            
            for file in files {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                if let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    let size = attributes[.size] as? Int64 ?? 0
                    totalSize += size
                    try fileManager.removeItem(at: file)
                    deletedCount += 1
                    print("❌ Deleted: \\(file.lastPathComponent)")
                }
            }
            
            if deletedCount > 0 {
                let sizeInMB = Double(totalSize) / 1024.0 / 1024.0
                print("")
                print("✅ Cleanup complete!")
                print("📊 Deleted \\(deletedCount) files, freed \\(String(format: "%.2f", sizeInMB)) MB")
            } else {
                print("✨ No old files to clean up!")
            }
            
        } catch {
            print("❌ Error during cleanup: \\(error.localizedDescription)")
            exit(1)
        }
        """
    }
}

// MARK: - Supporting Types

struct CleanupResult {
    let deletedFiles: Int
    let freedSpace: Int64
    
    var formattedFreedSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: freedSpace)
    }
}

// MARK: - Cache Management Errors

enum CacheManagementError: LocalizedError {
    case directoryNotFound
    case permissionDenied
    case cleanupFailed(String)
    case scriptExportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Cache directory not found"
        case .permissionDenied:
            return "Permission denied to access cache directory"
        case .cleanupFailed(let message):
            return "Cache cleanup failed: \(message)"
        case .scriptExportFailed(let message):
            return "Failed to export cleanup script: \(message)"
        }
    }
} 