import Foundation

// MARK: - PhotoTheme Model
struct PhotoTheme: Identifiable, Codable {
    let id: Int
    let name: String
    let prompt: String
    let enabled: Bool
    let category: String
    
    // For UI compatibility
    var isEnabled: Bool { enabled }
}

// MARK: - Theme Configuration Container
struct ThemeConfiguration: Codable {
    let version: String
    let themes: [PhotoTheme]
    
    var enabledThemes: [PhotoTheme] {
        themes.filter { $0.enabled }
    }
    
    var themesByCategory: [String: [PhotoTheme]] {
        Dictionary(grouping: enabledThemes) { $0.category }
    }
}

// MARK: - PhotoBooth Errors
enum PhotoBoothError: Error {
    case serviceNotConfigured
    case imageGenerationFailed
    case imageSaveFailed
    case cameraNotFound
    case themeConfigurationInvalid
    case themeConfigurationNotFound
    case noThemesAvailable
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let newPhotoCapture = Notification.Name("newPhotoCapture")
    static let themeConfigurationUpdated = Notification.Name("themeConfigurationUpdated")
}

// MARK: - AVCaptureDevice Extensions
import AVFoundation

extension AVCaptureDevice.Position {
    var description: String {
        switch self {
        case .back:
            return "Back"
        case .front:
            return "Front"
        case .unspecified:
            return "Unspecified"
        @unknown default:
            return "Unknown"
        }
    }
} 