//
//  VaultManager.swift
//  ClawBox
//
//  Manages vault state and operations
//

import Foundation
import Combine

/// Secret entry model
struct SecretEntry: Identifiable, Codable {
    let id: String
    let path: String
    var value: String?
    let accessLevel: AccessLevel
    let tags: [String]
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum AccessLevel: String, Codable, CaseIterable {
        case `public` = "public"
        case normal = "normal"
        case sensitive = "sensitive"
        case critical = "critical"
        
        var icon: String {
            switch self {
            case .public: return "🔓"
            case .normal: return "🔑"
            case .sensitive: return "🔐"
            case .critical: return "🔒"
            }
        }
    }
}

/// Vault state
enum VaultState {
    case notInitialized
    case locked
    case unlocked
    case error(String)
}

/// Main vault manager
@MainActor
class VaultManager: ObservableObject {
    static let shared = VaultManager()
    
    @Published var state: VaultState = .locked
    @Published var secrets: [SecretEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var biometricEnabled = false
    
    private let vaultPath: URL
    private var clawboxPath: String
    private let biometricAuth = BiometricAuth.shared
    private let autoLockService = AutoLockService.shared
    
    var isUnlocked: Bool {
        if case .unlocked = state { return true }
        return false
    }
    
    private init() {
        // Default vault path
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.vaultPath = home.appendingPathComponent(".clawbox")
        
        // Find clawbox binary
        self.clawboxPath = "/usr/local/bin/clawbox"
        if !FileManager.default.fileExists(atPath: clawboxPath) {
            // Try homebrew path
            let brewPath = "/opt/homebrew/bin/clawbox"
            if FileManager.default.fileExists(atPath: brewPath) {
                self.clawboxPath = brewPath
            }
        }
        
        checkVaultStatus()
    }
    
    /// Check if vault exists and is initialized
    func checkVaultStatus() {
        let dbPath = vaultPath.appendingPathComponent("vault.db")
        if FileManager.default.fileExists(atPath: dbPath.path) {
            state = .locked
        } else {
            state = .notInitialized
        }
        
        // Load biometric settings
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled") && biometricAuth.hasStoredPassword
    }
    
    /// Setup auto-lock when unlocked
    private func setupAutoLock() {
        autoLockService.start { [weak self] in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
    
    /// Initialize vault with password
    func initialize(password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await runClawbox(["init"], password: password)
        if result.exitCode == 0 {
            state = .unlocked
            try await loadSecrets()
        } else {
            throw ClawBoxError.initFailed(result.output)
        }
    }
    
    /// Unlock vault
    func unlock(password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Test unlock by listing secrets
        let result = try await runClawbox(["list", "--json"], password: password)
        if result.exitCode == 0 {
            state = .unlocked
            parseSecrets(from: result.output)
            setupAutoLock()
        } else {
            throw ClawBoxError.unlockFailed("Invalid password")
        }
    }
    
    /// Lock vault
    func lock() {
        secrets = []
        state = .locked
        currentPassword = nil
        autoLockService.stop()
    }
    
    /// Unlock with biometrics
    func unlockWithBiometrics() async throws {
        guard biometricAuth.hasStoredPassword else {
            throw ClawBoxError.unlockFailed("No saved password")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let password = try await biometricAuth.loadPassword()
        try await unlock(password: password)
    }
    
    /// Enable biometric unlock
    func enableBiometrics(password: String) throws {
        try biometricAuth.savePassword(password)
        biometricEnabled = true
        UserDefaults.standard.set(true, forKey: "biometricEnabled")
    }
    
    /// Disable biometric unlock
    func disableBiometrics() {
        biometricAuth.removePassword()
        biometricEnabled = false
        UserDefaults.standard.set(false, forKey: "biometricEnabled")
    }
    
    /// Check if biometrics available
    var biometricAvailable: Bool {
        biometricAuth.isAvailable
    }
    
    /// Biometric type name
    var biometricTypeName: String {
        biometricAuth.biometricTypeName
    }
    
    /// Load secrets list
    func loadSecrets() async throws {
        guard isUnlocked else { return }
        
        let result = try await runClawbox(["list", "--json"])
        if result.exitCode == 0 {
            parseSecrets(from: result.output)
        }
    }
    
    /// Get secret value
    func getSecret(_ path: String) async throws -> String {
        let result = try await runClawbox(["get", path])
        if result.exitCode == 0 {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw ClawBoxError.secretNotFound(path)
    }
    
    /// Set secret value
    func setSecret(path: String, value: String, accessLevel: SecretEntry.AccessLevel = .normal) async throws {
        let result = try await runClawbox(["set", path, value, "--access", accessLevel.rawValue])
        if result.exitCode != 0 {
            throw ClawBoxError.setFailed(result.output)
        }
        try await loadSecrets()
    }
    
    /// Delete secret
    func deleteSecret(_ path: String) async throws {
        let result = try await runClawbox(["delete", path, "--force"])
        if result.exitCode != 0 {
            throw ClawBoxError.deleteFailed(result.output)
        }
        try await loadSecrets()
    }
    
    // MARK: - Private
    
    private var currentPassword: String?
    
    private func runClawbox(_ args: [String], password: String? = nil) async throws -> (exitCode: Int32, output: String) {
        if let pwd = password {
            currentPassword = pwd
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: clawboxPath)
            process.arguments = ["--vault", vaultPath.path] + args
            
            // Set password via environment
            var env = ProcessInfo.processInfo.environment
            if let pwd = currentPassword {
                env["CLAWBOX_PASSWORD"] = pwd
            }
            process.environment = env
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                continuation.resume(returning: (process.terminationStatus, output))
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseSecrets(from json: String) {
        guard let data = json.data(using: .utf8) else { return }
        
        do {
            let decoded = try JSONDecoder().decode([SecretListItem].self, from: data)
            secrets = decoded.map { item in
                SecretEntry(
                    id: item.path,
                    path: item.path,
                    value: nil,
                    accessLevel: SecretEntry.AccessLevel(rawValue: item.access.lowercased()) ?? .normal,
                    tags: item.tags,
                    note: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        } catch {
            print("Failed to parse secrets: \(error)")
        }
    }
}

// JSON parsing helper
private struct SecretListItem: Codable {
    let path: String
    let access: String
    let tags: [String]
}

// Errors
enum ClawBoxError: LocalizedError {
    case initFailed(String)
    case unlockFailed(String)
    case secretNotFound(String)
    case setFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .initFailed(let msg): return "Init failed: \(msg)"
        case .unlockFailed(let msg): return "Unlock failed: \(msg)"
        case .secretNotFound(let path): return "Secret not found: \(path)"
        case .setFailed(let msg): return "Set failed: \(msg)"
        case .deleteFailed(let msg): return "Delete failed: \(msg)"
        }
    }
}
