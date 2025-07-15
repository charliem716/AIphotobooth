import Foundation
import Combine
@testable import PhotoBooth

/// Mock Configuration Service for testing
@MainActor
final class MockConfigurationService: ObservableObject, ConfigurationServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isOpenAIConfigured = false
    @Published var isTwilioConfigured = false
    
    // MARK: - Mock Data
    var mockOpenAIKey: String?
    var mockTwilioSID: String?
    var mockTwilioToken: String?
    var mockTwilioFromNumber: String?
    var mockOpenAIHost: String = "api.openai.com"
    var mockOpenAIPort: Int = 443
    var mockOpenAIScheme: String = "https"
    var mockValidationCallCount = 0
    
    // MARK: - ConfigurationServiceProtocol
    
    var isFullyConfigured: Bool {
        return isOpenAIConfigured
    }
    
    var configurationSummary: String {
        return "Mock Configuration Summary - OpenAI: \(isOpenAIConfigured), Twilio: \(isTwilioConfigured)"
    }
    
    func getOpenAIKey() -> String? {
        return mockOpenAIKey
    }
    
    func getTwilioSID() -> String? {
        return mockTwilioSID
    }
    
    func getTwilioToken() -> String? {
        return mockTwilioToken
    }
    
    func getTwilioFromNumber() -> String? {
        return mockTwilioFromNumber
    }
    
    func getOpenAIHost() -> String {
        return mockOpenAIHost
    }
    
    func getOpenAIPort() -> Int {
        return mockOpenAIPort
    }
    
    func getOpenAIScheme() -> String {
        return mockOpenAIScheme
    }
    
    func validateConfiguration() {
        mockValidationCallCount += 1
        isOpenAIConfigured = mockOpenAIKey != nil && !mockOpenAIKey!.isEmpty
        isTwilioConfigured = mockTwilioSID != nil && !mockTwilioSID!.isEmpty &&
                           mockTwilioToken != nil && !mockTwilioToken!.isEmpty &&
                           mockTwilioFromNumber != nil && !mockTwilioFromNumber!.isEmpty
    }
    
    // MARK: - Mock Helpers
    
    func setMockOpenAIKey(_ key: String?) {
        mockOpenAIKey = key
        validateConfiguration()
    }
    
    func setMockTwilioCredentials(sid: String?, token: String?, fromNumber: String?) {
        mockTwilioSID = sid
        mockTwilioToken = token
        mockTwilioFromNumber = fromNumber
        validateConfiguration()
    }
    
    func reset() {
        mockOpenAIKey = nil
        mockTwilioSID = nil
        mockTwilioToken = nil
        mockTwilioFromNumber = nil
        mockOpenAIHost = "api.openai.com"
        mockOpenAIPort = 443
        mockOpenAIScheme = "https"
        mockValidationCallCount = 0
        isOpenAIConfigured = false
        isTwilioConfigured = false
    }
}

/// Mock Configuration Service Error for testing
enum MockConfigurationServiceError: Error, LocalizedError {
    case mockMissingAPIKey
    case mockInvalidConfiguration
    case mockValidationError
    
    var errorDescription: String? {
        switch self {
        case .mockMissingAPIKey:
            return "Mock missing API key"
        case .mockInvalidConfiguration:
            return "Mock invalid configuration"
        case .mockValidationError:
            return "Mock validation error"
        }
    }
} 