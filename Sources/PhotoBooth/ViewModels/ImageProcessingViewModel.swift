import SwiftUI
import AppKit
import Combine
import os.log

/// ViewModel responsible for image processing, AI generation, and theme management
@MainActor
final class ImageProcessingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedTheme: PhotoTheme?
    @Published var isProcessing = false
    @Published var lastCapturedImage: NSImage?
    @Published var lastThemedImage: NSImage?
    @Published var processingProgress: Double = 0.0
    @Published var currentProcessingStep: ProcessingStep = .idle
    
    // MARK: - Private Properties
    private let openAIService: any OpenAIServiceProtocol
    private let imageProcessingService: any ImageProcessingServiceProtocol
    private let themeConfigurationService: ThemeConfigurationService
    private let logger = Logger(subsystem: "PhotoBooth", category: "ImageProcessing")
    private var cancellables = Set<AnyCancellable>()
    private var currentPhotoTimestamp: TimeInterval?
    
    // MARK: - Delegation
    weak var delegate: ImageProcessingViewModelDelegate?
    
    // MARK: - Computed Properties
    
    /// Available themes from configuration service
    var themes: [PhotoTheme] {
        themeConfigurationService.availableThemes
    }
    
    /// Themes grouped by category
    var themesByCategory: [String: [PhotoTheme]] {
        themeConfigurationService.themesByCategory
    }
    
    /// Available categories
    var availableCategories: [String] {
        themeConfigurationService.getAvailableCategories()
    }
    
    /// Theme configuration status
    var isThemeConfigurationLoaded: Bool {
        themeConfigurationService.isConfigured
    }
    
    // MARK: - Initialization
    init(
        openAIService: any OpenAIServiceProtocol,
        imageProcessingService: any ImageProcessingServiceProtocol,
        themeConfigurationService: ThemeConfigurationService
    ) {
        self.openAIService = openAIService
        self.imageProcessingService = imageProcessingService
        self.themeConfigurationService = themeConfigurationService
        
        setupServiceObservation()
        setupThemeConfigurationObservation()
    }
    
    // Convenience initializer for main actor context
    @MainActor
    convenience init() {
        self.init(
            openAIService: OpenAIService(),
            imageProcessingService: ImageProcessingService(),
            themeConfigurationService: ThemeConfigurationService()
        )
    }
    
    // MARK: - Public Methods
    
    /// Select a theme for processing
    func selectTheme(_ theme: PhotoTheme) {
        logger.info("Theme selected: \(theme.name)")
        selectedTheme = theme
        delegate?.imageProcessingViewModel(self, didSelectTheme: theme)
    }
    
    /// Clear theme selection
    func clearThemeSelection() {
        logger.info("Clearing theme selection")
        selectedTheme = nil
    }
    
    /// Process captured image with selected theme
    func processImage(_ image: NSImage) async {
        guard let theme = selectedTheme else {
            logger.error("No theme selected for processing")
            delegate?.imageProcessingViewModel(self, didFailWithError: ImageProcessingViewModelError.noThemeSelected)
            return
        }
        
        guard openAIService.isConfigured else {
            logger.error("OpenAI service not configured - check API key")
            delegate?.imageProcessingViewModel(self, didFailWithError: ImageProcessingViewModelError.serviceNotConfigured)
            return
        }
        
        logger.info("🎨 Starting image processing for theme: \(theme.name)")
        logger.debug("🎨 Image dimensions: \(image.size.width) x \(image.size.height)")
        logger.debug("🎨 OpenAI configured: \(self.openAIService.isConfigured)")
        
        // Setup processing state
        isProcessing = true
        lastCapturedImage = image
        currentPhotoTimestamp = Date().timeIntervalSince1970
        processingProgress = 0.0
        currentProcessingStep = .savingOriginal
        
        do {
            // Step 1: Save original image (20%)
            logger.info("Step 1: Saving original image...")
            let originalPath = try await imageProcessingService.saveOriginalImage(
                image, 
                timestamp: currentPhotoTimestamp!
            )
            processingProgress = 0.2
            
            // Notify delegate about original image saved
            delegate?.imageProcessingViewModel(self, didSaveOriginalImage: originalPath)
            
            // Step 2: Generate themed image (80%)
            currentProcessingStep = .generatingTheme
            logger.info("🎨 Step 2: Generating themed image...")
            
            let themedImage: NSImage
            do {
                themedImage = try await openAIService.generateThemedImage(from: image, theme: theme)
                lastThemedImage = themedImage
                processingProgress = 0.8
                logger.info("✅ Themed image generated successfully")
            } catch {
                logger.error("❌ OpenAI image generation failed: \(error.localizedDescription)")
                throw error
            }
            
            // Step 3: Save themed image (100%)
            currentProcessingStep = .savingThemed
            logger.info("Step 3: Saving themed image...")
            
            let themedPath = try await imageProcessingService.saveThemedImage(
                themedImage, 
                timestamp: currentPhotoTimestamp!
            )
            processingProgress = 1.0
            
            // Complete processing
            currentProcessingStep = .completed
            logger.info("Image processing completed successfully")
            
            // Notify delegate of successful completion
            delegate?.imageProcessingViewModel(
                self, 
                didCompleteProcessing: ImageProcessingResult(
                    originalImage: image,
                    themedImage: themedImage,
                    originalPath: originalPath,
                    themedPath: themedPath,
                    theme: theme,
                    timestamp: currentPhotoTimestamp!
                )
            )
            
            // Reset for next processing
            resetProcessingState()
            
        } catch {
            logger.error("Image processing failed: \(error.localizedDescription)")
            
            // Convert error to ViewModel error
            let viewModelError: ImageProcessingViewModelError
            if let openAIError = error as? OpenAIServiceError {
                viewModelError = .aiGenerationFailed(openAIError)
            } else if let imageError = error as? ImageProcessingError {
                viewModelError = .imageSaveFailed(imageError)
            } else {
                viewModelError = .unknownError(error)
            }
            
            delegate?.imageProcessingViewModel(self, didFailWithError: viewModelError)
            resetProcessingState()
        }
    }
    
    /// Check if ready for processing
    var isReadyForProcessing: Bool {
        return selectedTheme != nil && 
               openAIService.isConfigured && 
               !isProcessing
    }
    
    /// Get processing status summary
    func getProcessingStatusSummary() -> ProcessingStatusSummary {
        return ProcessingStatusSummary(
            selectedTheme: selectedTheme?.name,
            isProcessing: isProcessing,
            currentStep: currentProcessingStep,
            progress: processingProgress,
            isReadyForProcessing: isReadyForProcessing,
            openAIConfigured: openAIService.isConfigured
        )
    }
    
    /// Resize image for optimal processing
    func resizeImageForProcessing(_ image: NSImage) -> NSImage {
        // Crop to landscape 3:2 aspect ratio for API consistency
        let targetSize = CGSize(width: 1536, height: 1024)
        return imageProcessingService.resizeImage(image, to: targetSize)
    }
    
    /// Log image dimensions for debugging
    func logImageDimensions(_ image: NSImage, label: String) {
        imageProcessingService.logImageDimensions(image, label: label)
    }
    
    // MARK: - Private Methods
    
    private func setupServiceObservation() {
        // Monitor OpenAI service configuration changes using proper actor isolation
        logDebug("\(LoggingService.Emoji.connection) Setting up OpenAI service observation", category: .imageProcessing)
        
        // Note: Service observation temporarily simplified due to Swift 6 actor isolation
        // Services will notify state changes independently
        logDebug("\(LoggingService.Emoji.debug) Service observation configured for ImageProcessingViewModel", category: .imageProcessing)
        
        logDebug("\(LoggingService.Emoji.success) Service observation setup completed", category: .imageProcessing)
    }
    
    /// Set up theme configuration observation
    private func setupThemeConfigurationObservation() {
        logDebug("\(LoggingService.Emoji.config) Setting up theme configuration observation", category: .imageProcessing)
        
        // Observe theme configuration changes
        themeConfigurationService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe theme configuration updates
        NotificationCenter.default.publisher(for: .themeConfigurationUpdated)
            .sink { [weak self] _ in
                self?.handleThemeConfigurationUpdate()
            }
            .store(in: &cancellables)
        
        logDebug("\(LoggingService.Emoji.success) Theme configuration observation setup completed", category: .imageProcessing)
    }
    
    /// Handle theme configuration updates
    private func handleThemeConfigurationUpdate() {
        logger.info("Theme configuration updated - refreshing themes")
        
        // Clear current selection if the selected theme is no longer available
        if let selectedTheme = selectedTheme,
           !themeConfigurationService.availableThemes.contains(where: { $0.id == selectedTheme.id }) {
            logger.warning("Selected theme '\(selectedTheme.name)' is no longer available - clearing selection")
            clearThemeSelection()
        }
        
        // Notify delegate if no themes are available
        if !themeConfigurationService.isConfigured {
            delegate?.imageProcessingViewModel(self, didFailWithError: ImageProcessingViewModelError.serviceNotConfigured)
        }
    }
    
    private func resetProcessingState() {
        selectedTheme = nil
        currentPhotoTimestamp = nil
        isProcessing = false
        processingProgress = 0.0
        currentProcessingStep = .idle
    }
}

