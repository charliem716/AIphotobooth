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
    
    // MARK: - Configuration Keys
    private enum ConfigKey: String {
        case openAIKey = "OPENAI_KEY"
        case twilioSID = "TWILIO_SID"
        case twilioToken = "TWILIO_TOKEN"
        case twilioFrom = "TWILIO_FROM"
        case openAIHost = "OPENAI_HOST"
        case openAIPort = "OPENAI_PORT"
        case openAIScheme = "OPENAI_SCHEME"
    }
    
    // MARK: - Initialization
    private init() {
        validateConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Get OpenAI API key
    func getOpenAIKey() -> String? {
        return getEnvironmentValue(for: .openAIKey)
    }
    
    /// Get Twilio Account SID
    func getTwilioSID() -> String? {
        return getEnvironmentValue(for: .twilioSID)
    }
    
    /// Get Twilio Auth Token
    func getTwilioToken() -> String? {
        return getEnvironmentValue(for: .twilioToken)
    }
    
    /// Get Twilio From Phone Number
    func getTwilioFromNumber() -> String? {
        return getEnvironmentValue(for: .twilioFrom)
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
    
    /// Validate and refresh configuration status
    func validateConfiguration() {
        logger.info("Validating configuration...")
        
        // Validate OpenAI configuration
        if let apiKey = getOpenAIKey(), !apiKey.isEmpty {
            logger.info("OpenAI API key configured (length: \(apiKey.count))")
            isOpenAIConfigured = true
        } else {
            logger.warning("OpenAI API key not found or empty")
            isOpenAIConfigured = false
        }
        
        // Validate Twilio configuration
        let hasSID = getTwilioSID()?.isEmpty == false
        let hasToken = getTwilioToken()?.isEmpty == false
        let hasFromNumber = getTwilioFromNumber()?.isEmpty == false
        
        isTwilioConfigured = hasSID && hasToken && hasFromNumber
        
        if isTwilioConfigured {
            logger.info("Twilio configuration complete")
        } else {
            logger.warning("Twilio configuration incomplete - missing SID, token, or from number")
        }
        
        logger.info("Configuration validation complete - OpenAI: \(isOpenAIConfigured), Twilio: \(isTwilioConfigured)")
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
        summary += "• Twilio: \(isTwilioConfigured ? "✅ Configured" : "❌ Missing")"
        return summary
    }
    
    // MARK: - Private Methods
    
    private func getEnvironmentValue(for key: ConfigKey) -> String? {
        return ProcessInfo.processInfo.environment[key.rawValue]
    }
}

// MARK: - Configuration Errors
enum ConfigurationError: LocalizedError {
    case missingOpenAIKey
    case missingTwilioCredentials
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .missingOpenAIKey:
            return "OpenAI API key is missing. Please add OPENAI_KEY to your .env file."
        case .missingTwilioCredentials:
            return "Twilio credentials are incomplete. Please add TWILIO_SID, TWILIO_TOKEN, and TWILIO_FROM to your .env file."
        case .invalidConfiguration(let message):
            return "Configuration error: \(message)"
        }
    }
} 