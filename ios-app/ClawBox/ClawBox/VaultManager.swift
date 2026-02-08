//
//  VaultManager.swift
//  ClawBox iOS
//
//  Manages vault state and operations using CryptoKit
//

import Foundation
import LocalAuthentication
import Security
import CryptoKit

/// Secret entry
struct SecretEntry: Identifiable, Codable {
    let id: String
    let path: String
    var value: String?
    let accessLevel: String
    let tags: [String]
    
    init(path: String, value: String? = nil, accessLevel: String = "normal", tags: [String] = []) {
        self.id = path
        self.path = path
        self.value = value
        self.accessLevel = accessLevel
        self.tags = tags
    }
}

/// Vault state
enum VaultState {
    case locked
    case unlocked
    case notInitialized
}

/// Main vault manager
@MainActor
class VaultManager: ObservableObject {
    @Published var state: VaultState = .locked
    @Published var secrets: [SecretEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let keychainService = "com.harrishan.ClawBox"
    private var masterKey: SymmetricKey?
    
    var isUnlocked: Bool {
        state == .unlocked
    }
    
    init() {
        checkVaultStatus()
    }
    
    // MARK: - Vault Operations
    
    func checkVaultStatus() {
        if getSalt() != nil {
            state = .locked
        } else {
            state = .notInitialized
        }
    }
    
    func initialize(password: String) throws {
        // Generate salt
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        
        // Derive key using PBKDF2 (via CryptoKit's HKDF after SHA256)
        let key = deriveKey(password: password, salt: salt)
        
        // Store salt in keychain
        try saveSalt(salt)
        
        // Create and encrypt verification data
        let verification = "clawbox-verification".data(using: .utf8)!
        let encrypted = try encrypt(data: verification, key: key)
        try saveVerification(encrypted)
        
        // Store password for biometric access
        try saveBiometricPassword(password)
        
        masterKey = key
        state = .unlocked
    }
    
    func unlock(password: String) throws {
        guard let salt = getSalt() else {
            throw VaultError.notInitialized
        }
        
        let key = deriveKey(password: password, salt: salt)
        
        guard let encrypted = getVerification() else {
            throw VaultError.corrupted
        }
        
        do {
            let decrypted = try decrypt(data: encrypted, key: key)
            guard String(data: decrypted, encoding: .utf8) == "clawbox-verification" else {
                throw VaultError.invalidPassword
            }
        } catch {
            throw VaultError.invalidPassword
        }
        
        masterKey = key
        state = .unlocked
        loadSecrets()
    }
    
    func unlockWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw VaultError.biometricsNotAvailable
        }
        
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock ClawBox"
        )
        
        guard success else {
            throw VaultError.biometricsFailed
        }
        
        guard let password = getBiometricPassword() else {
            throw VaultError.biometricsNotConfigured
        }
        
        try unlock(password: password)
    }
    
    func lock() {
        masterKey = nil
        secrets = []
        state = .locked
    }
    
    // MARK: - Secret Operations
    
    func loadSecrets() {
        guard let data = getSecretsList() else { return }
        secrets = (try? JSONDecoder().decode([SecretEntry].self, from: data)) ?? []
    }
    
    func getSecret(_ path: String) throws -> String {
        guard let key = masterKey else {
            throw VaultError.locked
        }
        
        guard let encrypted = getSecretData(path: path) else {
            throw VaultError.notFound
        }
        
        let decrypted = try decrypt(data: encrypted, key: key)
        return String(data: decrypted, encoding: .utf8) ?? ""
    }
    
    func setSecret(path: String, value: String, accessLevel: String = "normal") throws {
        guard let key = masterKey else {
            throw VaultError.locked
        }
        
        let data = value.data(using: .utf8)!
        let encrypted = try encrypt(data: data, key: key)
        
        try saveSecretData(path: path, data: encrypted)
        
        // Remove old entry if exists
        secrets.removeAll { $0.path == path }
        
        // Add with access level
        secrets.append(SecretEntry(path: path, accessLevel: accessLevel))
        saveSecretsList()
    }
    
    func deleteSecret(_ path: String) throws {
        deleteSecretData(path: path)
        secrets.removeAll { $0.path == path }
        saveSecretsList()
    }
    
    // MARK: - Crypto (CryptoKit)
    
    private func deriveKey(password: String, salt: Data) -> SymmetricKey {
        // Use PBKDF2-like derivation with SHA256
        let passwordData = password.data(using: .utf8)!
        
        // Create initial hash of password + salt
        var combined = passwordData
        combined.append(salt)
        
        // Multiple iterations for key stretching
        var hashData = Data(SHA256.hash(data: combined))
        for _ in 0..<100000 {
            var iterData = hashData
            iterData.append(salt)
            hashData = Data(SHA256.hash(data: iterData))
        }
        
        // Convert to SymmetricKey
        return SymmetricKey(data: hashData)
    }
    
    private func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw VaultError.cryptoError
        }
        return combined
    }
    
    private func decrypt(data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Keychain Helpers
    
    private func getSalt() -> Data? {
        getKeychainData(key: "salt")
    }
    
    private func saveSalt(_ salt: Data) throws {
        try setKeychainData(key: "salt", data: salt)
    }
    
    private func getVerification() -> Data? {
        getKeychainData(key: "verification")
    }
    
    private func saveVerification(_ data: Data) throws {
        try setKeychainData(key: "verification", data: data)
    }
    
    private func getSecretsList() -> Data? {
        getKeychainData(key: "secrets_list")
    }
    
    private func saveSecretsList() {
        guard let data = try? JSONEncoder().encode(secrets) else { return }
        try? setKeychainData(key: "secrets_list", data: data)
    }
    
    private func getSecretData(path: String) -> Data? {
        getKeychainData(key: "secret_\(path)")
    }
    
    private func saveSecretData(path: String, data: Data) throws {
        try setKeychainData(key: "secret_\(path)", data: data)
    }
    
    private func deleteSecretData(path: String) {
        deleteKeychainData(key: "secret_\(path)")
    }
    
    private func getBiometricPassword() -> String? {
        // Get password stored with biometric protection
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "biometric_password",
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: LAContext()
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    private func saveBiometricPassword(_ password: String) throws {
        deleteKeychainData(key: "biometric_password")
        
        // Create access control with biometric protection
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw VaultError.keychainError
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "biometric_password",
            kSecValueData as String: password.data(using: .utf8)!,
            kSecAttrAccessControl as String: accessControl
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.keychainError
        }
    }
    
    private func getKeychainData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return status == errSecSuccess ? result as? Data : nil
    }
    
    private func setKeychainData(key: String, data: Data) throws {
        deleteKeychainData(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.keychainError
        }
    }
    
    private func deleteKeychainData(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum VaultError: LocalizedError {
    case notInitialized
    case locked
    case invalidPassword
    case corrupted
    case notFound
    case cryptoError
    case keychainError
    case biometricsNotAvailable
    case biometricsFailed
    case biometricsNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .notInitialized: return "Vault not initialized"
        case .locked: return "Vault is locked"
        case .invalidPassword: return "Invalid password"
        case .corrupted: return "Vault data corrupted"
        case .notFound: return "Secret not found"
        case .cryptoError: return "Encryption error"
        case .keychainError: return "Keychain error"
        case .biometricsNotAvailable: return "Biometrics not available"
        case .biometricsFailed: return "Biometric authentication failed"
        case .biometricsNotConfigured: return "Biometrics not configured"
        }
    }
}
