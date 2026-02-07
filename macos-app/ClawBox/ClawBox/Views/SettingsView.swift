//
//  SettingsView.swift
//  ClawBox
//
//  Settings for biometrics, auto-lock, and security
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @StateObject private var autoLockService = AutoLockService.shared
    
    @State private var showEnableBiometric = false
    @State private var password = ""
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            // Biometric Section
            Section("Biometric Unlock") {
                if vaultManager.biometricAvailable {
                    Toggle(isOn: Binding(
                        get: { vaultManager.biometricEnabled },
                        set: { enabled in
                            if enabled {
                                showEnableBiometric = true
                            } else {
                                vaultManager.disableBiometrics()
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "touchid")
                            Text("Enable \(vaultManager.biometricTypeName)")
                        }
                    }
                    
                    if vaultManager.biometricEnabled {
                        Text("Your vault can be unlocked using \(vaultManager.biometricTypeName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Biometric authentication not available on this device")
                        .foregroundColor(.secondary)
                }
            }
            
            // Auto-lock Section
            Section("Auto-Lock") {
                Picker("Lock vault after", selection: $autoLockService.policy) {
                    ForEach(AutoLockPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                
                Text("The vault will automatically lock after inactivity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Clipboard Section
            Section("Clipboard") {
                Text("Copied secrets are automatically cleared after 30 seconds")
                    .foregroundColor(.secondary)
            }
            
            // About Section
            Section("About") {
                LabeledContent("Version") {
                    Text("0.4.0")
                }
                LabeledContent("Encryption") {
                    Text("AES-256-GCM")
                }
                LabeledContent("Key Derivation") {
                    Text("Argon2id")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .sheet(isPresented: $showEnableBiometric) {
            enableBiometricSheet
        }
    }
    
    private var enableBiometricSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "touchid")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Enable \(vaultManager.biometricTypeName)")
                .font(.headline)
            
            Text("Enter your master password to enable biometric unlock")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            SecureField("Master Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    showEnableBiometric = false
                    password = ""
                    errorMessage = nil
                }
                
                Button("Enable") {
                    enableBiometrics()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 350)
    }
    
    private func enableBiometrics() {
        do {
            try vaultManager.enableBiometrics(password: password)
            showEnableBiometric = false
            password = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(VaultManager.shared)
}