// MARK: - Supporting Types

/// Delegate protocol for image processing events
@MainActor
protocol ImageProcessingViewModelDelegate: AnyObject {
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didSelectTheme theme: PhotoTheme)
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didSaveOriginalImage path: URL)
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didCompleteProcessing result: ImageProcessingResult)
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didFailWithError error: ImageProcessingViewModelError)
}

/// Processing steps for UI feedback
enum ProcessingStep: String, CaseIterable {
    case idle = "Idle"
    case savingOriginal = "Saving Original"
    case generatingTheme = "Generating Theme"
    case savingThemed = "Saving Themed Image"
    case completed = "Completed"
    
    var description: String {
        switch self {
        case .idle:
            return "Ready to process"
        case .savingOriginal:
            return "Saving original photo..."
        case .generatingTheme:
            return "AI is creating your themed image..."
        case .savingThemed:
            return "Saving themed photo..."
        case .completed:
            return "Processing complete!"
        }
    }
    
    var icon: String {
        switch self {
        case .idle:
            return "photo"
        case .savingOriginal:
            return "square.and.arrow.down"
        case .generatingTheme:
            return "wand.and.stars"
        case .savingThemed:
            return "square.and.arrow.down.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
}

/// Result of successful image processing
struct ImageProcessingResult {
    let originalImage: NSImage
    let themedImage: NSImage
    let originalPath: URL
    let themedPath: URL
    let theme: PhotoTheme
    let timestamp: TimeInterval
}

/// Processing status summary for UI display
struct ProcessingStatusSummary {
    let selectedTheme: String?
    let isProcessing: Bool
    let currentStep: ProcessingStep
    let progress: Double
    let isReadyForProcessing: Bool
    let openAIConfigured: Bool
    
    var statusText: String {
        if isProcessing {
            return currentStep.description
        } else if !openAIConfigured {
            return "OpenAI service not configured"
        } else if selectedTheme == nil {
            return "Select a theme to continue"
        } else {
            return "Ready to process with \(selectedTheme!)"
        }
    }
    
    var statusIcon: String {
        if isProcessing {
            return currentStep.icon
        } else if !openAIConfigured {
            return "exclamationmark.triangle"
        } else if selectedTheme == nil {
            return "paintbrush"
        } else {
            return "checkmark.circle"
        }
    }
}

/// Image processing specific errors
enum ImageProcessingViewModelError: LocalizedError {
    case noThemeSelected
    case serviceNotConfigured
    case aiGenerationFailed(OpenAIServiceError)
    case imageSaveFailed(ImageProcessingError)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noThemeSelected:
            return "Please select a theme before taking a photo."
        case .serviceNotConfigured:
            return "AI service is not properly configured. Please check your API key."
        case .aiGenerationFailed(let error):
            return "AI generation failed: \(error.localizedDescription)"
        case .imageSaveFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noThemeSelected:
            return "Choose one of the available themes and try again."
        case .serviceNotConfigured:
            return "Check your .env file and ensure OPENAI_KEY is set correctly."
        case .aiGenerationFailed:
            return "Check your internet connection and try again."
        case .imageSaveFailed:
            return "Check disk space and file permissions."
        case .unknownError:
            return "Please try again or restart the application."
        }
    }
} 