import XCTest
import KeychainSwift
@testable import PhotoBooth

@MainActor
final class KeychainCredentialStoreTests: XCTestCase {
    
    private var keychainStore: KeychainCredentialStore!
    private let testKeyPrefix = "photobooth_test_"
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test instance with isolated keychain space
        keychainStore = KeychainCredentialStore()
        
        // Clear any existing test data
        _ = keychainStore.clearAll()
    }
    
    override func tearDown() async throws {
        // Clean up test data
        _ = keychainStore.clearAll()
        keychainStore = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Storage Tests
    
    func testStoreAndRetrieveCredential() {
        let testCredential = "test_api_key_12345"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Store credential
        let storeResult = keychainStore.store(testCredential, forKey: key)
        XCTAssertTrue(storeResult, "Should successfully store credential")
        
        // Retrieve credential
        let retrievedCredential = keychainStore.retrieve(key: key)
        XCTAssertEqual(retrievedCredential, testCredential, "Retrieved credential should match stored credential")
    }
    
    func testStoreEmptyCredential() {
        let emptyCredential = ""
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Attempt to store empty credential
        let storeResult = keychainStore.store(emptyCredential, forKey: key)
        XCTAssertFalse(storeResult, "Should not store empty credential")
        
        // Verify nothing was stored
        let retrievedCredential = keychainStore.retrieve(key: key)
        XCTAssertNil(retrievedCredential, "Should not retrieve empty credential")
    }
    
    func testRetrieveNonExistentCredential() {
        let key = KeychainCredentialStore.CredentialKey.twilioSID
        
        // Attempt to retrieve non-existent credential
        let retrievedCredential = keychainStore.retrieve(key: key)
        XCTAssertNil(retrievedCredential, "Should return nil for non-existent credential")
    }
    
    // MARK: - Credential Management Tests
    
    func testDeleteCredential() {
        let testCredential = "test_credential_to_delete"
        let key = KeychainCredentialStore.CredentialKey.twilioToken
        
        // Store credential
        let storeResult = keychainStore.store(testCredential, forKey: key)
        XCTAssertTrue(storeResult, "Should successfully store credential")
        
        // Verify it exists
        XCTAssertTrue(keychainStore.exists(key: key), "Credential should exist after storing")
        
        // Delete credential
        let deleteResult = keychainStore.delete(key: key)
        XCTAssertTrue(deleteResult, "Should successfully delete credential")
        
        // Verify it's gone
        XCTAssertFalse(keychainStore.exists(key: key), "Credential should not exist after deletion")
        XCTAssertNil(keychainStore.retrieve(key: key), "Should not retrieve deleted credential")
    }
    
    func testDeleteNonExistentCredential() {
        let key = KeychainCredentialStore.CredentialKey.twilioFromNumber
        
        // Attempt to delete non-existent credential
        let deleteResult = keychainStore.delete(key: key)
        XCTAssertTrue(deleteResult, "Delete should return true even for non-existent credential")
    }
    
    func testExistsCredential() {
        let testCredential = "test_existence_check"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Initially should not exist
        XCTAssertFalse(keychainStore.exists(key: key), "Credential should not exist initially")
        
        // Store credential
        _ = keychainStore.store(testCredential, forKey: key)
        
        // Now should exist
        XCTAssertTrue(keychainStore.exists(key: key), "Credential should exist after storing")
        
        // Delete credential
        _ = keychainStore.delete(key: key)
        
        // Should not exist again
        XCTAssertFalse(keychainStore.exists(key: key), "Credential should not exist after deletion")
    }
    
    // MARK: - Multiple Credentials Tests
    
    func testStoreMultipleCredentials() {
        let credentials = [
            (KeychainCredentialStore.CredentialKey.openAIKey, "openai_key_12345"),
            (KeychainCredentialStore.CredentialKey.twilioSID, "twilio_sid_67890"),
            (KeychainCredentialStore.CredentialKey.twilioToken, "twilio_token_abcdef"),
            (KeychainCredentialStore.CredentialKey.twilioFromNumber, "+1234567890")
        ]
        
        // Store all credentials
        for (key, credential) in credentials {
            let storeResult = keychainStore.store(credential, forKey: key)
            XCTAssertTrue(storeResult, "Should successfully store credential for \(key.displayName)")
        }
        
        // Verify all credentials
        for (key, expectedCredential) in credentials {
            let retrievedCredential = keychainStore.retrieve(key: key)
            XCTAssertEqual(retrievedCredential, expectedCredential, "Retrieved credential should match for \(key.displayName)")
        }
    }
    
    func testGetAllStoredKeys() {
        let credentialsToStore = [
            KeychainCredentialStore.CredentialKey.openAIKey: "openai_key_12345",
            KeychainCredentialStore.CredentialKey.twilioSID: "twilio_sid_67890"
        ]
        
        // Initially should be empty
        let initialKeys = keychainStore.getAllStoredKeys()
        XCTAssertTrue(initialKeys.isEmpty, "Should have no stored keys initially")
        
        // Store some credentials
        for (key, credential) in credentialsToStore {
            _ = keychainStore.store(credential, forKey: key)
        }
        
        // Check stored keys
        let storedKeys = keychainStore.getAllStoredKeys()
        XCTAssertEqual(storedKeys.count, credentialsToStore.count, "Should have correct number of stored keys")
        XCTAssertTrue(storedKeys.contains(.openAIKey), "Should contain OpenAI key")
        XCTAssertTrue(storedKeys.contains(.twilioSID), "Should contain Twilio SID")
    }
    
    func testClearAllCredentials() {
        let credentials = [
            (KeychainCredentialStore.CredentialKey.openAIKey, "openai_key_12345"),
            (KeychainCredentialStore.CredentialKey.twilioSID, "twilio_sid_67890"),
            (KeychainCredentialStore.CredentialKey.twilioToken, "twilio_token_abcdef")
        ]
        
        // Store multiple credentials
        for (key, credential) in credentials {
            _ = keychainStore.store(credential, forKey: key)
        }
        
        // Verify they exist
        XCTAssertEqual(keychainStore.getAllStoredKeys().count, credentials.count, "Should have all credentials stored")
        
        // Clear all
        let clearResult = keychainStore.clearAll()
        XCTAssertTrue(clearResult, "Should successfully clear all credentials")
        
        // Verify they're gone
        XCTAssertTrue(keychainStore.getAllStoredKeys().isEmpty, "Should have no stored keys after clearing")
        
        for (key, _) in credentials {
            XCTAssertFalse(keychainStore.exists(key: key), "Credential should not exist after clearing: \(key.displayName)")
        }
    }
    
    // MARK: - Migration Tests
    
    func testMigrateFromEnvironment() {
        let envValue = "env_api_key_12345"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Initially should not exist
        XCTAssertFalse(keychainStore.exists(key: key), "Credential should not exist initially")
        
        // Migrate from environment
        let migrateResult = keychainStore.migrateFromEnvironment(envValue, toKey: key)
        XCTAssertTrue(migrateResult, "Should successfully migrate from environment")
        
        // Verify migration
        let retrievedCredential = keychainStore.retrieve(key: key)
        XCTAssertEqual(retrievedCredential, envValue, "Migrated credential should match environment value")
    }
    
    func testMigrateFromEnvironmentEmptyValue() {
        let emptyValue = ""
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Attempt to migrate empty value
        let migrateResult = keychainStore.migrateFromEnvironment(emptyValue, toKey: key)
        XCTAssertFalse(migrateResult, "Should not migrate empty environment value")
        
        // Verify nothing was stored
        XCTAssertFalse(keychainStore.exists(key: key), "Should not store empty migrated value")
    }
    
    func testMigrateFromEnvironmentExistingCredential() {
        let existingCredential = "existing_credential_12345"
        let envValue = "env_credential_67890"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Store existing credential
        _ = keychainStore.store(existingCredential, forKey: key)
        
        // Attempt to migrate (should skip because credential exists)
        let migrateResult = keychainStore.migrateFromEnvironment(envValue, toKey: key)
        XCTAssertTrue(migrateResult, "Should return true for existing credential")
        
        // Verify existing credential is unchanged
        let retrievedCredential = keychainStore.retrieve(key: key)
        XCTAssertEqual(retrievedCredential, existingCredential, "Existing credential should be unchanged")
    }
    
    // MARK: - Status Tests
    
    func testGetCredentialStatus() {
        let testCredential = "test_status_credential"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Initially should show not stored
        let initialStatus = keychainStore.getCredentialStatus()
        XCTAssertFalse(initialStatus[key]?.isStored ?? true, "Should initially show not stored")
        XCTAssertEqual(initialStatus[key]?.source, .none, "Should show no source initially")
        
        // Store credential
        _ = keychainStore.store(testCredential, forKey: key)
        
        // Check status after storing
        let storedStatus = keychainStore.getCredentialStatus()
        XCTAssertTrue(storedStatus[key]?.isStored ?? false, "Should show stored after storing")
        XCTAssertEqual(storedStatus[key]?.source, .keychain, "Should show keychain source")
        XCTAssertEqual(storedStatus[key]?.length, testCredential.count, "Should show correct length")
    }
    
    func testGetCredentialStatusAllKeys() {
        let status = keychainStore.getCredentialStatus()
        
        // Should have status for all credential keys
        XCTAssertEqual(status.count, KeychainCredentialStore.CredentialKey.allCases.count, "Should have status for all keys")
        
        // Check each key has proper status
        for key in KeychainCredentialStore.CredentialKey.allCases {
            XCTAssertNotNil(status[key], "Should have status for \(key.displayName)")
            XCTAssertFalse(status[key]?.isStored ?? true, "Should initially show not stored for \(key.displayName)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testGetLastResultCode() {
        let testCredential = "test_result_code"
        let key = KeychainCredentialStore.CredentialKey.openAIKey
        
        // Store credential and check result code
        _ = keychainStore.store(testCredential, forKey: key)
        let resultCode = keychainStore.getLastResultCode()
        
        // Should be noErr (0) for successful operation
        XCTAssertEqual(resultCode, noErr, "Should return noErr for successful operation")
    }
    
    // MARK: - Credential Key Tests
    
    func testCredentialKeyDisplayNames() {
        let expectedDisplayNames = [
            KeychainCredentialStore.CredentialKey.openAIKey: "OpenAI API Key",
            KeychainCredentialStore.CredentialKey.twilioSID: "Twilio Account SID",
            KeychainCredentialStore.CredentialKey.twilioToken: "Twilio Auth Token",
            KeychainCredentialStore.CredentialKey.twilioFromNumber: "Twilio From Number"
        ]
        
        for (key, expectedName) in expectedDisplayNames {
            XCTAssertEqual(key.displayName, expectedName, "Display name should match for \(key.rawValue)")
        }
    }
    
    func testCredentialKeyAllCases() {
        let allCases = KeychainCredentialStore.CredentialKey.allCases
        
        XCTAssertEqual(allCases.count, 4, "Should have 4 credential keys")
        XCTAssertTrue(allCases.contains(.openAIKey), "Should contain OpenAI key")
        XCTAssertTrue(allCases.contains(.twilioSID), "Should contain Twilio SID")
        XCTAssertTrue(allCases.contains(.twilioToken), "Should contain Twilio token")
        XCTAssertTrue(allCases.contains(.twilioFromNumber), "Should contain Twilio from number")
    }
    
    // MARK: - Supporting Types Tests
    
    func testCredentialStatusDescription() {
        let storedStatus = CredentialStatus(isStored: true, length: 25, source: .keychain)
        let notStoredStatus = CredentialStatus(isStored: false, length: 0, source: .none)
        
        XCTAssertTrue(storedStatus.description.contains("✅"), "Stored status should show success")
        XCTAssertTrue(storedStatus.description.contains("Keychain"), "Stored status should show keychain source")
        XCTAssertTrue(storedStatus.description.contains("25"), "Stored status should show length")
        
        XCTAssertTrue(notStoredStatus.description.contains("❌"), "Not stored status should show error")
        XCTAssertTrue(notStoredStatus.description.contains("Not stored"), "Not stored status should show not stored")
    }
    
    func testCredentialSourceValues() {
        XCTAssertEqual(CredentialSource.keychain.rawValue, "Keychain")
        XCTAssertEqual(CredentialSource.environment.rawValue, "Environment")
        XCTAssertEqual(CredentialSource.none.rawValue, "None")
    }
} 