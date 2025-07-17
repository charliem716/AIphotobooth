import Foundation
import Combine
import os.log

/// Main service coordinator that manages all PhotoBooth services
@MainActor
final class PhotoBoothServiceCoordinator: ObservableObject, PhotoBoothServiceCoordinatorProtocol {
    
        // MARK: - Services
    let configurationService: any ConfigurationServiceProtocol
    let networkService: any NetworkServiceProtocol
    let openAIService: any OpenAIServiceProtocol
    let cameraService: any CameraServiceProtocol  
    let imageProcessingService: any ImageProcessingServiceProtocol
    let cacheManagementService: any CacheManagementServiceProtocol
    let themeConfigurationService: ThemeConfigurationService
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var hasConfigurationErrors = false
    @Published var initializationProgress: Double = 0.0
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "PhotoBooth", category: "ServiceCoordinator")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with default services
    convenience init() {
        let configurationService = ConfigurationService.shared
        let networkService = NetworkService()
        
        self.init(
            configurationService: configurationService,
            networkService: networkService,
            openAIService: OpenAIService(
                configurationService: configurationService,
                networkService: networkService
            ),
            cameraService: CameraService(),
            imageProcessingService: ImageProcessingService(),
            cacheManagementService: CacheManagementService(),
            themeConfigurationService: ThemeConfigurationService()
        )
    }
    
    /// Initialize with dependency injection support
    init(
        configurationService: any ConfigurationServiceProtocol,
        networkService: any NetworkServiceProtocol,
        openAIService: any OpenAIServiceProtocol,
        cameraService: any CameraServiceProtocol,
        imageProcessingService: any ImageProcessingServiceProtocol,
        cacheManagementService: any CacheManagementServiceProtocol,
        themeConfigurationService: ThemeConfigurationService
    ) {
        self.configurationService = configurationService
        self.networkService = networkService
        self.openAIService = openAIService
        self.cameraService = cameraService
        self.imageProcessingService = imageProcessingService
        self.cacheManagementService = cacheManagementService
        self.themeConfigurationService = themeConfigurationService
        
        setupServiceObservation()
    }
    
    // MARK: - Public Methods
    
    /// Setup all services in the correct order
    func setupAllServices() async {
        logger.info("Starting service initialization...")
        initializationProgress = 0.0
        
        // Step 1: Validate configuration (20%)
        logger.info("Step 1/5: Validating configuration...")
        configurationService.validateConfiguration()
        initializationProgress = 0.2
        
        // Step 2: Setup network service (40%)
        logger.info("Step 2/5: Setting up network service...")
        // NetworkService is initialized and ready to use
        initializationProgress = 0.4
        
        // Step 3: Setup camera service (60%)
        logger.info("Step 3/5: Setting up camera service...")
        await cameraService.setupCamera()
        initializationProgress = 0.6
        
        // Step 4: Load theme configuration (80%)
        logger.info("Step 4/5: Loading theme configuration...")
        await themeConfigurationService.loadConfiguration()
        
        // Initialize cache management service
        await cacheManagementService.refreshCacheStatistics()
        initializationProgress = 0.8
        
        // Step 5: Verify OpenAI service and complete (100%)
        logger.info("Step 5/5: Verifying OpenAI service...")
        // OpenAI service is automatically configured via configuration service
        await validateServicesSetup()
        initializationProgress = 1.0
        
        isInitialized = true
        logger.info("Service initialization completed successfully")
    }
    
    /// Validate that all required services are properly configured
    func validateServicesConfiguration() -> Bool {
        let configValid = configurationService.isFullyConfigured
        let networkReady = true // NetworkService is always ready
        let cameraReady = cameraService.authorizationStatus == .authorized
        let openAIReady = openAIService.isConfigured
        let themesReady = themeConfigurationService.isConfigured
        let cacheReady = true // Cache management service is always ready
        
        logger.debug("Service validation - Config: \(configValid), Network: \(networkReady), Camera: \(cameraReady), OpenAI: \(openAIReady), Themes: \(themesReady), Cache: \(cacheReady)")
        
        return configValid && networkReady && cameraReady && openAIReady && themesReady && cacheReady
    }
    
    /// Get service status summary
    func getServiceStatusSummary() -> ServiceStatusSummary {
        return ServiceStatusSummary(
            configurationStatus: configurationService.isFullyConfigured ? .ready : .error,
            networkStatus: .ready, // NetworkService is always ready
            cameraStatus: getCameraStatus(),
            openAIStatus: openAIService.isConfigured ? .ready : .error,
            imageProcessingStatus: .ready, // Always ready since it's local
            themeConfigurationStatus: themeConfigurationService.isConfigured ? .ready : .error,
            overallStatus: validateServicesConfiguration() ? .ready : .error
        )
    }
    
    /// Restart all services
    func restartAllServices() async {
        logger.info("Restarting all services...")
        
        // Stop camera service
        cameraService.stopSession()
        
        // Reset state
        isInitialized = false
        hasConfigurationErrors = false
        
        // Restart setup
        await setupAllServices()
    }
    
    /// Handle configuration changes
    func handleConfigurationChange() async {
        logger.info("Configuration changed, updating services...")
        
        // Re-validate configuration
        configurationService.validateConfiguration()
        
        // Check if we need to restart services
        if !validateServicesConfiguration() {
            await restartAllServices()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupServiceObservation() {
        // Set up proper service observation using actor-isolated patterns
        logger.debug("Setting up service observation with actor isolation compliance")
        
        // Note: Cross-service observation temporarily simplified due to Swift 6 actor isolation
        // Individual services handle their own state management and notifications
        logger.debug("Service observation configured - services will update status independently")
        
        logger.info("Service observation setup completed successfully")
    }
    
    private func updateOverallStatus() {
        let newConfigurationErrors = !validateServicesConfiguration()
        if hasConfigurationErrors != newConfigurationErrors {
            hasConfigurationErrors = newConfigurationErrors
        }
    }
    
    private func getCameraStatus() -> ServiceStatus {
        switch cameraService.authorizationStatus {
        case .authorized:
            return cameraService.isCameraConnected ? .ready : .warning
        case .denied, .restricted:
            return .error
        case .notDetermined:
            return .pending
        @unknown default:
            return .error
        }
    }
    
    private func validateServicesSetup() async {
        // Perform any final validation or setup steps
        let allValid = validateServicesConfiguration()
        
        if !allValid {
            hasConfigurationErrors = true
            logger.warning("Service setup completed with configuration errors")
        } else {
            hasConfigurationErrors = false
            logger.info("All services configured and ready")
        }
    }
}

// MARK: - Supporting Types

/// Status of individual services
enum ServiceStatus {
    case pending
    case ready
    case warning
    case error
    
    var statusText: String {
        switch self {
        case .pending: return "Pending"
        case .ready: return "Ready"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
    
    var isOperational: Bool {
        switch self {
        case .ready, .warning: return true
        case .pending, .error: return false
        }
    }
}

/// Summary of all service statuses
struct ServiceStatusSummary {
    let configurationStatus: ServiceStatus
    let networkStatus: ServiceStatus
    let cameraStatus: ServiceStatus
    let openAIStatus: ServiceStatus
    let imageProcessingStatus: ServiceStatus
    let themeConfigurationStatus: ServiceStatus
    let overallStatus: ServiceStatus
    
    var isFullyOperational: Bool {
        return overallStatus.isOperational
    }
    
    var statusDescription: String {
        var description = "Service Status:\n"
        description += "• Configuration: \(configurationStatus.statusText)\n"
        description += "• Network: \(networkStatus.statusText)\n"
        description += "• Camera: \(cameraStatus.statusText)\n"
        description += "• OpenAI: \(openAIStatus.statusText)\n"
        description += "• Image Processing: \(imageProcessingStatus.statusText)\n"
        description += "• Theme Configuration: \(themeConfigurationStatus.statusText)\n"
        description += "• Overall: \(overallStatus.statusText)"
        return description
    }
} 