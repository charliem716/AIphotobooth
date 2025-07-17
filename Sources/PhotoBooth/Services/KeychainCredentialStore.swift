import Foundation
import Security

/// Thread-safe keychain-based credential store with session caching
class KeychainCredentialStore {
    
    // MARK: - Properties
    
    // Session cache for avoiding repeated keychain access
    private var sessionCache: [CredentialKey: String] = [:]
    private let sessionCacheLock = NSLock()
    
    // MARK: - Constants
    
    private static let keyPrefix = "photobooth_"
    private static let serviceName = "PhotoBooth"
    
    // MARK: - Initialization
    
    init() {
        logInfo("🔐 KeychainCredentialStore initialized with Security framework integration")
    }
    
    // MARK: - Public Methods
    
    /// Store a credential in the keychain using Security framework
    /// - Parameters:
    ///   - key: The credential key identifier
    ///   - value: The credential value to store
    /// - Returns: True if successful, false otherwise
    func store(key: CredentialKey, value: String) -> Bool {
        logInfo("💾 Storing credential: \(key.displayName)")
        
        guard let data = value.data(using: .utf8) else {
            logError("❌ Failed to encode credential data for: \(key.displayName)")
            return false
        }
        
        let account = "\(Self.keyPrefix)\(key.rawValue)"
        
        // First, try to update existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, create new one
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            
            status = SecItemAdd(newItem as CFDictionary, nil)
        }
        
        let success = status == errSecSuccess
        
        if success {
            // Update session cache
            sessionCacheLock.lock()
            sessionCache[key] = value
            sessionCacheLock.unlock()
            
            logInfo("✅ Stored credential successfully: \(key.displayName)")
        } else {
            logError("❌ Failed to store credential: \(key.displayName) (status: \(status))")
        }
        
