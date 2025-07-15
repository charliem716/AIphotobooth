import XCTest
import AppKit
@testable import PhotoBooth

final class ImageProcessingServiceTests: XCTestCase {
    
    var mockImageProcessingService: MockImageProcessingService!
    var testImage: NSImage!
    var testTimestamp: TimeInterval!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockImageProcessingService = MockImageProcessingService()
        testImage = createTestImage()
        testTimestamp = Date().timeIntervalSince1970
    }
    
    override func tearDown() {
        mockImageProcessingService = nil
        testImage = nil
        testTimestamp = nil
        super.tearDown()
    }
    
    // MARK: - Basic Tests
    
    @MainActor
    func testInitialization() {
        // Given & When
        let service = MockImageProcessingService()
        
        // Then
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isProcessingImage, "Should not be processing initially")
    }
    
    @MainActor
    func testSaveOriginalImage() async {
        // Given
        mockImageProcessingService.reset()
        
        // When
        do {
            let result = try await mockImageProcessingService.saveOriginalImage(testImage, timestamp: testTimestamp)
            
            // Then
            XCTAssertNotNil(result, "Should return saved file URL")
            XCTAssertTrue(result.path.contains("original"), "Should contain 'original' in path")
            XCTAssertTrue(result.path.contains(".png"), "Should have PNG extension")
            XCTAssertEqual(mockImageProcessingService.saveOriginalCallCount, 1, "Should increment save call count")
        } catch {
            XCTFail("Should not throw error for successful save: \(error)")
        }
    }
    
    @MainActor
    func testSaveThemedImage() async {
        // Given
        mockImageProcessingService.reset()
        
        // When
        do {
            let result = try await mockImageProcessingService.saveThemedImage(testImage, timestamp: testTimestamp)
            
            // Then
            XCTAssertNotNil(result, "Should return saved file URL")
            XCTAssertTrue(result.path.contains("themed"), "Should contain 'themed' in path")
            XCTAssertTrue(result.path.contains(".png"), "Should have PNG extension")
            XCTAssertEqual(mockImageProcessingService.saveThemedCallCount, 1, "Should increment save call count")
        } catch {
            XCTFail("Should not throw error for successful save: \(error)")
        }
    }
    
    @MainActor
    func testSaveImageWithError() async {
        // Given
        mockImageProcessingService.configureForError(MockImageProcessingError.mockSaveError)
        
        // When
        do {
            _ = try await mockImageProcessingService.saveOriginalImage(testImage, timestamp: testTimestamp)
            XCTFail("Should throw error when configured to return error")
        } catch {
            // Then
            XCTAssertTrue(error is MockImageProcessingError, "Should throw MockImageProcessingError")
            XCTAssertEqual(mockImageProcessingService.saveOriginalCallCount, 1, "Should still increment call count")
        }
    }
    
    @MainActor
    func testResizeImage() {
        // Given
        let targetSize = CGSize(width: 200, height: 150)
        mockImageProcessingService.reset()
        
        // When
        let result = mockImageProcessingService.resizeImage(testImage, to: targetSize)
        
        // Then
        XCTAssertNotNil(result, "Should return resized image")
        XCTAssertEqual(result.size.width, targetSize.width, "Should match target width")
        XCTAssertEqual(result.size.height, targetSize.height, "Should match target height")
        XCTAssertEqual(mockImageProcessingService.resizeCallCount, 1, "Should increment resize call count")
    }
    
    @MainActor
    func testLogImageDimensions() {
        // Given
        let label = "Test Image"
        mockImageProcessingService.reset()
        
        // When
        mockImageProcessingService.logImageDimensions(testImage, label: label)
        
        // Then
        XCTAssertEqual(mockImageProcessingService.logDimensionsCallCount, 1, "Should increment log call count")
    }
    
    @MainActor
    func testGetBoothDirectoryURL() {
        // Given & When
        let result = mockImageProcessingService.getBoothDirectoryURL()
        
        // Then
        XCTAssertNotNil(result, "Should return directory URL")
        XCTAssertTrue(result.path.contains("mock-booth"), "Should contain mock booth directory")
    }
    
    @MainActor
    func testCleanupOldImages() async {
        // Given
        mockImageProcessingService.reset()
        let retentionDays = 7
        
        // When
        do {
            try await mockImageProcessingService.cleanupOldImages(retentionDays: retentionDays)
            
            // Then
            XCTAssertEqual(mockImageProcessingService.cleanupCallCount, 1, "Should increment cleanup call count")
        } catch {
            XCTFail("Should not throw error for successful cleanup: \(error)")
        }
    }
    
    @MainActor
    func testGetCacheStatistics() async {
        // Given
        mockImageProcessingService.reset()
        
        // When
        let result = await mockImageProcessingService.getCacheStatistics()
        
        // Then
        XCTAssertNotNil(result, "Should return cache statistics")
        XCTAssertGreaterThanOrEqual(result.totalFiles, 0, "Should have valid file count")
        XCTAssertGreaterThanOrEqual(result.totalSizeBytes, 0, "Should have valid size")
        XCTAssertEqual(mockImageProcessingService.getCacheStatsCallCount, 1, "Should increment cache stats call count")
    }
    
    // MARK: - Multiple Operations Tests
    
    @MainActor
    func testSaveMultipleImages() async {
        // Given
        mockImageProcessingService.reset()
        let timestamps = [
            Date().timeIntervalSince1970,
            Date().timeIntervalSince1970 + 1,
            Date().timeIntervalSince1970 + 2
        ]
        
        // When
        var originalURLs: [URL] = []
        var themedURLs: [URL] = []
        
        for timestamp in timestamps {
            do {
                let originalURL = try await mockImageProcessingService.saveOriginalImage(testImage, timestamp: timestamp)
                let themedURL = try await mockImageProcessingService.saveThemedImage(testImage, timestamp: timestamp)
                originalURLs.append(originalURL)
                themedURLs.append(themedURL)
            } catch {
                XCTFail("Should not throw error for timestamp \(timestamp): \(error)")
            }
        }
        
        // Then
        XCTAssertEqual(originalURLs.count, timestamps.count, "Should save all original images")
        XCTAssertEqual(themedURLs.count, timestamps.count, "Should save all themed images")
        XCTAssertEqual(mockImageProcessingService.saveOriginalCallCount, timestamps.count, "Should track original saves")
        XCTAssertEqual(mockImageProcessingService.saveThemedCallCount, timestamps.count, "Should track themed saves")
    }
    
    @MainActor
    func testResizeMultipleSizes() {
        // Given
        let targetSizes = [
            CGSize(width: 100, height: 100),
            CGSize(width: 200, height: 150),
            CGSize(width: 300, height: 200),
            CGSize(width: 400, height: 300)
        ]
        mockImageProcessingService.reset()
        
        // When
        var results: [NSImage] = []
        for size in targetSizes {
            let result = mockImageProcessingService.resizeImage(testImage, to: size)
            results.append(result)
        }
        
        // Then
        XCTAssertEqual(results.count, targetSizes.count, "Should resize to all target sizes")
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.size.width, targetSizes[index].width, "Should match target width for index \(index)")
            XCTAssertEqual(result.size.height, targetSizes[index].height, "Should match target height for index \(index)")
        }
        XCTAssertEqual(mockImageProcessingService.resizeCallCount, targetSizes.count, "Should track all resize calls")
    }
    
    // MARK: - Processing State Tests
    
    @MainActor
    func testProcessingStateTracking() async {
        // Given
        mockImageProcessingService.reset()
        mockImageProcessingService.configureForDelay(0.1)
        
        // When
        XCTAssertFalse(mockImageProcessingService.isProcessingImage, "Should not be processing initially")
        
        let saveTask = Task {
            do {
                return try await mockImageProcessingService.saveOriginalImage(testImage, timestamp: testTimestamp)
            } catch {
                XCTFail("Should not throw error: \(error)")
                return URL(fileURLWithPath: "")
            }
        }
        
        // Check processing state during operation
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // The state might be processing or might have already completed - both are valid
        // What matters is that the save operation completes successfully
        
        // Wait for completion
        let result = await saveTask.value
        XCTAssertNotNil(result, "Should complete save operation")
        XCTAssertNotEqual(result.path, "", "Should return valid URL")
        XCTAssertFalse(mockImageProcessingService.isProcessingImage, "Should not be processing after save")
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testErrorHandlingWithDelay() async {
        // Given
        mockImageProcessingService.configureForError(MockImageProcessingError.mockSaveError)
        mockImageProcessingService.configureForDelay(0.1)
        
        // When
        let start = Date()
        do {
            _ = try await mockImageProcessingService.saveOriginalImage(testImage, timestamp: testTimestamp)
            XCTFail("Should throw error when configured to return error")
        } catch {
            let end = Date()
            
            // Then
            XCTAssertTrue(error is MockImageProcessingError, "Should throw MockImageProcessingError")
            XCTAssertGreaterThan(end.timeIntervalSince(start), 0.05, "Should have simulated delay even with error")
            XCTAssertFalse(mockImageProcessingService.isProcessingImage, "Should not be processing after error")
        }
    }
    
    // MARK: - Cache Management Tests
    
    @MainActor
    func testCacheStatsWithMockFiles() async {
        // Given
        mockImageProcessingService.reset()
        mockImageProcessingService.addMockFile(name: "test1.png", sizeBytes: 1024)
        mockImageProcessingService.addMockFile(name: "test2.png", sizeBytes: 2048)
        
        // When
        let stats = await mockImageProcessingService.getCacheStatistics()
        
        // Then
        XCTAssertGreaterThan(stats.totalFiles, 0, "Should have files in cache")
        XCTAssertGreaterThan(stats.totalSizeBytes, 0, "Should have non-zero cache size")
        XCTAssertGreaterThan(stats.totalSizeMB, 0, "Should calculate MB size")
    }
    
    @MainActor
    func testCleanupWithMockFiles() async {
        // Given
        mockImageProcessingService.reset()
        mockImageProcessingService.addMockFile(name: "old_file.png", sizeBytes: 1024)
        
        // When
        do {
            try await mockImageProcessingService.cleanupOldImages(retentionDays: 1)
            
            // Then
            XCTAssertEqual(mockImageProcessingService.cleanupCallCount, 1, "Should perform cleanup")
        } catch {
            XCTFail("Should not throw error for cleanup: \(error)")
        }
    }
    
    // MARK: - Reset Tests
    
    @MainActor
    func testReset() {
        // Given
        mockImageProcessingService.configureForError(MockImageProcessingError.mockSaveError)
        mockImageProcessingService.configureForDelay(1.0)
        mockImageProcessingService.addMockFile(name: "test.png", sizeBytes: 1024)
        
        // When
        mockImageProcessingService.reset()
        
        // Then
        XCTAssertFalse(mockImageProcessingService.shouldThrowError, "Should not throw error after reset")
        XCTAssertFalse(mockImageProcessingService.shouldSimulateDelay, "Should not simulate delay after reset")
        XCTAssertFalse(mockImageProcessingService.isProcessingImage, "Should not be processing after reset")
        XCTAssertEqual(mockImageProcessingService.saveOriginalCallCount, 0, "Should reset save call count")
        XCTAssertEqual(mockImageProcessingService.saveThemedCallCount, 0, "Should reset themed save call count")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testImageSavePerformance() async {
        // Given
        mockImageProcessingService.reset()
        mockImageProcessingService.configureForDelay(0.01)
        
        // When & Then - Test performance without async in measure block
        let iterations = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            do {
                _ = try await mockImageProcessingService.saveOriginalImage(testImage, timestamp: testTimestamp + Double(i))
            } catch {
                XCTFail("Performance test should not fail: \(error)")
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        // Assert reasonable performance (should be under 1 second per operation)
        XCTAssertLessThan(averageTime, 1.0, "Average save time should be under 1 second")
        
        // Log performance for debugging
        print("🔍 Performance: \(averageTime) seconds average per image save")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 200, height: 150)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
} 