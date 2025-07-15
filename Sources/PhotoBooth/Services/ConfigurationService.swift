import Foundation
import os.log

/// Centralized configuration service for managing environment variables and API keys
@MainActor
final class ConfigurationService: ObservableObject, ConfigurationServiceProtocol {
    
    // MARK: - Singleton
    static let shared = ConfigurationService()
    
    // MARK: - Published Properties  
    @Published var isOpenAIConfigured = false
    @Published var isTwilioConfigured = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "PhotoBooth", category: "Configuration")
    private let keychainStore: KeychainCredentialStore
    
    // MARK: - Configuration Keys
    private enum ConfigKey: String {
        case openAIKey = "OPENAI_KEY"
        case twilioSID = "TWILIO_SID"
        case twilioToken = "TWILIO_TOKEN"
        case twilioFrom = "TWILIO_FROM"
        case openAIHost = "OPENAI_HOST"
        case openAIPort = "OPENAI_PORT"
        case openAIScheme = "OPENAI_SCHEME"
        case imageQuality = "IMAGE_QUALITY"
    }
    
    // MARK: - Initialization
    private init() {
        self.keychainStore = KeychainCredentialStore()
        
        // Perform automatic migration from environment to keychain
        performAutomaticMigration()
        
        // Skip credential preloading - use lazy loading instead
        // This avoids multiple password prompts during startup
        
        // Validate configuration after migration
        validateConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Get OpenAI API key (Keychain → Environment → nil)
    func getOpenAIKey() -> String? {
        return getSecureCredential(keychainKey: .openAIKey, envKey: .openAIKey)
    }
    
    /// Get Twilio Account SID (Keychain → Environment → nil)
    func getTwilioSID() -> String? {
        return getSecureCredential(keychainKey: .twilioSID, envKey: .twilioSID)
    }
    
    /// Get Twilio Auth Token (Keychain → Environment → nil)
    func getTwilioToken() -> String? {
        return getSecureCredential(keychainKey: .twilioToken, envKey: .twilioToken)
    }
    
    /// Get Twilio From Phone Number (Keychain → Environment → nil)
    func getTwilioFromNumber() -> String? {
        return getSecureCredential(keychainKey: .twilioFromNumber, envKey: .twilioFrom)
    }
    
    /// Get OpenAI Host (optional, defaults to api.openai.com)
    func getOpenAIHost() -> String {
        return getEnvironmentValue(for: .openAIHost) ?? "api.openai.com"
    }
    
    /// Get OpenAI Port (optional, defaults to 443)
    func getOpenAIPort() -> Int {
        guard let portString = getEnvironmentValue(for: .openAIPort),
              let port = Int(portString) else {
            return 443
        }
        return port
    }
    
    /// Get OpenAI Scheme (optional, defaults to https)
    func getOpenAIScheme() -> String {
        return getEnvironmentValue(for: .openAIScheme) ?? "https"
    }
    
    /// Get Image Quality Level (AppStorage → Environment → "high" default)
    func getImageQuality() -> String {
        // Check UserDefaults first (from AppStorage)
        if let userDefault = UserDefaults.standard.string(forKey: "imageQuality") {
            return userDefault
        }
        // Fall back to environment variable, then default
        return getEnvironmentValue(for: .imageQuality) ?? "high"
    }
    
    /// Validate and refresh configuration status
    func validateConfiguration() {
        logger.info("Validating configuration...")
        
        // Validate OpenAI configuration (check environment first to avoid keychain access)
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_KEY"], !envKey.isEmpty {
            logger.info("✅ OpenAI API key configured from Environment (length: \(envKey.count))")
            logger.debug("🔑 OpenAI key prefix: \(String(envKey.prefix(7)))...")
            isOpenAIConfigured = true
        } else {
            // For lazy loading, assume keychain might have it without checking
            // Actual keychain access will happen when getOpenAIKey() is called
            logger.info("🔍 OpenAI API key not in environment - will check keychain when needed")
            isOpenAIConfigured = false
        }
        
        // Validate Twilio configuration (check environment first to avoid keychain access)
        let hasSIDEnv = ProcessInfo.processInfo.environment["TWILIO_SID"]?.isEmpty == false
        let hasTokenEnv = ProcessInfo.processInfo.environment["TWILIO_TOKEN"]?.isEmpty == false
        let hasFromNumberEnv = ProcessInfo.processInfo.environment["TWILIO_FROM"]?.isEmpty == false
        
        isTwilioConfigured = hasSIDEnv && hasTokenEnv && hasFromNumberEnv
        
        if isTwilioConfigured {
            logger.info("✅ Twilio configuration complete from environment")
        } else {
            logger.info("🔍 Twilio configuration not complete in environment - will check keychain when needed")
        }
        
        // Skip credential status logging during initialization to avoid keychain prompts
        // logCredentialStatus()
        
        logger.info("Configuration validation complete - OpenAI: \(self.isOpenAIConfigured), Twilio: \(self.isTwilioConfigured)")
    }
    
    /// Check if all required services are configured
    var isFullyConfigured: Bool {
        return isOpenAIConfigured
        // Note: Excluding Twilio as requested in requirements
    }
    
    /// Get configuration status summary
    var configurationSummary: String {
        var summary = "Configuration Status:\n"
        summary += "• OpenAI: \(isOpenAIConfigured ? "✅ Configured" : "❌ Missing")\n"
        summary += "• Twilio: \(isTwilioConfigured ? "✅ Configured" : "❌ Missing")\n"
        summary += "\nCredential Storage:\n"
        
        let status = keychainStore.getCredentialStatus()
        for (key, credentialStatus) in status {
            summary += "• \(key.displayName): \(credentialStatus.description)\n"
        }
        
        summary += "\nSession Cache:\n"
        summary += "• Session Active: \(!keychainStore.getSessionCacheStatus().isEmpty ? "✅ Yes" : "❌ No")\n"
        
        let cacheStatus = keychainStore.getSessionCacheStatus()
        for (key, isCached) in cacheStatus {
            summary += "• \(key.displayName): \(isCached ? "✅ Cached" : "❌ Not Cached")\n"
        }
        
        return summary
    }
    
    // MARK: - Keychain Management
    
    /// Store a credential securely in the keychain
    /// - Parameters:
    ///   - credential: The credential value to store
    ///   - key: The credential key identifier
    /// - Returns: True if successful, false otherwise
    func storeSecureCredential(_ credential: String, forKey key: KeychainCredentialStore.CredentialKey) -> Bool {
        let success = keychainStore.store(key: key, value: credential)
        
        if success {
            logger.info("✅ Stored secure credential: \(key.displayName)")
        } else {
            logger.error("❌ Failed to store secure credential: \(key.displayName)")
        }
        
        return success
    }
    
    /// Delete a credential from the keychain
    /// - Parameter key: The credential key identifier
    /// - Returns: True if successful, false otherwise
    func deleteSecureCredential(forKey key: KeychainCredentialStore.CredentialKey) -> Bool {
        let success = keychainStore.delete(key: key)
        
        if success {
            // Refresh configuration after deletion
            validateConfiguration()
        }
        
        return success
    }
    
    /// Get credential status for all keys
    /// - Returns: Dictionary mapping credential keys to their status
    func getCredentialStatus() -> [KeychainCredentialStore.CredentialKey: KeychainCredentialStore.CredentialStatus] {
        return keychainStore.getCredentialStatus()
    }
    
    /// Clear all credentials from keychain
    /// - Returns: True if successful, false otherwise
    func clearAllCredentials() -> Bool {
        let success = keychainStore.clearAll()
        
        if success {
            // Refresh configuration after clearing
            validateConfiguration()
        }
        
        return success
    }
    
    /// Manually trigger migration from environment to keychain
    /// - Returns: Number of credentials successfully migrated
    func performManualMigration() -> Int {
        return performMigration(automatic: false)
    }
    
    /// Get session cache status for debugging
    /// - Returns: Dictionary showing which credentials are cached
    func getSessionCacheStatus() -> [KeychainCredentialStore.CredentialKey: Bool] {
        return keychainStore.getSessionCacheStatus()
    }
    
    /// Check if keychain session is active
    /// - Returns: True if user has authenticated during this session
    func isKeychainSessionActive() -> Bool {
        return !keychainStore.getSessionCacheStatus().isEmpty
    }
    
    /// Validate keychain credentials (may require password prompt)
    /// This method should be called when actually needed, not during initialization
    func validateKeychainCredentials() {
        logger.info("Validating keychain credentials...")
        
        // Check OpenAI key in keychain if not already configured from environment
        if !isOpenAIConfigured {
            if keychainStore.exists(key: .openAIKey) {
                logger.info("✅ OpenAI API key found in Keychain")
                isOpenAIConfigured = true
            } else {
                logger.warning("❌ OpenAI API key not found in Keychain or Environment")
            }
        }
        
        // Check Twilio credentials in keychain if not already configured from environment
        if !isTwilioConfigured {
            let hasSID = keychainStore.exists(key: .twilioSID)
            let hasToken = keychainStore.exists(key: .twilioToken)
            let hasFromNumber = keychainStore.exists(key: .twilioFromNumber)
            
            isTwilioConfigured = hasSID && hasToken && hasFromNumber
            
            if isTwilioConfigured {
                logger.info("✅ Twilio configuration complete from keychain")
            } else {
                logger.warning("❌ Twilio configuration incomplete - missing credentials in keychain")
            }
        }
        
        // Log credential status summary
        logCredentialStatus()
        
        logger.info("Keychain validation complete - OpenAI: \(self.isOpenAIConfigured), Twilio: \(self.isTwilioConfigured)")
    }
    
    // MARK: - Private Methods
    
    /// Get secure credential with priority: Keychain → Environment → nil
    private func getSecureCredential(
        keychainKey: KeychainCredentialStore.CredentialKey,
        envKey: ConfigKey
    ) -> String? {
        // Priority 1: Check keychain first
        if let keychainValue = keychainStore.retrieve(key: keychainKey) {
            return keychainValue
        }
        
        // Priority 2: Fall back to environment variable
        if let envValue = getEnvironmentValue(for: envKey) {
            logger.debug("🔄 Using environment fallback for \(keychainKey.displayName)")
            return envValue
        }
        
        // Priority 3: Not found
        return nil
    }
    
    /// Get environment variable value
    private func getEnvironmentValue(for key: ConfigKey) -> String? {
        return ProcessInfo.processInfo.environment[key.rawValue]
    }
    
    /// Perform automatic migration from environment to keychain
    private func performAutomaticMigration() {
        _ = performMigration(automatic: true)
    }
    
    /// Perform migration from environment to keychain
    /// - Parameter automatic: Whether this is an automatic migration
    /// - Returns: Number of credentials successfully migrated
    private func performMigration(automatic: Bool) -> Int {
        let migrationLabel = automatic ? "automatic" : "manual"
        logger.info("🔄 Starting \(migrationLabel) migration from environment to keychain")
        
        var migratedCount = 0
        
        // Define migration mappings
        let migrations: [(KeychainCredentialStore.CredentialKey, ConfigKey)] = [
            (.openAIKey, .openAIKey),
            (.twilioSID, .twilioSID),
            (.twilioToken, .twilioToken),
            (.twilioFromNumber, .twilioFrom)
        ]
        
        for (keychainKey, envKey) in migrations {
            if let envValue = getEnvironmentValue(for: envKey) {
                if keychainStore.migrateFromEnvironment(envValue, toKey: keychainKey) {
                    migratedCount += 1
                }
            }
        }
        
        if migratedCount > 0 {
            logger.info("✅ \(migrationLabel.capitalized) migration completed: \(migratedCount) credentials migrated")
        } else {
            logger.debug("🔄 \(migrationLabel.capitalized) migration: No credentials to migrate")
        }
        
        return migratedCount
    }
    
    /// Log detailed credential status
    private func logCredentialStatus() {
        logger.debug("📊 Credential Status Summary:")
        
        let status = keychainStore.getCredentialStatus()
        for (key, credentialStatus) in status {
            logger.debug("   • \(key.displayName): \(credentialStatus.description)")
        }
    }
}

// MARK: - Configuration Errors
enum ConfigurationError: LocalizedError {
    case missingOpenAIKey
    case missingTwilioCredentials
    case invalidConfiguration(String)
    case keychainStorageFailure(String)
    case migrationFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .missingOpenAIKey:
            return "OpenAI API key is missing. Please add it to your Keychain or .env file."
        case .missingTwilioCredentials:
            return "Twilio credentials are incomplete. Please add them to your Keychain or .env file."
        case .invalidConfiguration(let message):
            return "Configuration error: \(message)"
        case .keychainStorageFailure(let message):
            return "Keychain storage error: \(message)"
        case .migrationFailure(let message):
            return "Migration error: \(message)"
        }
    }
} 