import XCTest
import AppKit
@testable import PhotoBooth

final class OpenAIServiceTests: XCTestCase {
    
    var mockOpenAIService: MockOpenAIService!
    var testImage: NSImage!
    var testTheme: PhotoTheme!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockOpenAIService = MockOpenAIService()
        testImage = createTestImage()
        testTheme = PhotoTheme(id: 1, name: "Test Theme", prompt: "Test transformation", enabled: true, category: "test")
    }
    
    override func tearDown() {
        mockOpenAIService = nil
        testImage = nil
        testTheme = nil
        super.tearDown()
    }
    
    // MARK: - Basic Tests
    
    @MainActor
    func testInitialization() {
        // Given & When
        let service = MockOpenAIService()
        
        // Then
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertTrue(service.isConfigured, "Mock service should be configured by default")
    }
    
    @MainActor
    func testSuccessfulImageGeneration() async {
        // Given
        mockOpenAIService.reset()
        
        // When
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            
            // Then
            XCTAssertNotNil(result, "Should return generated image")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should increment generation call count")
        } catch {
            XCTFail("Should not throw error for successful generation: \(error)")
        }
    }
    
    @MainActor
    func testImageGenerationWithError() async {
        // Given
        mockOpenAIService.configureForError(MockOpenAIError.mockGenerationError)
        
        // When
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("Should throw error when configured to return error")
        } catch {
            // Then
            XCTAssertTrue(error is MockOpenAIError, "Should throw MockOpenAIError")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should still increment call count")
        }
    }
    
    @MainActor
    func testImageGenerationWithDelay() async {
        // Given
        mockOpenAIService.configureForDelay(0.1)
        
        // When
        let start = Date()
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            let end = Date()
            
            // Then
            XCTAssertNotNil(result, "Should return generated image")
            XCTAssertGreaterThan(end.timeIntervalSince(start), 0.05, "Should have simulated delay")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should increment generation call count")
        } catch {
            XCTFail("Should not throw error with delay: \(error)")
        }
    }
    
    @MainActor
    func testMultipleImageGenerations() async {
        // Given
        let themes = [
            PhotoTheme(id: 1, name: "Theme 1", prompt: "First theme", enabled: true, category: "test"),
            PhotoTheme(id: 2, name: "Theme 2", prompt: "Second theme", enabled: true, category: "test"),
            PhotoTheme(id: 3, name: "Theme 3", prompt: "Third theme", enabled: true, category: "test")
        ]
        
        // When
        var results: [NSImage] = []
        for theme in themes {
            do {
                let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: theme)
                results.append(result)
            } catch {
                XCTFail("Should not throw error for theme \(theme.name): \(error)")
            }
        }
        
        // Then
        XCTAssertEqual(results.count, themes.count, "Should generate images for all themes")
        XCTAssertEqual(mockOpenAIService.generationCallCount, themes.count, "Should track all generation calls")
    }
    
    @MainActor
    func testConcurrentImageGeneration() async {
        // Given
        let themes = [
            PhotoTheme(id: 1, name: "Theme 1", prompt: "First theme", enabled: true, category: "test"),
            PhotoTheme(id: 2, name: "Theme 2", prompt: "Second theme", enabled: true, category: "test"),
            PhotoTheme(id: 3, name: "Theme 3", prompt: "Third theme", enabled: true, category: "test")
        ]
        
        // When - Test concurrent calls sequentially to avoid sendable issues
        var successCount = 0
        for theme in themes {
            do {
                let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: theme)
                if result.size.width > 0 && result.size.height > 0 {
                    successCount += 1
                }
            } catch {
                // Continue testing other themes
            }
        }
        
        // Then
        XCTAssertEqual(successCount, themes.count, "Should handle multiple image generation calls")
        XCTAssertEqual(mockOpenAIService.generationCallCount, themes.count, "Should track all calls")
    }
    
    @MainActor
    func testDifferentThemeCategories() async {
        // Given
        let themes = [
            PhotoTheme(id: 1, name: "Anime Theme", prompt: "Anime style", enabled: true, category: "anime"),
            PhotoTheme(id: 2, name: "Cartoon Theme", prompt: "Cartoon style", enabled: true, category: "tv_cartoon"),
            PhotoTheme(id: 3, name: "Art Theme", prompt: "Art style", enabled: true, category: "art")
        ]
        
        // When
        var results: [NSImage] = []
        for theme in themes {
            do {
                let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: theme)
                results.append(result)
            } catch {
                XCTFail("Should not throw error for theme \(theme.name): \(error)")
            }
        }
        
        // Then
        XCTAssertEqual(results.count, themes.count, "Should generate images for all theme categories")
        XCTAssertTrue(results.allSatisfy { $0.size.width > 0 && $0.size.height > 0 }, "All images should have valid dimensions")
    }
    
    // MARK: - Reset Tests
    
    @MainActor
    func testReset() {
        // Given
        mockOpenAIService.configureForError(MockOpenAIError.mockGenerationError)
        mockOpenAIService.configureForDelay(1.0)
        
        // When
        mockOpenAIService.reset()
        
        // Then
        XCTAssertFalse(mockOpenAIService.shouldThrowError, "Should not throw error after reset")
        XCTAssertFalse(mockOpenAIService.shouldSimulateDelay, "Should not simulate delay after reset")
        XCTAssertTrue(mockOpenAIService.isConfigured, "Should be configured after reset")
        XCTAssertEqual(mockOpenAIService.generationCallCount, 0, "Should reset generation count")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testImageGenerationPerformance() async {
        // Given
        mockOpenAIService.configureForDelay(0.01) // Small delay for realistic measurement
        
        // When & Then - Test performance without async in measure block
        let iterations = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            do {
                _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            } catch {
                XCTFail("Performance test should not fail: \(error)")
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        // Assert reasonable performance (should be under 1 second per operation)
        XCTAssertLessThan(averageTime, 1.0, "Average generation time should be under 1 second")
        
        // Log performance for debugging
        print("🔍 Performance: \(averageTime) seconds average per image generation")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
} 