        return success
    }
    
    /// Retrieve a credential from the keychain using Security framework
    /// - Parameter key: The credential key identifier
    /// - Returns: The credential value if found, nil otherwise
    func retrieve(key: CredentialKey) -> String? {
        // Check session cache first for performance
        sessionCacheLock.lock()
        if let cachedCredential = sessionCache[key] {
            sessionCacheLock.unlock()
            logDebug("🔍 Retrieved credential from session cache: \(key.displayName) (length: \(cachedCredential.count))")
            return cachedCredential
        }
        sessionCacheLock.unlock()
        
        // Access keychain using Security framework
        logDebug("🔍 Accessing keychain for credential: \(key.displayName)")
        
        let account = "\(Self.keyPrefix)\(key.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logDebug("❌ Failed to retrieve credential \(key.displayName) (status: \(status))")
            }
            return nil
        }
        
        guard let data = result as? Data,
              let credential = String(data: data, encoding: .utf8) else {
            logError("❌ Failed to decode credential data for: \(key.displayName)")
            return nil
        }
        
        // Cache the credential for this session
        sessionCacheLock.lock()
        sessionCache[key] = credential
        sessionCacheLock.unlock()
        
        logDebug("✅ Retrieved credential from keychain: \(key.displayName) (length: \(credential.count))")
        return credential
    }
    
    /// Delete a credential from the keychain using Security framework
    /// - Parameter key: The credential key identifier
    /// - Returns: True if successful, false otherwise
    func delete(key: CredentialKey) -> Bool {
        let account = "\(Self.keyPrefix)\(key.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        
        if success {
            logInfo("🗑️ Successfully deleted credential: \(key.displayName)")
            
            // Remove from session cache
            sessionCacheLock.lock()
            sessionCache.removeValue(forKey: key)
            sessionCacheLock.unlock()
            
        } else {
            logError("❌ Failed to delete credential: \(key.displayName) (status: \(status))")
        }
        
        return success
    }
    
    /// Check if a credential exists in the keychain using Security framework
    /// - Parameter key: The credential key identifier
    /// - Returns: True if credential exists, false otherwise
    func exists(key: CredentialKey) -> Bool {
        // First check session cache
        sessionCacheLock.lock()
        let cachedExists = sessionCache[key] != nil
        sessionCacheLock.unlock()
        
        if cachedExists {
            return true
        }
        
        // Check keychain using Security framework
        let account = "\(Self.keyPrefix)\(key.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false // Don't return data, just check existence
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Get all stored credential keys
    /// - Returns: Array of credential keys that have values stored
    func getAllStoredKeys() -> [CredentialKey] {
        return CredentialKey.allCases.filter { exists(key: $0) }
    }
    
    /// Preload all credentials into session cache to reduce keychain prompts
    /// This should be called during app startup to minimize password prompts
    func preloadAllCredentials() {
        logInfo("🔄 Preloading all credentials into session cache")
        
        sessionCacheLock.lock()
        defer { sessionCacheLock.unlock() }
        
        // Load all credentials in one batch to minimize keychain access prompts
        for key in CredentialKey.allCases {
            // Skip if already cached
            if sessionCache[key] != nil {
                continue
            }
            
            // Access keychain directly (bypassing retrieve method to avoid double-caching)
            let account = "\(Self.keyPrefix)\(key.rawValue)"
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.serviceName,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess,
               let data = result as? Data,
               let credential = String(data: data, encoding: .utf8) {
                sessionCache[key] = credential
                logDebug("✅ Preloaded credential: \(key.displayName)")
            } else if status != errSecItemNotFound {
                logDebug("⚠️ Failed to preload credential \(key.displayName) (status: \(status))")
            }
        }
        
        logInfo("🔄 Credential preloading completed")
    }
    
    /// Clear all PhotoBooth credentials from keychain
    /// - Returns: True if successful, false otherwise
    func clearAll() -> Bool {
        logWarning("🧹 Clearing all PhotoBooth credentials from keychain")
        
        var allSuccess = true
        for key in CredentialKey.allCases {
            if exists(key: key) {
                let success = delete(key: key)
                allSuccess = allSuccess && success
            }
        }
        
        // Clear session cache
        sessionCacheLock.lock()
        sessionCache.removeAll()
        sessionCacheLock.unlock()
        
        if allSuccess {
            logInfo("✅ Successfully cleared all credentials")
        } else {
            logError("❌ Failed to clear some credentials")
        }
        
        return allSuccess
    }
    
    /// Migrate credential from environment variable to keychain
    /// - Parameters:
    ///   - envValue: The environment variable value
    ///   - key: The credential key to store
    /// - Returns: True if migration successful, false otherwise
    func migrateFromEnvironment(_ envValue: String, toKey key: CredentialKey) -> Bool {
        guard !envValue.isEmpty else {
            logDebug("🔄 No environment value to migrate for key: \(key.displayName)")
            return false
        }
        
        // Check if already exists in keychain
        if exists(key: key) {
            logDebug("🔄 Credential already exists in keychain for key: \(key.displayName)")
            return true
        }
        
        // Store in keychain
        let success = store(key: key, value: envValue)
        
        if success {
            logInfo("🔄 Successfully migrated credential from environment: \(key.displayName)")
        } else {
            logError("❌ Failed to migrate credential from environment: \(key.displayName)")
        }
        
        return success
    }
    
    // MARK: - Session Management
    
    /// Preload all credentials into session cache
    /// - Returns: Number of credentials successfully cached
    func preloadCredentials() -> Int {
        logInfo("🔄 Preloading credentials into session cache")
        
        var loadedCount = 0
        for key in CredentialKey.allCases {
            // Try to retrieve each credential - this will populate the session cache
            if let _ = retrieve(key: key) {
                loadedCount += 1
                logDebug("🔍 Preloaded credential: \(key.displayName)")
            }
        }
        
        logInfo("✅ Preloaded \(loadedCount) credentials into session cache")
        return loadedCount
    }
    
    /// Clear session cache (forces re-authentication)
    func clearSessionCache() {
        sessionCacheLock.lock()
        sessionCache.removeAll()
        sessionCacheLock.unlock()
        
        logInfo("🧹 Session cache cleared - next access will require authentication")
    }
    
    /// Get session cache status
    /// - Returns: Dictionary showing which credentials are cached
    func getSessionCacheStatus() -> [CredentialKey: Bool] {
        sessionCacheLock.lock()
        let status = Dictionary(uniqueKeysWithValues: CredentialKey.allCases.map { ($0, sessionCache[$0] != nil) })
        sessionCacheLock.unlock()
        return status
    }
    
    /// Get credential status for all keys
    /// - Returns: Dictionary with detailed status for each credential
    func getCredentialStatus() -> [CredentialKey: CredentialStatus] {
        var status: [CredentialKey: CredentialStatus] = [:]
        
        for key in CredentialKey.allCases {
            let existsInKeychain = exists(key: key)
            let existsInCache = sessionCache[key] != nil
            
            if existsInKeychain && existsInCache {
                status[key] = .availableAndCached
            } else if existsInKeychain {
                status[key] = .availableNotCached
            } else {
                status[key] = .notAvailable
            }
        }
        
        return status
    }
}

// MARK: - Supporting Types

extension KeychainCredentialStore {
    
    /// Credential Keys
    enum CredentialKey: String, CaseIterable {
        case openAIKey = "openai_key"
        case twilioSID = "twilio_sid"
        case twilioToken = "twilio_token"
        case twilioFromNumber = "twilio_from"
        
        var displayName: String {
            switch self {
            case .openAIKey: return "OpenAI API Key"
            case .twilioSID: return "Twilio Account SID"
            case .twilioToken: return "Twilio Auth Token"
            case .twilioFromNumber: return "Twilio From Number"
            }
        }
    }
    
    /// Credential Status
    enum CredentialStatus {
        case availableAndCached
        case availableNotCached
        case notAvailable
        
        var description: String {
            switch self {
            case .availableAndCached: return "✅ Available (Cached)"
            case .availableNotCached: return "🔑 Available (Not Cached)"
            case .notAvailable: return "❌ Not Available"
            }
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(status: OSStatus)
} 