//
//  ContentView.swift
//  ClawBox
//
//  Main content view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    
    var body: some View {
        Group {
            switch vaultManager.state {
            case .notInitialized:
                InitializeView()
            case .locked:
                UnlockView()
            case .unlocked:
                MainView()
            case .error(let message):
                ErrorView(message: message)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Initialize View

struct InitializeView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Welcome to ClawBox")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Create a new vault to get started")
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: initialize) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Create Vault")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty || password != confirmPassword || isLoading)
            }
        }
        .padding(40)
    }
    
    private func initialize() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await vaultManager.initialize(password: password)
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
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("ClawBox is Locked")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .onSubmit { unlock() }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: unlock) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Unlock")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty || isLoading)
            }
        }
        .padding(40)
    }
    
    private func unlock() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await vaultManager.unlock(password: password)
            } catch {
                errorMessage = "Invalid password"
            }
            isLoading = false
        }
    }
}

// MARK: - Main View

struct MainView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchText = ""
    @State private var selectedSecret: SecretEntry?
    @State private var showingAddSheet = false
    
    var filteredSecrets: [SecretEntry] {
        if searchText.isEmpty {
            return vaultManager.secrets
        }
        return vaultManager.secrets.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack {
                List(filteredSecrets, selection: $selectedSecret) { secret in
                    SecretRow(secret: secret)
                        .tag(secret)
                }
                .searchable(text: $searchText, prompt: "Search secrets...")
            }
            .navigationTitle("Secrets")
            .toolbar {
                ToolbarItem {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem {
                    Button(action: { vaultManager.lock() }) {
                        Image(systemName: "lock.fill")
                    }
                    .help("Lock Vault")
                }
            }
        } detail: {
            if let secret = selectedSecret {
                SecretDetailView(secret: secret)
            } else {
                Text("Select a secret")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSecretSheet()
        }
    }
}

// MARK: - Secret Row

struct SecretRow: View {
    let secret: SecretEntry
    
    var body: some View {
        HStack {
            Text(secret.accessLevel.icon)
            
            VStack(alignment: .leading) {
                Text(secret.path)
                    .fontWeight(.medium)
                
                if !secret.tags.isEmpty {
                    Text(secret.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Secret Detail View

struct SecretDetailView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let secret: SecretEntry
    
    @State private var value: String = "••••••••"
    @State private var isRevealed = false
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section("Secret") {
                LabeledContent("Path") {
                    Text(secret.path)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Value") {
                    HStack {
                        Text(isRevealed ? value : "••••••••")
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                        
                        Button(action: toggleReveal) {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: copyValue) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                LabeledContent("Access Level") {
                    Text("\(secret.accessLevel.icon) \(secret.accessLevel.rawValue.capitalized)")
                }
            }
            
            Section {
                Button("Delete Secret", role: .destructive) {
                    deleteSecret()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle(secret.path)
    }
    
    private func toggleReveal() {
        if isRevealed {
            isRevealed = false
            value = "••••••••"
        } else {
            isLoading = true
            Task {
                do {
                    value = try await vaultManager.getSecret(secret.path)
                    isRevealed = true
                } catch {
                    value = "Error loading"
                }
                isLoading = false
            }
        }
    }
    
    private func copyValue() {
        Task {
            let val = try await vaultManager.getSecret(secret.path)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(val, forType: .string)
            
            // Clear after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                NSPasteboard.general.clearContents()
            }
        }
    }
    
    private func deleteSecret() {
        Task {
            try await vaultManager.deleteSecret(secret.path)
        }
    }
}

// MARK: - Add Secret Sheet

struct AddSecretSheet: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) var dismiss
    
    @State private var path = ""
    @State private var value = ""
    @State private var accessLevel: SecretEntry.AccessLevel = .normal
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Secret")
                .font(.headline)
            
            Form {
                TextField("Path (e.g., github/token)", text: $path)
                SecureField("Value", text: $value)
                Picker("Access Level", selection: $accessLevel) {
                    ForEach(SecretEntry.AccessLevel.allCases, id: \.self) { level in
                        Text("\(level.icon) \(level.rawValue.capitalized)").tag(level)
                    }
                }
            }
            .formStyle(.grouped)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(path.isEmpty || value.isEmpty || isLoading)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func save() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await vaultManager.setSecret(path: path, value: value, accessLevel: accessLevel)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var vaultManager: VaultManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vaultManager.isUnlocked {
                Text("🔓 Vault Unlocked")
                    .font(.headline)
                
                Divider()
                
                Text("Quick Copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(vaultManager.secrets.prefix(5)) { secret in
                    Button(action: { copySecret(secret.path) }) {
                        Text(secret.path)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                Button("Lock Vault") {
                    vaultManager.lock()
                }
            } else {
                Text("🔒 Vault Locked")
                    .font(.headline)
            }
            
            Divider()
            
            Button("Quit ClawBox") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
    
    private func copySecret(_ path: String) {
        Task {
            let value = try await vaultManager.getSecret(path)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultManager.shared)
}
