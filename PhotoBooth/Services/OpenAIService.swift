import Foundation
import OpenAI
import AppKit
import os.log

/// Service responsible for OpenAI image generation operations
@MainActor
final class OpenAIService: ObservableObject, OpenAIServiceProtocol {
    
    // MARK: - Properties
    private var openAI: OpenAI?
    private let configService: ConfigurationService
    private let logger = Logger(subsystem: "PhotoBooth", category: "OpenAI")
    
    // MARK: - Published Properties
    @Published var isConfigured = false
    
    // MARK: - Initialization
    init(configurationService: ConfigurationService = .shared) {
        self.configService = configurationService
        setupOpenAI()
        
        // Listen for configuration changes
        configurationService.$isOpenAIConfigured
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConfigured in
                if isConfigured {
                    self?.setupOpenAI()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup
    private func setupOpenAI() {
        guard let apiKey = configService.getOpenAIKey(), !apiKey.isEmpty else {
            logger.warning("OpenAI API key not available")
            isConfigured = false
            return
        }
        
        openAI = OpenAI(apiToken: apiKey)
        isConfigured = true
        logger.info("OpenAI service configured successfully")
    }
    
    // MARK: - Public Methods
    
    /// Generate themed image from original image using OpenAI
    /// - Parameters:
    ///   - image: The original NSImage to transform
    ///   - theme: The PhotoTheme containing the transformation prompt
    /// - Returns: The generated themed NSImage
    /// - Throws: OpenAIServiceError for various failure cases
    func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage {
        guard let openAI = openAI else {
            logger.error("OpenAI service not configured")
            throw OpenAIServiceError.serviceNotConfigured
        }
        
        logger.info("Starting AI image generation for theme: \(theme.name)")
        
        // Convert NSImage to Data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            logger.error("Failed to convert image to PNG format")
            throw OpenAIServiceError.imageConversionFailed
        }
        
        // Create optimized prompt for image editing
        let editPrompt = """
                Transform this photo into \(theme.prompt).
                
                IMPORTANT: Keep all the people exactly as they appear in the original photo - same faces, same expressions, same positioning. Only change the art style, not the people or their appearance.
                """
        
        logger.debug("Using edit prompt: \(editPrompt)")
        
        do {
            // Perform image edit with retry logic
            let themedImage = try await performImageEditWithRetry(
                imageData: pngData,
                prompt: editPrompt,
                maxRetries: 3
            )
            
            logger.info("AI image generation completed successfully for theme: \(theme.name)")
            return themedImage
            
        } catch {
            logger.error("AI image generation failed: \(error.localizedDescription)")
            throw OpenAIServiceError.generationFailed(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func performImageEditWithRetry(
        imageData: Data,
        prompt: String,
        maxRetries: Int
    ) async throws -> NSImage {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                logger.debug("AI generation attempt \(attempt)/\(maxRetries)")
                return try await performImageEdit(imageData: imageData, prompt: prompt)
            } catch {
                lastError = error
                logger.warning("AI generation attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Progressive backoff: 2s, 4s, 8s
                    let delay = TimeInterval(2 * attempt)
                    logger.debug("Retrying in \(delay) seconds...")
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        
        throw lastError ?? OpenAIServiceError.maxRetriesExceeded
    }
    
    private func performImageEdit(imageData: Data, prompt: String) async throws -> NSImage {
        guard let apiKey = configService.getOpenAIKey() else {
            throw OpenAIServiceError.serviceNotConfigured
        }
        
        let host = configService.getOpenAIHost()
        let port = configService.getOpenAIPort()
        let scheme = configService.getOpenAIScheme()
        
        let url = URL(string: "\(scheme)://\(host):\(port)/v1/images/edits")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("gpt-image-1\r\n".data(using: .utf8)!)
        
        // Add prompt field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(prompt)\r\n".data(using: .utf8)!)
        
        // Add size field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
        body.append("1536x1024\r\n".data(using: .utf8)!)
        
        // Add image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            logger.error("OpenAI API error - Status: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("OpenAI API error response: \(errorString)")
            }
            throw OpenAIServiceError.apiError(httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstResult = dataArray.first,
              let urlString = firstResult["url"] as? String,
              let imageURL = URL(string: urlString) else {
            throw OpenAIServiceError.invalidResponseFormat
        }
        
        // Download the generated image
        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let themedImage = NSImage(data: imageData) else {
            throw OpenAIServiceError.imageCreationFailed
        }
        
        return themedImage
    }
}

// MARK: - Supporting Types
import Combine

/// Errors that can occur during OpenAI operations
enum OpenAIServiceError: LocalizedError {
    case serviceNotConfigured
    case imageConversionFailed
    case generationFailed(Error)
    case maxRetriesExceeded
    case invalidResponse
    case apiError(Int)
    case invalidResponseFormat
    case imageCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .serviceNotConfigured:
            return "OpenAI service is not properly configured. Please check your API key."
        case .imageConversionFailed:
            return "Failed to convert image for processing."
        case .generationFailed(let error):
            return "Image generation failed: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded for image generation."
        case .invalidResponse:
            return "Received invalid response from OpenAI API."
        case .apiError(let statusCode):
            return "OpenAI API error with status code: \(statusCode)"
        case .invalidResponseFormat:
            return "Unable to parse OpenAI API response."
        case .imageCreationFailed:
            return "Failed to create image from API response."
        }
    }
} 