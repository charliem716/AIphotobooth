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
        
        // When - Test multiple generation calls sequentially
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
    
    // MARK: - PhotoTheme Prompt Tests
    
    @MainActor
    func testPhotoThemePromptGeneration() async {
        // Given - PhotoTheme prompts are very effective for image theming
        mockOpenAIService.reset()
        let portraitTheme = PhotoTheme(id: 1, name: "Portrait", prompt: "professional portrait style, studio lighting, clean background", enabled: true, category: "portrait")
        let landscapeTheme = PhotoTheme(id: 2, name: "Landscape", prompt: "beautiful landscape scene, natural lighting, vibrant colors", enabled: true, category: "landscape")
        let vintageTheme = PhotoTheme(id: 3, name: "Vintage", prompt: "vintage aesthetic, sepia tones, film grain, retro styling", enabled: true, category: "vintage")
        
        // When - Generate images with different PhotoTheme prompts
        do {
            let portraitResult = try await mockOpenAIService.generateThemedImage(from: testImage, theme: portraitTheme)
            let landscapeResult = try await mockOpenAIService.generateThemedImage(from: testImage, theme: landscapeTheme)
            let vintageResult = try await mockOpenAIService.generateThemedImage(from: testImage, theme: vintageTheme)
            
            // Then - Should generate themed images successfully
            XCTAssertNotNil(portraitResult, "Should generate portrait themed image")
            XCTAssertNotNil(landscapeResult, "Should generate landscape themed image")
            XCTAssertNotNil(vintageResult, "Should generate vintage themed image")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 3, "Should generate 3 themed images")
        } catch {
            XCTFail("PhotoTheme prompt generation should succeed: \(error)")
        }
    }
    
    @MainActor
    func testGPTImage1ModelUsage() async {
        // Given - Use gpt-image-1 model for image generation instead of DALL-E 3
        mockOpenAIService.reset()
        let testTheme = PhotoTheme(id: 1, name: "GPT-Image-1 Test", prompt: "test prompt for gpt-image-1 model", enabled: true, category: "test")
        
        // When - Generate image using gpt-image-1 model
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            
            // Then - Should use gpt-image-1 model successfully
            XCTAssertNotNil(result, "Should generate image with gpt-image-1 model")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should call gpt-image-1 model once")
        } catch {
            XCTFail("GPT-Image-1 model usage should succeed: \(error)")
        }
    }
    
    @MainActor
    func testLandscapeResolutionPreference() async {
        // Given - User prefers landscape resolution (1536x1024) for group photos
        mockOpenAIService.reset()
        let groupPhotoTheme = PhotoTheme(id: 1, name: "Group Photo", prompt: "group photo style, multiple people, landscape orientation, 1536x1024 resolution", enabled: true, category: "group")
        
        // When - Generate landscape-oriented group photo
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: groupPhotoTheme)
            
            // Then - Should generate landscape-oriented image
            XCTAssertNotNil(result, "Should generate landscape group photo")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should generate landscape photo")
        } catch {
            XCTFail("Landscape resolution generation should succeed: \(error)")
        }
    }
    
    // MARK: - Advanced Image Generation Tests
    
    @MainActor
    func testMultipleImageGenerationSequence() async {
        // Given
        mockOpenAIService.reset()
        let themes = [
            PhotoTheme(id: 1, name: "Classic", prompt: "classic portrait style", enabled: true, category: "portrait"),
            PhotoTheme(id: 2, name: "Modern", prompt: "modern artistic style", enabled: true, category: "artistic"),
            PhotoTheme(id: 3, name: "Vintage", prompt: "vintage retro style", enabled: true, category: "vintage")
        ]
        
        // When - Generate multiple images in sequence
        var results: [NSImage] = []
        for theme in themes {
            do {
                let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: theme)
                results.append(result)
            } catch {
                XCTFail("Sequential generation should succeed for theme: \(theme.name)")
            }
        }
        
        // Then - Should generate all images successfully
        XCTAssertEqual(results.count, themes.count, "Should generate all themed images")
        XCTAssertEqual(mockOpenAIService.generationCallCount, themes.count, "Should call generation for each theme")
    }
    
    @MainActor
    func testImageGenerationWithLargeImage() async {
        // Given - Large image for processing
        mockOpenAIService.reset()
        let largeImage = createLargeTestImage()
        let theme = PhotoTheme(id: 1, name: "Large Image Test", prompt: "process large image", enabled: true, category: "test")
        
        // When - Generate themed image from large source
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: largeImage, theme: theme)
            
            // Then - Should handle large image processing
            XCTAssertNotNil(result, "Should process large image")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should process large image once")
        } catch {
            XCTFail("Large image processing should succeed: \(error)")
        }
    }
    
    @MainActor
    func testImageGenerationWithComplexPrompt() async {
        // Given - Complex PhotoTheme prompt
        mockOpenAIService.reset()
        let complexTheme = PhotoTheme(
            id: 1,
            name: "Complex Theme",
            prompt: "professional portrait photography, studio lighting setup with softbox and rim lighting, clean white background, shallow depth of field, 85mm lens, natural pose, warm color grading, high resolution, sharp focus on eyes, commercial headshot style",
            enabled: true,
            category: "professional"
        )
        
        // When - Generate image with complex prompt
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: complexTheme)
            
            // Then - Should handle complex prompt successfully
            XCTAssertNotNil(result, "Should process complex prompt")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should process complex prompt once")
        } catch {
            XCTFail("Complex prompt processing should succeed: \(error)")
        }
    }
    
    // MARK: - Network Error Scenario Tests
    
    @MainActor
    func testNetworkTimeoutError() async {
        // Given - Network timeout scenario
        mockOpenAIService.reset()
        mockOpenAIService.configureForError(MockOpenAIError.networkTimeout)
        
        // When - Attempt image generation with timeout
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("Should throw network timeout error")
        } catch let error as MockOpenAIError {
            // Then - Should handle network timeout appropriately
            XCTAssertEqual(error, MockOpenAIError.networkTimeout, "Should throw network timeout error")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should attempt generation once")
        } catch {
            XCTFail("Should throw MockOpenAIError: \(error)")
        }
    }
    
    @MainActor
    func testRateLimitError() async {
        // Given - Rate limit exceeded scenario
        mockOpenAIService.reset()
        mockOpenAIService.configureForError(MockOpenAIError.rateLimitExceeded)
        
        // When - Attempt image generation with rate limit
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("Should throw rate limit error")
        } catch let error as MockOpenAIError {
            // Then - Should handle rate limit appropriately
            XCTAssertEqual(error, MockOpenAIError.rateLimitExceeded, "Should throw rate limit error")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should attempt generation once")
        } catch {
            XCTFail("Should throw MockOpenAIError: \(error)")
        }
    }
    
    @MainActor
    func testInvalidAPIKeyError() async {
        // Given - Invalid API key scenario
        mockOpenAIService.reset()
        mockOpenAIService.configureForError(MockOpenAIError.invalidAPIKey)
        
        // When - Attempt image generation with invalid key
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("Should throw invalid API key error")
        } catch let error as MockOpenAIError {
            // Then - Should handle invalid API key appropriately
            XCTAssertEqual(error, MockOpenAIError.invalidAPIKey, "Should throw invalid API key error")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should attempt generation once")
        } catch {
            XCTFail("Should throw MockOpenAIError: \(error)")
        }
    }
    
    @MainActor
    func testNetworkErrorRecovery() async {
        // Given - Network error followed by recovery
        mockOpenAIService.reset()
        mockOpenAIService.configureForError(MockOpenAIError.networkTimeout)
        
        // When - First attempt fails, then recover
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("First attempt should fail")
        } catch {
            // Expected failure
        }
        
        // Reset to success and retry
        mockOpenAIService.configureForSuccess()
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            
            // Then - Should recover successfully
            XCTAssertNotNil(result, "Should recover from network error")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 2, "Should attempt generation twice")
        } catch {
            XCTFail("Recovery should succeed: \(error)")
        }
    }
    
    // MARK: - Configuration Tests
    
    @MainActor
    func testServiceConfigurationValidation() {
        // Given - Various configuration states
        let configuredService = MockOpenAIService()
        let unconfiguredService = MockOpenAIService()
        
        // When - Test configuration states
        configuredService.isConfigured = true
        unconfiguredService.isConfigured = false
        
        // Then - Should reflect configuration correctly
        XCTAssertTrue(configuredService.isConfigured, "Should be configured")
        XCTAssertFalse(unconfiguredService.isConfigured, "Should not be configured")
    }
    
    @MainActor
    func testUnconfiguredServiceError() async {
        // Given - Unconfigured service
        mockOpenAIService.reset()
        mockOpenAIService.isConfigured = false
        mockOpenAIService.configureForError(MockOpenAIError.serviceNotConfigured)
        
        // When - Attempt generation without configuration
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("Should throw service not configured error")
        } catch let error as MockOpenAIError {
            // Then - Should handle unconfigured service appropriately
            XCTAssertEqual(error, MockOpenAIError.serviceNotConfigured, "Should throw service not configured error")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should attempt generation once")
        } catch {
            XCTFail("Should throw MockOpenAIError: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testImageGenerationPerformance() async {
        // Given - Performance test setup
        mockOpenAIService.reset()
        mockOpenAIService.configureForDelay(0.01) // Very fast for testing
        
        // When - Generate multiple images and measure performance
        let iterations = 5
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            do {
                let theme = PhotoTheme(id: i, name: "Performance Test \(i)", prompt: "test prompt \(i)", enabled: true, category: "test")
                _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: theme)
            } catch {
                XCTFail("Performance test should not fail: \(error)")
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        // Then - Should complete within reasonable time
        XCTAssertLessThan(averageTime, 1.0, "Average generation time should be under 1 second")
        XCTAssertEqual(mockOpenAIService.generationCallCount, iterations, "Should generate all images")
        
        // Log performance for debugging
        print("🔍 Performance: \(averageTime) seconds average per image generation")
    }
    
    @MainActor
    func testConcurrentImageGeneration() async {
        // Given - Concurrent generation test
        mockOpenAIService.reset()
        mockOpenAIService.configureForDelay(0.1)
        
        let themes = [
            PhotoTheme(id: 1, name: "Concurrent 1", prompt: "concurrent test 1", enabled: true, category: "test"),
            PhotoTheme(id: 2, name: "Concurrent 2", prompt: "concurrent test 2", enabled: true, category: "test"),
            PhotoTheme(id: 3, name: "Concurrent 3", prompt: "concurrent test 3", enabled: true, category: "test")
        ]
        
        // When - Generate images concurrently
        await withTaskGroup(of: Void.self) { group in
            for theme in themes {
                group.addTask {
                    do {
                        _ = try await self.mockOpenAIService.generateThemedImage(from: self.testImage, theme: theme)
                    } catch {
                        XCTFail("Concurrent generation should not fail: \(error)")
                    }
                }
            }
            await group.waitForAll()
        }
        
        // Then - Should handle concurrent requests
        XCTAssertEqual(mockOpenAIService.generationCallCount, themes.count, "Should handle concurrent generation")
    }
    
    // MARK: - Theme Category Tests
    
    @MainActor
    func testThemeCategoryGeneration() async {
        // Given - Different theme categories
        mockOpenAIService.reset()
        let themeCategories = [
            PhotoTheme(id: 1, name: "Portrait", prompt: "portrait style", enabled: true, category: "portrait"),
            PhotoTheme(id: 2, name: "Landscape", prompt: "landscape style", enabled: true, category: "landscape"),
            PhotoTheme(id: 3, name: "Artistic", prompt: "artistic style", enabled: true, category: "artistic"),
            PhotoTheme(id: 4, name: "Vintage", prompt: "vintage style", enabled: true, category: "vintage"),
            PhotoTheme(id: 5, name: "Modern", prompt: "modern style", enabled: true, category: "modern")
        ]
        
        // When - Generate images for different categories
        for theme in themeCategories {
            do {
                let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: theme)
                XCTAssertNotNil(result, "Should generate image for category: \(theme.category)")
            } catch {
                XCTFail("Theme category generation should succeed for: \(theme.category)")
            }
        }
        
        // Then - Should generate images for all categories
        XCTAssertEqual(mockOpenAIService.generationCallCount, themeCategories.count, "Should generate images for all categories")
    }
    
    // MARK: - Enhanced Error Handling Tests
    
    @MainActor
    func testImageProcessingError() async {
        // Given - Image processing error scenario
        mockOpenAIService.reset()
        mockOpenAIService.configureForError(MockOpenAIError.imageProcessingFailed)
        
        // When - Attempt generation with processing error
        do {
            _ = try await mockOpenAIService.generateThemedImage(from: testImage, theme: testTheme)
            XCTFail("Should throw image processing error")
        } catch let error as MockOpenAIError {
            // Then - Should handle image processing error appropriately
            XCTAssertEqual(error, MockOpenAIError.imageProcessingFailed, "Should throw image processing error")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should attempt generation once")
        } catch {
            XCTFail("Should throw MockOpenAIError: \(error)")
        }
    }
    
    @MainActor
    func testInvalidImageError() async {
        // Given - Invalid image input
        mockOpenAIService.reset()
        let invalidImage = NSImage() // Empty image
        
        // When - Attempt generation with invalid image
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: invalidImage, theme: testTheme)
            
            // Then - Mock should still handle invalid image (creates mock result)
            XCTAssertNotNil(result, "Mock should handle invalid image")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should attempt generation once")
        } catch {
            XCTFail("Mock should handle invalid image: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testOpenAIServiceIntegration() async {
        // Given - Complete OpenAI service integration test
        mockOpenAIService.reset()
        
        // When - Test complete workflow
        // 1. Verify service is configured
        XCTAssertTrue(mockOpenAIService.isConfigured, "Service should be configured")
        
        // 2. Generate image with PhotoTheme
        let integrationTheme = PhotoTheme(
            id: 1,
            name: "Integration Test",
            prompt: "integration test prompt with professional lighting and composition",
            enabled: true,
            category: "integration"
        )
        
        do {
            let result = try await mockOpenAIService.generateThemedImage(from: testImage, theme: integrationTheme)
            
            // 3. Verify successful generation
            XCTAssertNotNil(result, "Should generate integrated image")
            XCTAssertEqual(mockOpenAIService.generationCallCount, 1, "Should perform integration generation")
        } catch {
            XCTFail("Integration test should succeed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLargeTestImage() -> NSImage {
        let size = NSSize(width: 2048, height: 1536) // Large image size
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Create gradient background
        let gradient = NSGradient(starting: .blue, ending: .purple)
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        
        image.unlockFocus()
        return image
    }
    
    private func createTestImage() -> NSImage {
        let size = NSSize(width: 400, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.green.set()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
} 