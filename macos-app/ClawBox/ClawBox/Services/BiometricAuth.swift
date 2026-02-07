//
//  BiometricAuth.swift
//  ClawBox
//
//  Touch ID / Face ID authentication service
//

import Foundation
import LocalAuthentication
import Security

/// Biometric authentication service
class BiometricAuth {
    static let shared = BiometricAuth()
    
    private let keychainService = "com.harrishan.ClawBox"
    private let keychainAccount = "masterPassword"
    
    /// Check if biometrics are available
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get biometric type name
    var biometricTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }
    
    /// Authenticate with biometrics
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"
        
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
    
    // MARK: - Keychain Storage
    
    /// Save password to Keychain with biometric protection
    func savePassword(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw BiometricError.encodingError
        }
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Create access control with biometric protection
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw BiometricError.keychainError("Failed to create access control")
        }
        
        // Add new password
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: passwordData,
            kSecAttrAccessControl as String: accessControl
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.keychainError("Failed to save password: \(status)")
        }
    }
    
    /// Load password from Keychain with biometric authentication
    func loadPassword() async throws -> String {
        // First authenticate
        guard try await authenticate(reason: "Unlock ClawBox vault") else {
            throw BiometricError.authenticationFailed
        }
        
        // Now query keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw BiometricError.keychainError("Failed to load password: \(status)")
        }
        
        return password
    }
    
    /// Check if password is saved in Keychain
    var hasStoredPassword: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
    
    /// Remove password from Keychain
    func removePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed
    case encodingError
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Biometric authentication not available"
        case .authenticationFailed: return "Authentication failed"
        case .encodingError: return "Failed to encode password"
        case .keychainError(let msg): return msg
        }
    }
}
