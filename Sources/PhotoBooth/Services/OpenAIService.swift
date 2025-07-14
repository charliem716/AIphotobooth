import Foundation
import OpenAI
import AppKit
import os.log
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize with default configuration service
    convenience init() {
        self.init(configurationService: ConfigurationService.shared)
    }
    
    /// Initialize with dependency injection
    init(configurationService: ConfigurationService) {
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
    
    // MARK: - Setup
    private func setupOpenAI() {
        guard let apiKey = configService.getOpenAIKey(), !apiKey.isEmpty else {
            logger.warning("OpenAI API key not available")
            isConfigured = false
            return
        }
        
        openAI = OpenAI(apiToken: apiKey)
        isConfigured = true
        logger.info("✅ OpenAI service configured successfully")
        logger.debug("🔑 Using API key: \(String(apiKey.prefix(7)))...")
    }
    
    // MARK: - Public Methods
    
    /// Generate themed image from original image using OpenAI
    /// - Parameters:
    ///   - image: The original NSImage to transform
    ///   - theme: The PhotoTheme containing the transformation prompt
    /// - Returns: The generated themed NSImage
    /// - Throws: OpenAIServiceError for various failure cases
    func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage {
        guard let apiKey = configService.getOpenAIKey() else {
            logger.error("❌ OpenAI service not configured")
            throw OpenAIServiceError.serviceNotConfigured
        }
        
        logger.info("🚀 Starting AI image generation for theme: \(theme.name)")
        logger.debug("📊 Input image size: \(image.size.width) x \(image.size.height)")
        logger.info("🎯 Theme: \(theme.name)")
        logger.info("📝 Using prompt: \(theme.prompt)")
        logger.info("🤖 Using OpenAI model: gpt-image-1")
        logger.info("📐 Output size: 1536x1024 (high quality for party souvenirs)")
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            logger.info("🔄 === ATTEMPT \(attempt) of \(maxRetries) ===")
            do {
                logger.debug("🔄 AI generation attempt \(attempt)/\(maxRetries)")
                logger.info("⏳ Preparing image for upload...")
                
                // Convert NSImage to JPEG data for the API
                // Skip optimization for gpt-image-1 (supports up to 50MB)
                // Send full-size image for better quality
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    throw OpenAIServiceError.imageConversionFailed
                }
                
                logger.debug("📸 Full-size image data: \(jpegData.count) bytes")
                logger.debug("📸 Original image size: \(image.size.width) x \(image.size.height)")
                
                // Check if image is within gpt-image-1 limits (50MB)
                let maxSize = 50 * 1024 * 1024  // 50MB in bytes
                if jpegData.count > maxSize {
                    logger.error("❌ Image too large: \(jpegData.count) bytes (max: \(maxSize) bytes)")
                    throw OpenAIServiceError.imageConversionFailed
                }
                
                // Verify image data is valid
                if let testImage = NSImage(data: jpegData) {
                    logger.debug("✅ JPEG data is valid, can create NSImage from it")
                    logger.debug("📊 Test image size: \(testImage.size.width) x \(testImage.size.height)")
                } else {
                    logger.error("❌ JPEG data is invalid, cannot create NSImage")
                    throw OpenAIServiceError.imageConversionFailed
                }
                
                logger.debug("📸 Using direct image editing with GPT-image-1...")
                
                // Create the theme-specific prompt
                let editPrompt = """
                Transform this photo into \(theme.name) style while preserving the exact same people, faces, poses, and composition from the original photo. \(theme.prompt)
                
                IMPORTANT: Keep all the people exactly as they appear in the original photo - same faces, same expressions, same positioning. Only change the art style, not the people or their appearance.
                """
                
                logger.debug("📝 Edit prompt: \(editPrompt)")
                
                // Additional debug logging for prompt components
                logger.debug("🎭 Theme name: \(theme.name)")
                logger.debug("📝 Theme prompt: \(theme.prompt)")
                logger.debug("📏 Full edit prompt length: \(editPrompt.count) characters")
                
                // Direct API call for image editing
                let host = configService.getOpenAIHost()
                let port = configService.getOpenAIPort()
                let scheme = configService.getOpenAIScheme()
                
                let url = URL(string: "\(scheme)://\(host):\(port)/v1/images/edits")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 120  // 2 minute timeout
                
                // Create multipart form data
                let boundary = UUID().uuidString
                request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                var body = Data()
                
                // Add model field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
                body.append("gpt-image-1\r\n".data(using: .utf8)!)  // Use gpt-image-1 for image editing
                
                // Add prompt field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(editPrompt)\r\n".data(using: .utf8)!)
                
                // Add size field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
                body.append("1536x1024\r\n".data(using: .utf8)!)  // High quality for party souvenirs
                
                // Add image field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(jpegData)
                body.append("\r\n".data(using: .utf8)!)
                
                logger.debug("📦 Image field added to multipart form data")
                logger.debug("📦 Image data size in form: \(jpegData.count) bytes")
                
                // Close boundary
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                logger.debug("📦 Final multipart form data size: \(body.count) bytes")
                logger.debug("📦 Multipart boundary: \(boundary)")
                
                request.httpBody = body
                
                logger.info("📡 Sending request to OpenAI API...")
                logger.debug("🌐 API URL: \(url.absoluteString)")
                logger.debug("📦 Request body size: \(body.count) bytes")
                
                logger.debug("📡 Sending image edit request to OpenAI...")
                
                let (data, response): (Data, URLResponse)
                do {
                    logger.info("⏳ Waiting for OpenAI response...")
                    (data, response) = try await URLSession.shared.data(for: request)
                    logger.info("✅ Received response from OpenAI")
                } catch {
                    logger.error("❌ Network request failed")
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .timedOut:
                            logger.error("❌ Request timed out after 2 minutes")
                        case .notConnectedToInternet:
                            logger.error("❌ No internet connection")
                        case .networkConnectionLost:
                            logger.error("❌ Network connection lost")
                        case .cannotFindHost:
                            logger.error("❌ Cannot find host: \(host)")
                        default:
                            logger.error("❌ URLError: \(urlError.localizedDescription)")
                        }
                    } else {
                        logger.error("❌ Network error: \(error.localizedDescription)")
                    }
                    throw error
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("❌ Invalid response type from OpenAI API")
                    throw OpenAIServiceError.invalidResponse
                }
                
                logger.debug("📡 Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    logger.error("❌ OpenAI API returned error status: \(httpResponse.statusCode)")
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        logger.error("❌ API Error: \(errorData)")
                    }
                    logger.error("❌ HTTP Status Code: \(httpResponse.statusCode)")
                    logger.error("❌ Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")")
                    throw OpenAIServiceError.invalidResponse
                }
                
                logger.info("✅ API request successful, processing response...")
                
                // Parse response - gpt-image-1 always returns b64_json
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]],
                      let firstItem = dataArray.first,
                      let b64Json = firstItem["b64_json"] as? String else {
                    logger.error("❌ Failed to parse JSON response")
                    if let responseString = String(data: data, encoding: .utf8) {
                        logger.debug("📡 Response was: \(responseString.prefix(200))...")
                    }
                    throw OpenAIServiceError.invalidResponseFormat
                }
                
                logger.info("⏳ Converting base64 image data...")
                logger.debug("✅ Successfully parsed API response, got base64 image data")
                
                // Decode base64 image
                guard let imageData = Data(base64Encoded: b64Json),
                      let editedImage = NSImage(data: imageData) else {
                    logger.error("❌ Failed to decode base64 image data")
                    throw OpenAIServiceError.imageCreationFailed
                }
                
                logger.info("🎉 Successfully created themed image!")
                logger.debug("📊 Generated image size: \(editedImage.size.width) x \(editedImage.size.height)")
                logger.info("✅ AI image generation completed successfully for theme: \(theme.name)")
                logger.info("🏁 === PROCESSING COMPLETE ===")
                return editedImage
                
            } catch {
                lastError = error
                logger.error("❌ AI generation attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Log specific error types for better debugging
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        logger.error("⏰ Request timed out - OpenAI API may be slow")
                    case .notConnectedToInternet:
                        logger.error("🌐 No internet connection")
                    case .networkConnectionLost:
                        logger.error("📡 Network connection lost")
                    default:
                        logger.error("🔗 Network error: \(urlError.localizedDescription)")
                    }
                } else if error.localizedDescription.contains("400") {
                    logger.error("❌ Bad request - check image format or prompt")
                } else if error.localizedDescription.contains("401") {
                    logger.error("🔑 Authentication failed - check API key")
                } else if error.localizedDescription.contains("429") {
                    logger.error("⏳ Rate limit exceeded - too many requests")
                } else {
                    logger.error("❓ Unknown error: \(error.localizedDescription)")
                }
                
                if attempt < maxRetries {
                    let delay = Double(attempt) * 0.5  // Shorter delays: 0.5s, 1s, 1.5s
                    logger.info("🔄 Retrying in \(delay) seconds... (attempt \(attempt + 1)/\(maxRetries))")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    logger.error("💥 All attempts exhausted - giving up")
                }
            }
        }
        
        logger.error("❌ All \(maxRetries) attempts failed. Last error: \(lastError?.localizedDescription ?? "Unknown")")
        throw lastError ?? OpenAIServiceError.maxRetriesExceeded
    }
}

// MARK: - Error Types
enum OpenAIServiceError: Error, LocalizedError {
    case serviceNotConfigured
    case invalidResponse
    case imageConversionFailed
    case generationFailed(Error)
    case maxRetriesExceeded
    case invalidResponseFormat
    case imageCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .serviceNotConfigured:
            return "OpenAI service is not configured"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .imageConversionFailed:
            return "Failed to convert image data"
        case .generationFailed(let error):
            return "Image generation failed: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .invalidResponseFormat:
            return "Invalid response format from OpenAI API"
        case .imageCreationFailed:
            return "Failed to create image from response data"
        }
    }
} 