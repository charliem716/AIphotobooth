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
    private let networkService: NetworkServiceProtocol
    private let logger = Logger(subsystem: "PhotoBooth", category: "OpenAI")
    
    // MARK: - Published Properties
    @Published var isConfigured = false
    
    // MARK: - Initialization
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize with default configuration service
    convenience init() {
        self.init(
            configurationService: ConfigurationService.shared,
            networkService: NetworkService()
        )
    }
    
    /// Initialize with dependency injection
    init(
        configurationService: ConfigurationService,
        networkService: NetworkServiceProtocol
    ) {
        self.configService = configurationService
        self.networkService = networkService
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
        logger.info("🔧 Image quality: \(self.configService.getImageQuality())")
        
        do {
            logger.info("⏳ Preparing image for upload...")
            
            // Convert NSImage to JPEG data for the API
            guard let jpegData = try prepareImageData(from: image) else {
                throw OpenAIServiceError.imageConversionFailed
            }
            
            logger.debug("📸 Image data prepared: \(jpegData.count) bytes")
            
            // Create the theme-specific prompt
            let editPrompt = createEditPrompt(for: theme)
            logger.debug("📝 Edit prompt: \(editPrompt)")
            
            // Create multipart form data
            let formData = try createMultipartFormData(
                imageData: jpegData,
                prompt: editPrompt,
                model: "gpt-image-1",
                size: "1536x1024",
                quality: self.configService.getImageQuality()
            )
            
            logger.debug("📦 Multipart form data prepared: \(formData.body.count) bytes")
            
            // Build API URL
            let url = try buildAPIURL()
            logger.debug("🌐 API URL: \(url.absoluteString)")
            
            // Create headers
            let headers = [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "multipart/form-data; boundary=\(formData.boundary)"
            ]
            
            // Create network request
            let request = NetworkRequest(
                url: url,
                method: .POST,
                headers: headers,
                body: formData.body,
                timeout: 120.0 // 2 minute timeout for image generation
            )
            
            logger.info("📡 Sending request to OpenAI API...")
            
            // Use NetworkService with retry logic
            let response = try await networkService.performRequest(
                request,
                retryConfig: createRetryConfig()
            )
            
            logger.info("✅ API request successful, processing response...")
            
            // Parse and convert response to NSImage
            let editedImage = try parseImageResponse(response.data)
            
            logger.info("🎉 Successfully created themed image!")
            logger.debug("📊 Generated image size: \(editedImage.size.width) x \(editedImage.size.height)")
            logger.info("✅ AI image generation completed successfully for theme: \(theme.name)")
            logger.info("🏁 === PROCESSING COMPLETE ===")
            
            return editedImage
            
        } catch let error as NetworkError {
            logger.error("❌ Network error: \(error.localizedDescription)")
            throw mapNetworkError(error)
        } catch {
            logger.error("❌ AI generation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func prepareImageData(from image: NSImage) throws -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        
        // Check if image is within gpt-image-1 limits (50MB)
        let maxSize = 50 * 1024 * 1024  // 50MB in bytes
        if jpegData.count > maxSize {
            logger.error("❌ Image too large: \(jpegData.count) bytes (max: \(maxSize) bytes)")
            return nil
        }
        
        // Verify image data is valid
        if let testImage = NSImage(data: jpegData) {
            logger.debug("✅ JPEG data is valid, can create NSImage from it")
            logger.debug("📊 Test image size: \(testImage.size.width) x \(testImage.size.height)")
        } else {
            logger.error("❌ JPEG data is invalid, cannot create NSImage")
            return nil
        }
        
        return jpegData
    }
    
    private func createEditPrompt(for theme: PhotoTheme) -> String {
        return """
        Transform this photo into \(theme.name) style while preserving the exact same people, faces, poses, and composition from the original photo. \(theme.prompt)
        
        IMPORTANT: Keep all the people exactly as they appear in the original photo - same faces, same expressions, same positioning. Only change the art style, not the people or their appearance.
        """
    }
    
    private func createMultipartFormData(
        imageData: Data,
        prompt: String,
        model: String,
        size: String,
        quality: String
    ) throws -> (body: Data, boundary: String) {
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add model field
        body.append(multipartField(name: "model", value: model, boundary: boundary))
        
        // Add prompt field
        body.append(multipartField(name: "prompt", value: prompt, boundary: boundary))
        
        // Add size field
        body.append(multipartField(name: "size", value: size, boundary: boundary))
        
        // Add quality field
        body.append(multipartField(name: "quality", value: quality, boundary: boundary))
        
        // Add image field
        body.append(multipartFileField(
            name: "image",
            filename: "photo.jpg",
            contentType: "image/jpeg",
            data: imageData,
            boundary: boundary
        ))
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return (body, boundary)
    }
    
    private func multipartField(name: String, value: String, boundary: String) -> Data {
        var fieldData = Data()
        fieldData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        fieldData.append("\(value)\r\n".data(using: .utf8)!)
        return fieldData
    }
    
    private func multipartFileField(
        name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String
    ) -> Data {
        var fieldData = Data()
        fieldData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        fieldData.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        fieldData.append(data)
        fieldData.append("\r\n".data(using: .utf8)!)
        return fieldData
    }
    
    private func buildAPIURL() throws -> URL {
        let host = configService.getOpenAIHost()
        let port = configService.getOpenAIPort()
        let scheme = configService.getOpenAIScheme()
        
        guard let url = URL(string: "\(scheme)://\(host):\(port)/v1/images/edits") else {
            throw OpenAIServiceError.invalidURL("\(scheme)://\(host):\(port)/v1/images/edits")
        }
        
        return url
    }
    
    private func createRetryConfig() -> RetryConfiguration {
        return RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )
    }
    
    private func parseImageResponse(_ data: Data) throws -> NSImage {
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
        
        return editedImage
    }
    
    private func mapNetworkError(_ error: NetworkError) -> OpenAIServiceError {
        switch error {
        case .statusCode(let code, _):
            switch code {
            case 400:
                logger.error("❌ Bad request - check image format or prompt")
                return .invalidResponse
            case 401:
                logger.error("🔑 Authentication failed - check API key")
                return .serviceNotConfigured
            case 429:
                logger.error("⏳ Rate limit exceeded - too many requests")
                return .maxRetriesExceeded
            default:
                logger.error("❌ HTTP Status Code: \(code)")
                return .invalidResponse
            }
        case .timeout:
            logger.error("⏰ Request timed out - OpenAI API may be slow")
            return .generationFailed(error)
        case .networkUnavailable:
            logger.error("🌐 No internet connection")
            return .generationFailed(error)
        case .retryExhausted(let lastError):
            logger.error("💥 All retry attempts exhausted")
            return .generationFailed(lastError)
        default:
            logger.error("❓ Unknown network error: \(error.localizedDescription)")
            return .generationFailed(error)
        }
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
    case invalidURL(String)
    
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
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        }
    }
} 