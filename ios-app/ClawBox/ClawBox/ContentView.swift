//
//  ContentView.swift
//  ClawBox iOS
//
//  Main content view
//

import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    
    var body: some View {
        NavigationStack {
            Group {
                switch vaultManager.state {
                case .notInitialized:
                    InitializeView()
                case .locked:
                    UnlockView()
                case .unlocked:
                    SecretsListView()
                }
            }
            .navigationTitle("ClawBox")
        }
    }
}

// MARK: - Initialize View

struct InitializeView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Welcome to ClawBox")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create a master password to secure your secrets")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: initialize) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Create Vault")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty || password != confirmPassword || isLoading)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func initialize() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try vaultManager.initialize(password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Unlock View

struct UnlockView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showBiometric = false
    
    private let context = LAContext()
    
    var biometricsAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var biometricType: String {
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Vault Locked")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                if biometricsAvailable {
                    Button(action: unlockWithBiometrics) {
                        HStack {
                            Image(systemName: context.biometryType == .faceID ? "faceid" : "touchid")
                            Text("Unlock with \(biometricType)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("or")
                        .foregroundColor(.secondary)
                }
                
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .onSubmit { unlock() }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: unlock) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Unlock")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(password.isEmpty || isLoading)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func unlock() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try vaultManager.unlock(password: password)
            } catch {
                errorMessage = "Invalid password"
            }
            isLoading = false
        }
    }
    
    private func unlockWithBiometrics() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await vaultManager.unlockWithBiometrics()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Secrets List View

struct SecretsListView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchText = ""
    @State private var showAddSheet = false
    
    var filteredSecrets: [SecretEntry] {
        if searchText.isEmpty {
            return vaultManager.secrets
        }
        return vaultManager.secrets.filter {
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredSecrets) { secret in
                NavigationLink(destination: SecretDetailView(secret: secret)) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.accentColor)
                        Text(secret.path)
                    }
                }
            }
            .onDelete(perform: deleteSecrets)
        }
        .searchable(text: $searchText, prompt: "Search secrets")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { vaultManager.lock() }) {
                    Image(systemName: "lock.fill")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSecretView()
        }
        .overlay {
            if filteredSecrets.isEmpty {
                ContentUnavailableView(
                    "No Secrets",
                    systemImage: "key.slash",
                    description: Text("Tap + to add your first secret")
                )
            }
        }
    }
    
    private func deleteSecrets(at offsets: IndexSet) {
        for index in offsets {
            let secret = filteredSecrets[index]
            try? vaultManager.deleteSecret(secret.path)
        }
    }
}

// MARK: - Secret Detail View

struct SecretDetailView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let secret: SecretEntry
    
    @State private var value = ""
    @State private var isRevealed = false
    @State private var isLoading = false
    @State private var copied = false
    
    var body: some View {
        Form {
            Section("Path") {
                Text(secret.path)
                    .font(.system(.body, design: .monospaced))
            }
            
            Section("Value") {
                HStack {
                    Text(isRevealed ? value : "••••••••")
                        .font(.system(.body, design: .monospaced))
                    
                    Spacer()
                    
                    Button(action: toggleReveal) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                    }
                    
                    Button(action: copyValue) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            
            Section("Access Level") {
                Text(secret.accessLevel.capitalized)
            }
        }
        .navigationTitle(secret.path)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleReveal() {
        if isRevealed {
            isRevealed = false
            value = ""
        } else {
            isLoading = true
            do {
                value = try vaultManager.getSecret(secret.path)
                isRevealed = true
            } catch {
                value = "Error"
            }
            isLoading = false
        }
    }
    
    private func copyValue() {
        do {
            let val = try vaultManager.getSecret(secret.path)
            UIPasteboard.general.string = val
            copied = true
            
            // Clear clipboard after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if UIPasteboard.general.string == val {
                    UIPasteboard.general.string = ""
                }
            }
            
            // Reset copied state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copied = false
            }
        } catch {
            // Handle error
        }
    }
}

// MARK: - Add Secret View

struct AddSecretView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) var dismiss
    
    @State private var path = ""
    @State private var value = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("New Secret") {
                    TextField("Path (e.g., github/token)", text: $path)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Value", text: $value)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Secret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(path.isEmpty || value.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        do {
            try vaultManager.setSecret(path: path, value: value)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultManager())
}
