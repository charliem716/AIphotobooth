import XCTest
@testable import PhotoBooth

final class ConfigurationServiceTests: XCTestCase {
    
    var mockConfigService: MockConfigurationService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockConfigService = MockConfigurationService()
    }
    
    override func tearDown() {
        mockConfigService = nil
        super.tearDown()
    }
    
    // MARK: - Basic Configuration Tests
    
    @MainActor
    func testInitialConfiguration() {
        // Given & When
        let service = MockConfigurationService()
        
        // Then
        XCTAssertNotNil(service, "Service should initialize")
        XCTAssertFalse(service.isOpenAIConfigured, "Should not be configured initially")
        XCTAssertFalse(service.isTwilioConfigured, "Should not be configured initially")
        XCTAssertFalse(service.isFullyConfigured, "Should not be fully configured initially")
        
        // Test keychain methods are available
        let status = service.getCredentialStatus()
        XCTAssertEqual(status.count, 4, "Should have status for all credential keys")
    }
    
    @MainActor
    func testOpenAIConfiguration() {
        // Given
        let apiKey = "sk-test-openai-key"
        
        // When
        mockConfigService.setMockOpenAIKey(apiKey)
        
        // Then
        XCTAssertEqual(mockConfigService.getOpenAIKey(), apiKey, "Should return OpenAI key")
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured")
        XCTAssertTrue(mockConfigService.isFullyConfigured, "Should be fully configured")
    }
    
    @MainActor
    func testTwilioConfiguration() {
        // Given
        let sid = "test-sid"
        let token = "test-token"
        let fromNumber = "+1234567890"
        
        // When
        mockConfigService.setMockTwilioCredentials(sid: sid, token: token, fromNumber: fromNumber)
        
        // Then
        XCTAssertEqual(mockConfigService.getTwilioSID(), sid, "Should return Twilio SID")
        XCTAssertEqual(mockConfigService.getTwilioToken(), token, "Should return Twilio token")
        XCTAssertEqual(mockConfigService.getTwilioFromNumber(), fromNumber, "Should return Twilio from number")
        XCTAssertTrue(mockConfigService.isTwilioConfigured, "Should be configured")
    }
    
    @MainActor
    func testMissingConfiguration() {
        // Given
        mockConfigService.setMockOpenAIKey(nil)
        
        // When
        let openAIKey = mockConfigService.getOpenAIKey()
        
        // Then
        XCTAssertNil(openAIKey, "Should return nil when not configured")
        XCTAssertFalse(mockConfigService.isOpenAIConfigured, "Should not be configured")
        XCTAssertFalse(mockConfigService.isFullyConfigured, "Should not be fully configured")
    }
    
    @MainActor
    func testEmptyConfiguration() {
        // Given
        mockConfigService.setMockOpenAIKey("")
        
        // When & Then
        XCTAssertFalse(mockConfigService.isOpenAIConfigured, "Should not be configured with empty key")
        XCTAssertFalse(mockConfigService.isFullyConfigured, "Should not be fully configured with empty key")
    }
    
    @MainActor
    func testValidationCallCount() {
        // Given
        let initialCallCount = mockConfigService.mockValidationCallCount
        
        // When
        mockConfigService.setMockOpenAIKey("test-key")
        
        // Then
        XCTAssertEqual(mockConfigService.mockValidationCallCount, initialCallCount + 1, "Should increment validation call count")
    }
    
    // MARK: - Host/Port/Scheme Tests
    
    @MainActor
    func testDefaultHostPortScheme() {
        // Given & When
        let host = mockConfigService.getOpenAIHost()
        let port = mockConfigService.getOpenAIPort()
        let scheme = mockConfigService.getOpenAIScheme()
        
        // Then
        XCTAssertEqual(host, "api.openai.com", "Should return default host")
        XCTAssertEqual(port, 443, "Should return default port")
        XCTAssertEqual(scheme, "https", "Should return default scheme")
    }
    
    @MainActor
    func testCustomHostPortScheme() {
        // Given
        mockConfigService.mockOpenAIHost = "custom.host.com"
        mockConfigService.mockOpenAIPort = 8080
        mockConfigService.mockOpenAIScheme = "http"
        
        // When
        let host = mockConfigService.getOpenAIHost()
        let port = mockConfigService.getOpenAIPort()
        let scheme = mockConfigService.getOpenAIScheme()
        
        // Then
        XCTAssertEqual(host, "custom.host.com", "Should return custom host")
        XCTAssertEqual(port, 8080, "Should return custom port")
        XCTAssertEqual(scheme, "http", "Should return custom scheme")
    }
    
    // MARK: - Configuration Summary Tests
    
    @MainActor
    func testConfigurationSummary() {
        // Given
        mockConfigService.setMockOpenAIKey("test-key")
        
        // When
        let summary = mockConfigService.configurationSummary
        
        // Then
        XCTAssertFalse(summary.isEmpty, "Should return non-empty summary")
        XCTAssertTrue(summary.contains("OpenAI"), "Should contain OpenAI info")
        XCTAssertTrue(summary.contains("Twilio"), "Should contain Twilio info")
    }
    
    // MARK: - Reset Tests
    
    @MainActor
    func testReset() {
        // Given
        mockConfigService.setMockOpenAIKey("test-key")
        mockConfigService.setMockTwilioCredentials(sid: "test-sid", token: "test-token", fromNumber: "+1234567890")
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured before reset")
        
        // When
        mockConfigService.reset()
        
        // Then
        XCTAssertFalse(mockConfigService.isOpenAIConfigured, "Should not be configured after reset")
        XCTAssertFalse(mockConfigService.isTwilioConfigured, "Should not be configured after reset")
        XCTAssertFalse(mockConfigService.isFullyConfigured, "Should not be fully configured after reset")
        XCTAssertNil(mockConfigService.getOpenAIKey(), "Should return nil after reset")
        XCTAssertNil(mockConfigService.getTwilioSID(), "Should return nil after reset")
        XCTAssertEqual(mockConfigService.mockValidationCallCount, 0, "Should reset validation count")
    }
    
    // MARK: - Complex Configuration Tests
    
    @MainActor
    func testFullConfigurationWorkflow() {
        // Given
        XCTAssertFalse(mockConfigService.isFullyConfigured, "Should start unconfigured")
        
        // When - Configure OpenAI
        mockConfigService.setMockOpenAIKey("sk-test-key")
        
        // Then
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be OpenAI configured")
        XCTAssertTrue(mockConfigService.isFullyConfigured, "Should be fully configured")
        
        // When - Configure Twilio
        mockConfigService.setMockTwilioCredentials(sid: "test-sid", token: "test-token", fromNumber: "+1234567890")
        
        // Then
        XCTAssertTrue(mockConfigService.isTwilioConfigured, "Should be Twilio configured")
        XCTAssertTrue(mockConfigService.isFullyConfigured, "Should still be fully configured")
    }
    
    @MainActor
    func testPartialTwilioConfiguration() {
        // Given
        mockConfigService.setMockTwilioCredentials(sid: "test-sid", token: nil, fromNumber: "+1234567890")
        
        // When & Then
        XCTAssertFalse(mockConfigService.isTwilioConfigured, "Should not be configured with missing token")
        
        // When - Add missing token
        mockConfigService.setMockTwilioCredentials(sid: "test-sid", token: "test-token", fromNumber: "+1234567890")
        
        // Then
        XCTAssertTrue(mockConfigService.isTwilioConfigured, "Should be configured with all credentials")
    }
    
    @MainActor
    func testConfigurationValidation() {
        // Given
        let initialCallCount = mockConfigService.mockValidationCallCount
        
        // When
        mockConfigService.validateConfiguration()
        
        // Then
        XCTAssertEqual(mockConfigService.mockValidationCallCount, initialCallCount + 1, "Should increment validation count")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testConfigurationPerformance() {
        // Given
        let apiKey = "sk-test-performance-key"
        
        // When & Then
        measure {
            mockConfigService.setMockOpenAIKey(apiKey)
            _ = mockConfigService.getOpenAIKey()
            _ = mockConfigService.isOpenAIConfigured
            _ = mockConfigService.isFullyConfigured
        }
    }
    
    // MARK: - Edge Cases
    
    @MainActor
    func testVeryLongApiKey() {
        // Given
        let longKey = String(repeating: "a", count: 10000)
        
        // When
        mockConfigService.setMockOpenAIKey(longKey)
        
        // Then
        XCTAssertEqual(mockConfigService.getOpenAIKey(), longKey, "Should handle very long API key")
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured with long key")
    }
    
    @MainActor
    func testSpecialCharactersInConfiguration() {
        // Given
        let specialKey = "sk-test!@#$%^&*()_+-=[]{}|;:,.<>?"
        let specialSID = "AC!@#$%^&*()_+-=[]{}|;:,.<>?"
        
        // When
        mockConfigService.setMockOpenAIKey(specialKey)
        mockConfigService.setMockTwilioCredentials(sid: specialSID, token: "test-token", fromNumber: "+1234567890")
        
        // Then
        XCTAssertEqual(mockConfigService.getOpenAIKey(), specialKey, "Should handle special characters in API key")
        XCTAssertEqual(mockConfigService.getTwilioSID(), specialSID, "Should handle special characters in SID")
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured with special characters")
        XCTAssertTrue(mockConfigService.isTwilioConfigured, "Should be configured with special characters")
    }
    
    // MARK: - Keychain Management Tests
    
    @MainActor
    func testStoreSecureCredential() {
        // Given
        let credential = "test-api-key-12345"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // When
        let result = mockConfigService.storeSecureCredential(credential, forKey: key)
        
        // Then
        XCTAssertTrue(result, "Should successfully store credential")
        XCTAssertEqual(mockConfigService.mockStoreCredentialCallCount, 1, "Should call store once")
        XCTAssertEqual(mockConfigService.getOpenAIKey(), credential, "Should return stored credential")
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured after storing")
    }
    
    @MainActor
    func testStoreEmptyCredential() {
        // Given
        let emptyCredential = ""
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // When
        let result = mockConfigService.storeSecureCredential(emptyCredential, forKey: key)
        
        // Then
        XCTAssertFalse(result, "Should not store empty credential")
        XCTAssertEqual(mockConfigService.mockStoreCredentialCallCount, 1, "Should call store once")
        XCTAssertNil(mockConfigService.getOpenAIKey(), "Should not have stored empty credential")
        XCTAssertFalse(mockConfigService.isOpenAIConfigured, "Should not be configured")
    }
    
    @MainActor
    func testDeleteSecureCredential() {
        // Given
        let credential = "test-api-key-12345"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Store credential first
        _ = mockConfigService.storeSecureCredential(credential, forKey: key)
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured after storing")
        
        // When
        let result = mockConfigService.deleteSecureCredential(forKey: key)
        
        // Then
        XCTAssertTrue(result, "Should successfully delete credential")
        XCTAssertEqual(mockConfigService.mockDeleteCredentialCallCount, 1, "Should call delete once")
        XCTAssertNil(mockConfigService.getOpenAIKey(), "Should not have credential after deletion")
        XCTAssertFalse(mockConfigService.isOpenAIConfigured, "Should not be configured after deletion")
    }
    
    @MainActor
    func testGetCredentialStatus() {
        // Given
        let credential = "test-api-key-12345"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Initially should show not stored
        let initialStatus = mockConfigService.getCredentialStatus()
        XCTAssertFalse(initialStatus[key]?.isStored ?? true, "Should initially show not stored")
        XCTAssertEqual(initialStatus[key]?.source, CredentialSource.none, "Should show no source initially")
        
        // Store credential
        _ = mockConfigService.storeSecureCredential(credential, forKey: key)
        
        // When
        let updatedStatus = mockConfigService.getCredentialStatus()
        
        // Then
        XCTAssertTrue(updatedStatus[key]?.isStored ?? false, "Should show stored after storing")
        XCTAssertEqual(updatedStatus[key]?.source, .keychain, "Should show keychain source")
        XCTAssertEqual(updatedStatus[key]?.length, credential.count, "Should show correct length")
    }
    
    @MainActor
    func testClearAllCredentials() {
        // Given - Store multiple credentials
        let credentials = [
            (KeychainCredentialStore.CredentialKey.openAIKey, "openai-key-123"),
            (KeychainCredentialStore.CredentialKey.twilioSID, "twilio-sid-456"),
            (KeychainCredentialStore.CredentialKey.twilioToken, "twilio-token-789")
        ]
        
        for (key, credential) in credentials {
            _ = mockConfigService.storeSecureCredential(credential, forKey: key)
        }
        
        // Verify they're stored
        XCTAssertTrue(mockConfigService.isOpenAIConfigured, "Should be configured")
        
        // When
        let result = mockConfigService.clearAllCredentials()
        
        // Then
        XCTAssertTrue(result, "Should successfully clear all credentials")
        XCTAssertEqual(mockConfigService.mockClearAllCallCount, 1, "Should call clear once")
        XCTAssertNil(mockConfigService.getOpenAIKey(), "Should not have OpenAI key after clearing")
        XCTAssertNil(mockConfigService.getTwilioSID(), "Should not have Twilio SID after clearing")
        XCTAssertNil(mockConfigService.getTwilioToken(), "Should not have Twilio token after clearing")
        XCTAssertFalse(mockConfigService.isOpenAIConfigured, "Should not be configured after clearing")
        XCTAssertFalse(mockConfigService.isTwilioConfigured, "Should not be configured after clearing")
    }
    
    @MainActor
    func testPerformManualMigration() {
        // Given
        let expectedResult = 2
        mockConfigService.setMockMigrationResult(expectedResult)
        
        // When
        let result = mockConfigService.performManualMigration()
        
        // Then
        XCTAssertEqual(result, expectedResult, "Should return expected migration result")
        XCTAssertEqual(mockConfigService.mockPerformMigrationCallCount, 1, "Should call migration once")
    }
} 