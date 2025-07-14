import SwiftUI
import AVFoundation
import Combine
import os.log

/// Main coordinator ViewModel that manages specialized ViewModels and orchestrates photo booth workflow
@MainActor
final class RefactoredPhotoBoothViewModel: NSObject, ObservableObject {
    
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
    
    // MARK: - Computed Properties for UI Compatibility
    
    // Camera properties - delegate to CameraViewModel
    var isSessionRunning: Bool { cameraViewModel.isSessionRunning }
    var isCameraConnected: Bool { cameraViewModel.isCameraConnected }
    var availableCameras: [AVCaptureDevice] { cameraViewModel.availableCameras }
    var selectedCameraDevice: AVCaptureDevice? { cameraViewModel.selectedCameraDevice }
    var captureSession: AVCaptureSession? { cameraViewModel.getPreviewLayer()?.session }
    
    // Image processing properties - delegate to ImageProcessingViewModel
    var selectedTheme: PhotoTheme? { imageProcessingViewModel.selectedTheme }
    var isProcessing: Bool { imageProcessingViewModel.isProcessing }
    var lastCapturedImage: NSImage? { imageProcessingViewModel.lastCapturedImage }
    var lastThemedImage: NSImage? { imageProcessingViewModel.lastThemedImage }
    var themes: [PhotoTheme] { imageProcessingViewModel.themes }
    
    // UI state properties - delegate to UIStateViewModel
    var countdown: Int { uiStateViewModel.countdown }
    var isCountingDown: Bool { uiStateViewModel.isCountingDown }
    var errorMessage: String? { uiStateViewModel.errorMessage }
    var showError: Bool { uiStateViewModel.showError }
    var isReadyForNextPhoto: Bool { uiStateViewModel.isReadyForNextPhoto }
    var minimumDisplayTimeRemaining: Int { uiStateViewModel.minimumDisplayTimeRemaining }
    var isInMinimumDisplayPeriod: Bool { uiStateViewModel.isInMinimumDisplayPeriod }
    
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
            imageProcessingService: serviceCoordinator.imageProcessingService
        )
        self.uiStateViewModel = UIStateViewModel()
        
        super.init()
        
        setupViewModelDelegation()
        setupServiceCoordination()
        setupSlideshow()
        
        logger.info("RefactoredPhotoBoothViewModel initialized")
    }
    
    deinit {
        logger.info("RefactoredPhotoBoothViewModel deinitialized")
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
    
    /// Take a photo with the selected theme
    func takePhoto() {
        guard let theme = imageProcessingViewModel.selectedTheme else {
            uiStateViewModel.showError(message: "Please select a theme before taking a photo.")
            return
        }
        
        guard cameraViewModel.isReadyForCapture else {
            uiStateViewModel.showError(message: "Camera is not ready. Please check camera connection.")
            return
        }
        
        guard imageProcessingViewModel.isReadyForProcessing else {
            uiStateViewModel.showError(message: "Image processing service is not ready. Please check configuration.")
            return
        }
        
        logger.info("Starting photo capture workflow...")
        
        // Start countdown
        uiStateViewModel.startCountdown(duration: 3)
    }
    
    /// Select a theme for photo processing
    func selectTheme(_ theme: PhotoTheme) {
        logger.info("Selecting theme: \(theme.name)")
        
        // Auto-close slideshow when theme is selected
        if isSlideShowActive {
            logger.info("Theme selected during slideshow - closing slideshow first")
            stopSlideshow()
        }
        
        imageProcessingViewModel.selectTheme(theme)
    }
    
    /// Refresh available cameras
    func refreshAvailableCameras() async {
        await cameraViewModel.refreshAvailableCameras()
    }
    
    /// Select a specific camera device
    func selectCamera(_ device: AVCaptureDevice) async {
        await cameraViewModel.selectCamera(device)
    }
    
    /// Show error message to user
    func showError(message: String) {
        uiStateViewModel.showError(message: message)
    }
    
    // MARK: - Slideshow Methods (keeping existing functionality)
    
    func startSlideshow() {
        guard !isSlideShowActive else { return }
        logger.info("Starting slideshow...")
        
        isSlideShowActive = true
        slideShowViewModel?.startSlideshow()
    }
    
    func stopSlideshow() {
        guard isSlideShowActive else { return }
        logger.info("Stopping slideshow...")
        
        isSlideShowActive = false
        slideShowViewModel?.stopSlideshow()
    }
    
    func updateSlideShowDuration(_ duration: Double) {
        slideShowDisplayDuration = duration
        slideShowViewModel?.updateDisplayDuration(duration)
    }
    
    // MARK: - Private Methods
    
    private func setupViewModelDelegation() {
        // Set up camera view model delegation
        cameraViewModel.delegate = self
        
        // Set up image processing view model delegation
        imageProcessingViewModel.delegate = self
        
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
        logger.info("Countdown finished, capturing photo...")
        cameraViewModel.capturePhoto()
    }
    
    private func processPhoto(_ image: NSImage) async {
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

// MARK: - CameraViewModelDelegate
extension RefactoredPhotoBoothViewModel: CameraViewModelDelegate {
    
    func cameraViewModel(_ viewModel: CameraViewModel, didCapturePhoto image: NSImage) {
        logger.info("Photo captured, starting processing...")
        
        Task {
            await processPhoto(image)
        }
    }
    
    func cameraViewModel(_ viewModel: CameraViewModel, didFailWithError error: CameraViewModelError) {
        logger.error("Camera error: \(error.localizedDescription)")
        uiStateViewModel.showError(message: error.localizedDescription)
    }
}

// MARK: - ImageProcessingViewModelDelegate
extension RefactoredPhotoBoothViewModel: ImageProcessingViewModelDelegate {
    
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didSelectTheme theme: PhotoTheme) {
        logger.info("Theme selected in coordinator: \(theme.name)")
        // Theme selection is already handled by the ImageProcessingViewModel
    }
    
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didSaveOriginalImage path: URL) {
        logger.info("Original image saved, notifying projector...")
        
        // Notify projector to show original image immediately
        NotificationCenter.default.post(
            name: .photoCapture,
            object: nil,
            userInfo: [
                "original": path,
                "theme": viewModel.selectedTheme?.name ?? "Unknown"
            ]
        )
        
        // Notify projector that processing has started
        NotificationCenter.default.post(
            name: .processingStart,
            object: nil,
            userInfo: [
                "theme": viewModel.selectedTheme?.name ?? "Unknown"
            ]
        )
    }
    
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didCompleteProcessing result: ImageProcessingResult) {
        handleSuccessfulProcessing(result)
    }
    
    func imageProcessingViewModel(_ viewModel: ImageProcessingViewModel, didFailWithError error: ImageProcessingViewModelError) {
        handleProcessingError(error)
    }
} 