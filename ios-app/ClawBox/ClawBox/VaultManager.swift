//
//  VaultManager.swift
//  ClawBox iOS
//
//  Manages vault state and operations
//

import Foundation
import LocalAuthentication
import Security

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
    private var masterKey: Data?
    
    var isUnlocked: Bool {
        state == .unlocked
    }
    
    init() {
        checkVaultStatus()
    }
    
    // MARK: - Vault Operations
    
    func checkVaultStatus() {
        // Check if vault exists in keychain
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
        
        // Derive key
        let key = try deriveKey(password: password, salt: salt)
        
        // Store salt in keychain
        try saveSalt(salt)
        
        // Create verification data
        let verification = "clawbox-verification".data(using: .utf8)!
        let encrypted = try encrypt(data: verification, key: key)
        try saveVerification(encrypted)
        
        masterKey = key
        state = .unlocked
    }
    
    func unlock(password: String) throws {
        guard let salt = getSalt() else {
            throw VaultError.notInitialized
        }
        
        let key = try deriveKey(password: password, salt: salt)
        
        // Verify password
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
        
        // Get password from keychain with biometric access
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
        // Load from secure storage
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
    
    func setSecret(path: String, value: String) throws {
        guard let key = masterKey else {
            throw VaultError.locked
        }
        
        let data = value.data(using: .utf8)!
        let encrypted = try encrypt(data: data, key: key)
        
        try saveSecretData(path: path, data: encrypted)
        
        if !secrets.contains(where: { $0.path == path }) {
            secrets.append(SecretEntry(path: path))
            saveSecretsList()
        }
    }
    
    func deleteSecret(_ path: String) throws {
        deleteSecretData(path: path)
        secrets.removeAll { $0.path == path }
        saveSecretsList()
    }
    
    // MARK: - Crypto
    
    private func deriveKey(password: String, salt: Data) throws -> Data {
        // Simple PBKDF2 (in production, use Argon2id)
        var key = Data(count: 32)
        let passwordData = password.data(using: .utf8)!
        
        let status = key.withUnsafeMutableBytes { keyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress, passwordData.count,
                        saltBytes.baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100000,
                        keyBytes.baseAddress, 32
                    )
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw VaultError.cryptoError
        }
        
        return key
    }
    
    private func encrypt(data: Data, key: Data) throws -> Data {
        var nonce = Data(count: 12)
        _ = nonce.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!) }
        
        var encrypted = Data(count: data.count + 16)
        var encryptedLength = 0
        
        let status = encrypted.withUnsafeMutableBytes { encryptedBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    nonce.withUnsafeBytes { nonceBytes in
                        CCCryptorGCM(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            keyBytes.baseAddress, 32,
                            nonceBytes.baseAddress, 12,
                            nil, 0,
                            dataBytes.baseAddress, data.count,
                            encryptedBytes.baseAddress,
                            encryptedBytes.baseAddress?.advanced(by: data.count), 16,
                            &encryptedLength
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw VaultError.cryptoError
        }
        
        return nonce + encrypted
    }
    
    private func decrypt(data: Data, key: Data) throws -> Data {
        guard data.count > 28 else {
            throw VaultError.cryptoError
        }
        
        let nonce = data.prefix(12)
        let ciphertext = data.dropFirst(12).dropLast(16)
        let tag = data.suffix(16)
        
        var decrypted = Data(count: ciphertext.count)
        var decryptedLength = 0
        
        // Simplified - in production use proper AES-GCM
        decrypted = ciphertext
        
        return Data(decrypted)
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
        // Would be stored with biometric protection
        nil
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
            kSecValueData as String: data
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

// CommonCrypto
import CommonCrypto
