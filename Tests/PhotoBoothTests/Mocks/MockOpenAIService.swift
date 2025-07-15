import Foundation
import AppKit
import Combine
@testable import PhotoBooth

/// Mock OpenAI Service for testing
@MainActor
final class MockOpenAIService: ObservableObject, OpenAIServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isConfigured = true
    
    // MARK: - Mock Configuration
    var shouldThrowError = false
    var shouldSimulateDelay = false
    var delayDuration: TimeInterval = 0.5
    var mockError: Error = MockOpenAIError.mockGenerationError
    var generationCallCount = 0
    
    // MARK: - OpenAIServiceProtocol
    
    func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage {
        generationCallCount += 1
        
        if shouldSimulateDelay {
            try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw mockError
        }
        
        // Return a mock themed image (copy of the original with some modifications)
        return createMockThemedImage(from: image, theme: theme)
    }
    
    // MARK: - Mock Helpers
    
    func reset() {
        shouldThrowError = false
        shouldSimulateDelay = false
        delayDuration = 0.5
        mockError = MockOpenAIError.mockGenerationError
        generationCallCount = 0
        isConfigured = true
    }
    
    func configureForError(_ error: Error) {
        shouldThrowError = true
        mockError = error
    }
    
    func configureForDelay(_ duration: TimeInterval) {
        shouldSimulateDelay = true
        delayDuration = duration
    }
    
    // MARK: - Private Methods
    
    private func createMockThemedImage(from originalImage: NSImage, theme: PhotoTheme) -> NSImage {
        let size = originalImage.size
        let mockImage = NSImage(size: size)
        
        mockImage.lockFocus()
        
        // Draw the original image
        originalImage.draw(in: NSRect(origin: .zero, size: size))
        
        // Add a colored overlay to simulate theme transformation
        let overlayColor = getThemeColor(for: theme)
        overlayColor.withAlphaComponent(0.3).set()
        NSRect(origin: .zero, size: size).fill(using: .multiply)
        
        // Add theme name text overlay
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -2
        ]
        
        let text = "MOCK: \(theme.name)"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        mockImage.unlockFocus()
        return mockImage
    }
    
    private func getThemeColor(for theme: PhotoTheme) -> NSColor {
        switch theme.category.lowercased() {
        case "anime":
            return NSColor.systemPink
        case "tv_cartoon":
            return NSColor.systemYellow
        case "art":
            return NSColor.systemPurple
        case "sci_fi":
            return NSColor.systemBlue
        default:
            return NSColor.systemGreen
        }
    }
}

// MARK: - Mock Error Types

enum MockOpenAIError: Error, LocalizedError {
    case mockGenerationError
    case mockConfigurationError
    case mockNetworkError
    case mockThemeNotSupported
    
    var errorDescription: String? {
        switch self {
        case .mockGenerationError:
            return "Mock image generation failed"
        case .mockConfigurationError:
            return "Mock configuration error"
        case .mockNetworkError:
            return "Mock network error"
        case .mockThemeNotSupported:
            return "Mock theme not supported"
        }
    }
} 