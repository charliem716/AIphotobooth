import Foundation
import os.log

/// Service responsible for loading and managing theme configurations
@MainActor
final class ThemeConfigurationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var themeConfiguration: ThemeConfiguration
    @Published var isLoading = false
    @Published var loadError: Error?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "PhotoBooth", category: "ThemeConfiguration")
    private let fileManager = FileManager.default
    private let themesFileName = "themes.json"
    
    // MARK: - Computed Properties
    
    /// Available themes (only enabled ones)
    var availableThemes: [PhotoTheme] {
        themeConfiguration.enabledThemes
    }
    
    /// Themes grouped by category
    var themesByCategory: [String: [PhotoTheme]] {
        themeConfiguration.themesByCategory
    }
    
    /// Configuration status
    var isConfigured: Bool {
        !availableThemes.isEmpty
    }
    
    /// Configuration summary for debugging
    var configurationSummary: String {
        """
        Theme Configuration:
        - Version: \(themeConfiguration.version)
        - Total themes: \(themeConfiguration.themes.count)
        - Enabled themes: \(availableThemes.count)
        - Categories: \(Set(availableThemes.map { $0.category }).sorted().joined(separator: ", "))
        """
    }
    
    // MARK: - Initialization
    
    init() {
        // Start with empty configuration
        self.themeConfiguration = ThemeConfiguration(version: "1.0", themes: [])
        
        // Load configuration on initialization
        Task {
            await loadConfiguration()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load theme configuration from JSON file
    func loadConfiguration() async {
        isLoading = true
        loadError = nil
        
        do {
            logger.info("Loading theme configuration from \(self.themesFileName)")
            
            // Try multiple approaches to find the themes.json file
            var configurationData: Data?
            
            // First try Bundle.module (SPM)
            if let resourceURL = Bundle.module.url(forResource: "themes", withExtension: "json") {
                configurationData = try? Data(contentsOf: resourceURL)
                logger.info("Found themes.json in Bundle.module")
            }
            // Fallback to Bundle.main (traditional app bundle)
            else if let resourcePath = Bundle.main.path(forResource: "themes", ofType: "json") {
                configurationData = fileManager.contents(atPath: resourcePath)
                logger.info("Found themes.json in Bundle.main")
            }
            // Last resort: try to find it in the current bundle
            else if let resourceURL = Bundle(for: type(of: self)).url(forResource: "themes", withExtension: "json") {
                configurationData = try? Data(contentsOf: resourceURL)
                logger.info("Found themes.json in current bundle")
            }
            
            guard let data = configurationData else {
                logger.warning("themes.json not found in any bundle, falling back to default themes")
                throw PhotoBoothError.themeConfigurationNotFound
            }
            
            // Parse JSON configuration
            let decoder = JSONDecoder()
            let loadedConfiguration = try decoder.decode(ThemeConfiguration.self, from: data)
            
            // Validate configuration
            try validateConfiguration(loadedConfiguration)
            
            // Update configuration
            themeConfiguration = loadedConfiguration
            
            logger.info("Successfully loaded \(loadedConfiguration.themes.count) themes (version: \(loadedConfiguration.version))")
            logger.info("Enabled themes: \(self.availableThemes.count)")
            
            // Notify observers
            NotificationCenter.default.post(name: .themeConfigurationUpdated, object: self)
            
        } catch {
            logger.error("Failed to load theme configuration: \(error.localizedDescription)")
            loadError = error
            
            // Fallback to default configuration
            loadDefaultConfiguration()
        }
        
        isLoading = false
    }
    
    /// Reload configuration (useful for dynamic updates)
    func reloadConfiguration() async {
        logger.info("Reloading theme configuration")
        await loadConfiguration()
    }
    
    /// Get theme by ID
    func getTheme(by id: Int) -> PhotoTheme? {
        return themeConfiguration.themes.first { $0.id == id }
    }
    
    /// Get enabled theme by ID
    func getEnabledTheme(by id: Int) -> PhotoTheme? {
        return availableThemes.first { $0.id == id }
    }
    
    /// Get themes by category
    func getThemes(in category: String) -> [PhotoTheme] {
        return themesByCategory[category] ?? []
    }
    
    /// Get available categories
    func getAvailableCategories() -> [String] {
        return Array(Set(availableThemes.map { $0.category })).sorted()
    }
    
    // MARK: - Private Methods
    
    /// Validate theme configuration
    private func validateConfiguration(_ configuration: ThemeConfiguration) throws {
        // Check version
        guard !configuration.version.isEmpty else {
            throw PhotoBoothError.themeConfigurationInvalid
        }
        
        // Check themes array
        guard !configuration.themes.isEmpty else {
            throw PhotoBoothError.noThemesAvailable
        }
        
        // Check for duplicate IDs
        let ids = configuration.themes.map { $0.id }
        let uniqueIds = Set(ids)
        guard ids.count == uniqueIds.count else {
            throw PhotoBoothError.themeConfigurationInvalid
        }
        
        // Validate each theme
        for theme in configuration.themes {
            try validateTheme(theme)
        }
        
        // Ensure at least one theme is enabled
        guard configuration.enabledThemes.count > 0 else {
            throw PhotoBoothError.noThemesAvailable
        }
        
        logger.info("Theme configuration validation passed")
    }
    
    /// Validate individual theme
    private func validateTheme(_ theme: PhotoTheme) throws {
        guard theme.id > 0 else {
            throw PhotoBoothError.themeConfigurationInvalid
        }
        
        guard !theme.name.isEmpty else {
            throw PhotoBoothError.themeConfigurationInvalid
        }
        
        guard !theme.prompt.isEmpty else {
            throw PhotoBoothError.themeConfigurationInvalid
        }
        
        guard !theme.category.isEmpty else {
            throw PhotoBoothError.themeConfigurationInvalid
        }
    }
    
    /// Load fallback default configuration
    private func loadDefaultConfiguration() {
        logger.warning("Loading fallback default theme configuration")
        
        let defaultThemes = [
            PhotoTheme(id: 1, name: "Studio Ghibli", prompt: "Transform this photo into Studio Ghibli anime style with soft watercolor backgrounds, whimsical characters, and magical atmosphere like Spirited Away or My Neighbor Totoro", enabled: true, category: "anime"),
            PhotoTheme(id: 2, name: "Simpsons", prompt: "Transform this photo into The Simpsons cartoon style with yellow skin, big eyes, overbite, and the iconic Springfield art style", enabled: true, category: "tv_cartoon"),
            PhotoTheme(id: 3, name: "Rick and Morty", prompt: "Transform this photo into Rick and Morty animation style with exaggerated features, drooling mouths, unibrows, and sci-fi elements", enabled: true, category: "tv_cartoon")
        ]
        
        themeConfiguration = ThemeConfiguration(version: "1.0-fallback", themes: defaultThemes)
        
        logger.info("Loaded fallback configuration with \(defaultThemes.count) themes")
    }
}

// MARK: - Error Extensions
extension PhotoBoothError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .serviceNotConfigured:
            return "Service not configured"
        case .imageGenerationFailed:
            return "Image generation failed"
        case .imageSaveFailed:
            return "Image save failed"
        case .cameraNotFound:
            return "Camera not found"
        case .themeConfigurationInvalid:
            return "Theme configuration is invalid"
        case .themeConfigurationNotFound:
            return "Theme configuration file not found"
        case .noThemesAvailable:
            return "No themes available"
        }
    }
} 