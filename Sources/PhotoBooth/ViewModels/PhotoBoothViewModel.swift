import SwiftUI
import AVFoundation
import Combine
import os.log

/// Main coordinator ViewModel that manages specialized ViewModels and orchestrates photo booth workflow
@MainActor
final class PhotoBoothViewModel: NSObject, ObservableObject {
    
    // MARK: - Specialized ViewModels
    @Published var cameraViewModel: CameraViewModel
    @Published var imageProcessingViewModel: ImageProcessingViewModel
    @Published var uiStateViewModel: UIStateViewModel
    
    // MARK: - Service Coordinator
    private let serviceCoordinator: PhotoBoothServiceCoordinator
    
    // MARK: - Slideshow Properties (keeping existing slideshow logic)
    @Published var isSlideShowActive = false
    @Published var slideShowPhotoPairCount = 0
    @Published var slideShowDisplayDuration: Double = 5.0
    private var slideShowViewModel: SlideShowViewModel?
    private var slideShowWindowController: SlideShowWindowController?
    
    // MARK: - Configuration Status Properties
    var isOpenAIConfigured: Bool { serviceCoordinator.openAIService.isConfigured }
    var isThemeConfigurationLoaded: Bool { imageProcessingViewModel.isThemeConfigurationLoaded }
    
