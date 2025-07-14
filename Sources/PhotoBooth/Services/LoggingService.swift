import Foundation
import os.log

/// Centralized logging service with consistent categories and levels
struct LoggingService {
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case app = "App"
        case camera = "Camera"
        case imageProcessing = "ImageProcessing"
        case openAI = "OpenAI"
        case ui = "UI"
        case slideshow = "Slideshow"
        case projector = "Projector"
        case configuration = "Configuration"
        case error = "Error"
        
        var logger: Logger {
            Logger(subsystem: "PhotoBooth", category: rawValue)
        }
    }
    
    // MARK: - Convenience Loggers
    static let app = Category.app.logger
    static let camera = Category.camera.logger
    static let imageProcessing = Category.imageProcessing.logger
    static let openAI = Category.openAI.logger
    static let ui = Category.ui.logger
    static let slideshow = Category.slideshow.logger
    static let projector = Category.projector.logger
    static let configuration = Category.configuration.logger
    static let error = Category.error.logger
    
    // MARK: - Emoji Constants for Visual Consistency
    struct Emoji {
        static let debug = "🔧"
        static let info = "ℹ️"
        static let warning = "⚠️"
        static let error = "❌"
        static let success = "✅"
        static let camera = "📸"
        static let projector = "📺"
        static let slideshow = "🎬"
        static let processing = "🎨"
        static let config = "⚙️"
        static let network = "🌐"
        static let timer = "⏰"
        static let display = "🖥️"
        static let connection = "🔗"
        static let refresh = "🔄"
        static let save = "💾"
    }
}

// MARK: - Global Logging Functions for Easy Migration
func logInfo(_ message: String, category: LoggingService.Category = .app) {
    category.logger.info("\(message)")
}

func logDebug(_ message: String, category: LoggingService.Category = .app) {
    category.logger.debug("\(message)")
}

func logWarning(_ message: String, category: LoggingService.Category = .app) {
    category.logger.warning("\(message)")
}

func logError(_ message: String, error: Error? = nil, category: LoggingService.Category = .error) {
    if let error = error {
        category.logger.error("\(message): \(error.localizedDescription)")
    } else {
        category.logger.error("\(message)")
    }
} 