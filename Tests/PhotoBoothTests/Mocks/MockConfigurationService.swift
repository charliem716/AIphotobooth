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
    
    // MARK: - Keychain Mock Data
    var mockKeychainCredentials: [KeychainCredentialStore.CredentialKey: String] = [:]
    var mockStoreCredentialCallCount = 0
    var mockDeleteCredentialCallCount = 0
    var mockClearAllCallCount = 0
    var mockPerformMigrationCallCount = 0
    var mockMigrationResult = 0
    
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
    
    // MARK: - Keychain Management Methods
    
    func storeSecureCredential(_ credential: String, forKey key: KeychainCredentialStore.CredentialKey) -> Bool {
        mockStoreCredentialCallCount += 1
        guard !credential.isEmpty else { return false }
        
        mockKeychainCredentials[key] = credential
        
        // Update configuration based on stored credentials
        if key == .openAIKey {
            mockOpenAIKey = credential
        } else if key == .twilioSID {
            mockTwilioSID = credential
        } else if key == .twilioToken {
            mockTwilioToken = credential
        } else if key == .twilioFromNumber {
            mockTwilioFromNumber = credential
        }
        
        validateConfiguration()
        return true
    }
    
    func deleteSecureCredential(forKey key: KeychainCredentialStore.CredentialKey) -> Bool {
        mockDeleteCredentialCallCount += 1
        
        let wasPresent = mockKeychainCredentials[key] != nil
        mockKeychainCredentials.removeValue(forKey: key)
        
        // Update configuration based on deleted credentials
        if key == .openAIKey {
            mockOpenAIKey = nil
        } else if key == .twilioSID {
            mockTwilioSID = nil
        } else if key == .twilioToken {
            mockTwilioToken = nil
        } else if key == .twilioFromNumber {
            mockTwilioFromNumber = nil
        }
        
        validateConfiguration()
        return wasPresent
    }
    
    func getCredentialStatus() -> [KeychainCredentialStore.CredentialKey: CredentialStatus] {
        var status: [KeychainCredentialStore.CredentialKey: CredentialStatus] = [:]
        
        for key in KeychainCredentialStore.CredentialKey.allCases {
            if let credential = mockKeychainCredentials[key] {
                status[key] = CredentialStatus(
                    isStored: true,
                    length: credential.count,
                    source: .keychain
                )
            } else {
                status[key] = CredentialStatus(
                    isStored: false,
                    length: 0,
                    source: .none
                )
            }
        }
        
        return status
    }
    
    func clearAllCredentials() -> Bool {
        mockClearAllCallCount += 1
        
        mockKeychainCredentials.removeAll()
        mockOpenAIKey = nil
        mockTwilioSID = nil
        mockTwilioToken = nil
        mockTwilioFromNumber = nil
        
        validateConfiguration()
        return true
    }
    
    func performManualMigration() -> Int {
        mockPerformMigrationCallCount += 1
        return mockMigrationResult
    }
    
    // MARK: - Session Management Methods
    
    func getSessionCacheStatus() -> [KeychainCredentialStore.CredentialKey: Bool] {
        return KeychainCredentialStore.CredentialKey.allCases.reduce(into: [:]) { result, key in
            result[key] = mockKeychainCredentials[key] != nil
        }
    }
    
    func isKeychainSessionActive() -> Bool {
        return !mockKeychainCredentials.isEmpty
    }
    
    // MARK: - Biometric Authentication Methods
    
    func getBiometricCapability() -> BiometricCapability {
        return .faceID // Mock always returns Face ID for testing
    }
    
    func setBiometricAuthenticationEnabled(_ enabled: Bool) {
        // Mock implementation - could track this for testing
    }
    
    func isBiometricAuthenticationEnabled() -> Bool {
        return true // Mock always returns true for testing
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
        
        // Reset keychain mock data
        mockKeychainCredentials.removeAll()
        mockStoreCredentialCallCount = 0
        mockDeleteCredentialCallCount = 0
        mockClearAllCallCount = 0
        mockPerformMigrationCallCount = 0
        mockMigrationResult = 0
    }
    
    // MARK: - Keychain Mock Helpers
    
    func setMockKeychainCredential(_ credential: String, forKey key: KeychainCredentialStore.CredentialKey) {
        mockKeychainCredentials[key] = credential
        
        // Update configuration based on stored credentials
        if key == .openAIKey {
            mockOpenAIKey = credential
        } else if key == .twilioSID {
            mockTwilioSID = credential
        } else if key == .twilioToken {
            mockTwilioToken = credential
        } else if key == .twilioFromNumber {
            mockTwilioFromNumber = credential
        }
        
        validateConfiguration()
    }
    
    func setMockMigrationResult(_ result: Int) {
        mockMigrationResult = result
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