    // MARK: - Service Access Properties
    var configurationService: any ConfigurationServiceProtocol { serviceCoordinator.configurationService }
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "PhotoBooth", category: "MainCoordinator")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with default services and ViewModels
    override convenience init() {
        let serviceCoordinator = PhotoBoothServiceCoordinator()
        self.init(serviceCoordinator: serviceCoordinator)
    }
    
    /// Initialize with dependency injection support
    init(serviceCoordinator: PhotoBoothServiceCoordinator) {
        self.serviceCoordinator = serviceCoordinator
        
        // Initialize specialized ViewModels with services from coordinator
        self.cameraViewModel = CameraViewModel(cameraService: serviceCoordinator.cameraService)
        self.imageProcessingViewModel = ImageProcessingViewModel(
            openAIService: serviceCoordinator.openAIService,
            imageProcessingService: serviceCoordinator.imageProcessingService,
            themeConfigurationService: serviceCoordinator.themeConfigurationService
        )
        self.uiStateViewModel = UIStateViewModel()
        
        super.init()
        
        setupCombineBindings()
        setupServiceCoordination()
        setupSlideshow()
        
        // Initialize the photo booth system
        Task {
            await setupPhotoBoothSystem()
        }
        
        logger.info("PhotoBoothViewModel initialized")
    }
    
    deinit {
        logger.info("PhotoBoothViewModel deinitialized")
    }
    
    // MARK: - Public Methods
    
    /// Initialize the entire photo booth system
    func setupPhotoBoothSystem() async {
        logger.info("Setting up photo booth system...")
        
        // Initialize all services
        await serviceCoordinator.setupAllServices()
        
        // Setup camera system
        await cameraViewModel.setupCamera()
        
        logger.info("Photo booth system setup completed")
    }
    
    /// Start the complete photo capture workflow with countdown
    func startCapture() {
        logger.info("Starting photo capture workflow from PhotoBoothViewModel")
        
        guard imageProcessingViewModel.selectedTheme != nil else {
            uiStateViewModel.showError(message: "Please select a theme before taking a photo.")
            return
        }
        
        guard cameraViewModel.isCameraConnected else {
            uiStateViewModel.showError(message: "Camera not connected. Please check camera connection.")
            return
        }
        
        // Auto-close slideshow when photo capture starts
        if isSlideShowActive {
            logger.info("Auto-closing slideshow for photo capture")
            stopSlideshow()
        }
        
        // Start countdown which will trigger photo capture when complete
        uiStateViewModel.startCountdown(duration: 3)
    }
    
    /// Show error message to user
    func showError(message: String) {
        uiStateViewModel.showError(message: message)
    }
    
    // MARK: - Slideshow Methods (keeping existing functionality)
    
    func startSlideshow() async {
        guard !isSlideShowActive else { return }
        logger.info("Starting slideshow...")
        
        // Hide projector window first
        NotificationCenter.default.post(name: .hideProjectorForSlideshow, object: nil)
        
        // Create slideshow window controller if it doesn't exist
        if slideShowWindowController == nil {
            slideShowWindowController = SlideShowWindowController()
        }
        
        // Launch slideshow window
        if let slideShowViewModel = slideShowViewModel,
           let slideShowWindowController = slideShowWindowController {
            slideShowWindowController.launchSlideshow(with: slideShowViewModel)
        }
        
        isSlideShowActive = true
        await slideShowViewModel?.startSlideshow()
        
        logger.info("Slideshow started successfully")
    }
    
    func stopSlideshow() {
        guard isSlideShowActive else { return }
        logger.info("Stopping slideshow...")
        
        isSlideShowActive = false
        slideShowViewModel?.stopSlideshow()
        
        // Close slideshow window
        slideShowWindowController?.closeSlideshow()
        slideShowWindowController = nil
        
        // Restore projector window
        NotificationCenter.default.post(name: .restoreProjectorAfterSlideshow, object: nil)
        
        logger.info("Slideshow stopped successfully")
    }
    
    func updateSlideShowDuration(_ duration: Double) {
        slideShowDisplayDuration = duration
        slideShowViewModel?.updateDisplayDuration(duration)
    }
    
    // MARK: - Private Methods
    
    private func setupCombineBindings() {
        // Setup Combine-based communication instead of delegates
        
        // Forward specialized ViewModel changes to main ObservableObject
        cameraViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        imageProcessingViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        uiStateViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Setup camera capture handling
        setupCameraCaptureHandling()
        
        // Setup image processing handling
        setupImageProcessingHandling()
    }
    
    private func setupCameraCaptureHandling() {
        // Listen for camera capture events through publishers
        cameraViewModel.photoCapturedPublisher
            .sink { [weak self] image in
                Task { @MainActor in
                    await self?.handlePhotoCaptured(image)
                }
            }
            .store(in: &cancellables)
        
        cameraViewModel.cameraErrorPublisher
            .sink { [weak self] error in
                self?.handleCameraError(error)
            }
            .store(in: &cancellables)
        
        logger.info("Camera capture handling setup completed")
    }
    
    private func setupImageProcessingHandling() {
        // Listen for image processing events through publishers
        imageProcessingViewModel.themeSelectedPublisher
            .sink { [weak self] theme in
                self?.handleThemeSelected(theme)
            }
            .store(in: &cancellables)
        
        imageProcessingViewModel.originalImageSavedPublisher
            .sink { [weak self] path in
                self?.handleOriginalImageSaved(path)
            }
            .store(in: &cancellables)
        
        imageProcessingViewModel.processingCompletedPublisher
            .sink { [weak self] result in
                self?.handleSuccessfulProcessing(result)
            }
            .store(in: &cancellables)
        
        imageProcessingViewModel.processingErrorPublisher
            .sink { [weak self] error in
                self?.handleProcessingError(error)
            }
            .store(in: &cancellables)
        
        logger.info("Image processing handling setup completed")
    }
    
    // MARK: - Event Handlers
    
    private func handlePhotoCaptured(_ image: NSImage) async {
        logger.info("📸 Photo captured, starting processing...")
        logger.debug("📸 Captured image size: \(image.size.width) x \(image.size.height)")
        
        await processPhoto(image)
    }
    
    private func handleCameraError(_ error: CameraViewModelError) {
        logger.error("❌ Camera error: \(error.localizedDescription)")
        uiStateViewModel.showError(message: error.localizedDescription)
    }
    
    private func handleThemeSelected(_ theme: PhotoTheme) {
        logger.info("Theme selected in coordinator: \(theme.name)")
        
        // Auto-close slideshow when theme is selected
        if isSlideShowActive {
            logger.info("Theme selected during slideshow - closing slideshow first")
            stopSlideshow()
        }
        
        // Always return to live camera view when a new theme is selected
        // This gives the photo attendant control over when to return from the themed photo display
        if uiStateViewModel.isReadyForNextPhoto {
            logger.info("Theme selected - returning to live camera view")
            NotificationCenter.default.post(name: .returnToLiveCamera, object: nil)
        }
    }
    
    private func handleOriginalImageSaved(_ path: URL) {
        logger.info("Original image saved, notifying projector...")
        
        // Notify projector to show original image immediately
        NotificationCenter.default.post(
            name: .photoCapture,
            object: nil,
            userInfo: [
                "original": path,
                "theme": imageProcessingViewModel.selectedTheme?.name ?? "Unknown"
            ]
        )
        
        // Notify projector that processing has started
        NotificationCenter.default.post(
            name: .processingStart,
            object: nil,
            userInfo: [
                "theme": imageProcessingViewModel.selectedTheme?.name ?? "Unknown"
            ]
        )
    }
    
    private func setupServiceCoordination() {
        // Monitor service coordinator changes
        serviceCoordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Listen for countdown finished notification
        NotificationCenter.default.publisher(for: .countdownFinished)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleCountdownFinished()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSlideshow() {
        logger.info("Setting up slideshow components...")
        
        // Initialize slideshow view model
        slideShowViewModel = SlideShowViewModel()
        
        guard let slideShowViewModel = slideShowViewModel else { return }
        
        // Set up listeners for photo pair count updates
        slideShowViewModel.$photoPairs
            .sink { [weak self] pairs in
                Task { @MainActor in
                    self?.slideShowPhotoPairCount = pairs.count
                    self?.logger.debug("Slideshow photo pair count updated: \(pairs.count)")
                }
            }
            .store(in: &cancellables)
        
        // Set up listener for slideshow state changes
        slideShowViewModel.$isActive
            .sink { [weak self] active in
                Task { @MainActor in
                    if !active && self?.isSlideShowActive == true {
                        self?.logger.info("SlideShowViewModel became inactive, stopping slideshow")
                        self?.stopSlideshow()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Scan for existing photos
        Task {
            await slideShowViewModel.scanForPhotoPairs()
            logger.info("Initial slideshow photo scan completed")
        }
    }
    
    private func handleCountdownFinished() async {
        logger.info("⏰ Countdown finished, capturing photo...")
        cameraViewModel.capturePhoto()
    }
    
    private func processPhoto(_ image: NSImage) async {
        logger.info("🎨 ProcessPhoto called - starting image processing...")
        logger.debug("🎨 Selected theme: \(self.imageProcessingViewModel.selectedTheme?.name ?? "None")")
        logger.debug("🎨 OpenAI configured: \(self.imageProcessingViewModel.isReadyForProcessing)")
        
        // Log image dimensions for debugging
        imageProcessingViewModel.logImageDimensions(image, label: "Captured image")
        
        // Process the image with selected theme
        await imageProcessingViewModel.processImage(image)
    }
    
    private func handleSuccessfulProcessing(_ result: ImageProcessingResult) {
        logger.info("Photo processing completed successfully")
        
        // Show success message
        uiStateViewModel.showSuccess(message: "Photos saved to Pictures/booth folder!")
        
        // Start minimum display period
        uiStateViewModel.startMinimumDisplayPeriod()
        
        // Send notifications for projector display
        NotificationCenter.default.post(
            name: .photoCapture,
            object: nil,
            userInfo: [
                "original": result.originalPath,
                "theme": result.theme.name
            ]
        )
        
        NotificationCenter.default.post(
            name: .processingDone,
            object: nil,
            userInfo: [
                "theme": result.theme.name
            ]
        )
        
        NotificationCenter.default.post(
            name: .newPhotoCapture,
            object: nil,
            userInfo: [
                "original": result.originalPath,
                "themed": result.themedPath
            ]
        )
    }
    
    private func handleProcessingError(_ error: Error) {
        logger.error("Photo processing failed: \(error.localizedDescription)")
        
        // Show user-friendly error message
        let friendlyMessage = getFriendlyErrorMessage(for: error)
        uiStateViewModel.showError(message: friendlyMessage)
    }
    
    private func getFriendlyErrorMessage(for error: Error) -> String {
        if let processingError = error as? ImageProcessingViewModelError {
            return processingError.localizedDescription
        } else if let cameraError = error as? CameraViewModelError {
            return cameraError.localizedDescription
        } else {
            return "An unexpected error occurred. Please try again."
        }
    }
} 