import Foundation
import Combine
@testable import PhotoBooth

/// Mock Cache Management Service for testing
@MainActor
final class MockCacheManagementService: ObservableObject, CacheManagementServiceProtocol {
    
    // MARK: - Published Properties
    @Published var automaticCleanupEnabled = true
    @Published var automaticCleanupRetentionDays = 30
    @Published var lastCleanupDate: Date? = Date()
    @Published var isCleaningUp = false
    
    // MARK: - Mock Configuration
    var shouldThrowError = false
    var shouldSimulateDelay = false
    var delayDuration: TimeInterval = 0.5
    var mockError: Error = MockCacheError.cleanupError
    var cleanupCallCount = 0
    var refreshCallCount = 0
    var scheduleCallCount = 0
    var cancelCallCount = 0
    var getCacheSizeCallCount = 0
    var getFileCountCallCount = 0
    var getOldestFileCallCount = 0
    var getNewestFileCallCount = 0
    var exportScriptCallCount = 0
    
    // MARK: - Mock Data
    var mockCacheSize: Int64 = 1_000_000
    var mockFileCount: Int = 100
    var mockOldestFile: Date? = Date().addingTimeInterval(-86400) // 1 day ago
    var mockNewestFile: Date? = Date()
    var mockScriptURL: URL
    
    // MARK: - Computed Properties
    var cacheStatistics: CacheStatistics {
        return CacheStatistics(
            totalFiles: mockFileCount,
            totalSizeBytes: mockCacheSize,
            oldestFile: mockOldestFile,
            newestFile: mockNewestFile
        )
    }
    
    // MARK: - Initialization
    init() {
        mockScriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("mock-cleanup-script.sh")
    }
    
    // MARK: - CacheManagementServiceProtocol
    
    func refreshCacheStatistics() async {
        refreshCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
    }
    
    func cleanupCache(retentionDays: Int) async throws {
        cleanupCallCount += 1
        isCleaningUp = true
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        isCleaningUp = false
        
        if shouldThrowError {
            throw mockError
        }
        
        // Simulate cleanup by reducing cache size and count
        let cleanedFiles = min(20, mockFileCount)
        mockFileCount = max(0, mockFileCount - cleanedFiles)
        mockCacheSize = max(0, mockCacheSize - 200_000)
        lastCleanupDate = Date()
    }
    
    func performAutomaticCleanup() async throws {
        try await cleanupCache(retentionDays: automaticCleanupRetentionDays)
    }
    
    func scheduleAutomaticCleanup() {
        scheduleCallCount += 1
    }
    
    func cancelAutomaticCleanup() {
        cancelCallCount += 1
    }
    
    func getCacheSize() async -> Int64 {
        getCacheSizeCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        return mockCacheSize
    }
    
    func getCacheFileCount() async -> Int {
        getFileCountCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        return mockFileCount
    }
    
    func getOldestCacheFile() async -> Date? {
        getOldestFileCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        return mockOldestFile
    }
    
    func getNewestCacheFile() async -> Date? {
        getNewestFileCallCount += 1
        
        if shouldSimulateDelay {
            try? await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        return mockNewestFile
    }
    
    func exportCacheCleanupScript() throws -> URL {
        exportScriptCallCount += 1
        
        if shouldThrowError {
            throw mockError
        }
        
        // Create a mock script file
        let scriptContent = """
        #!/bin/bash
        # Mock cleanup script for testing
        echo "Cleaning up cache..."
        """
        
        try scriptContent.write(to: mockScriptURL, atomically: true, encoding: .utf8)
        return mockScriptURL
    }
    
    // MARK: - Mock Configuration Methods
    
    func reset() {
        shouldThrowError = false
        shouldSimulateDelay = false
        delayDuration = 0.5
        mockError = MockCacheError.cleanupError
        cleanupCallCount = 0
        refreshCallCount = 0
        scheduleCallCount = 0
        cancelCallCount = 0
        getCacheSizeCallCount = 0
        getFileCountCallCount = 0
        getOldestFileCallCount = 0
        getNewestFileCallCount = 0
        exportScriptCallCount = 0
        
        // Reset mock data
        mockCacheSize = 1_000_000
        mockFileCount = 100
        mockOldestFile = Date().addingTimeInterval(-86400)
        mockNewestFile = Date()
        lastCleanupDate = Date().addingTimeInterval(-86400)
        automaticCleanupEnabled = true
        automaticCleanupRetentionDays = 30
        isCleaningUp = false
    }
    
    func configureForSuccess() {
        shouldThrowError = false
    }
    
    func configureForError(_ error: Error) {
        shouldThrowError = true
        mockError = error
    }
    
    func configureForDelay(_ delay: TimeInterval) {
        shouldSimulateDelay = true
        delayDuration = delay
    }
}

// MARK: - Mock Error Types

enum MockCacheError: Error, LocalizedError {
    case cleanupError
    case refreshError
    case exportError
    
    var errorDescription: String? {
        switch self {
        case .cleanupError:
            return "Mock cache cleanup error"
        case .refreshError:
            return "Mock cache refresh error"
        case .exportError:
            return "Mock cache export error"
        }
    }
} 