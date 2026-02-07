//
//  ContentView.swift
//  ClawBox
//
//  Modern UI inspired by 1Password/Bitwarden
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
        .frame(minWidth: 800, minHeight: 500)
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
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                        )
                    
                    Text("ClawBox")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("AI-Native Secret Manager")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create Master Password")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        SecureField("", text: $password)
                            .textFieldStyle(ModernTextFieldStyle())
                            .frame(width: 320)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        SecureField("", text: $confirmPassword)
                            .textFieldStyle(ModernTextFieldStyle())
                            .frame(width: 320)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: initialize) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text("Create Vault")
                                .fontWeight(.semibold)
                        }
                        .frame(width: 320, height: 44)
                    }
                    .buttonStyle(ModernButtonStyle())
                    .disabled(password.isEmpty || password != confirmPassword || isLoading)
                }
            }
            .padding(60)
        }
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
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.cyan)
                    
                    Text("ClawBox")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Vault is locked")
                        .foregroundColor(.gray)
                }
                
                // Unlock form
                VStack(spacing: 20) {
                    // Biometric button
                    if vaultManager.biometricEnabled && vaultManager.biometricAvailable {
                        Button(action: unlockWithBiometrics) {
                            HStack {
                                Image(systemName: "touchid")
                                    .font(.title2)
                                Text("Unlock with \(vaultManager.biometricTypeName)")
                            }
                            .frame(width: 320, height: 44)
                        }
                        .buttonStyle(ModernButtonStyle())
                        .disabled(isLoading)
                        
                        Text("or enter password")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    
                    SecureField("Master Password", text: $password)
                        .textFieldStyle(ModernTextFieldStyle())
                        .frame(width: 320)
                        .onSubmit { unlock() }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: unlock) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text("Unlock")
                                .fontWeight(.semibold)
                        }
                        .frame(width: 320, height: 44)
                    }
                    .buttonStyle(ModernSecondaryButtonStyle())
                    .disabled(password.isEmpty || isLoading)
                }
            }
            .padding(60)
        }
        .onAppear {
            if vaultManager.biometricEnabled && vaultManager.biometricAvailable {
                unlockWithBiometrics()
            }
        }
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

// MARK: - Main View

struct MainView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchText = ""
    @State private var selectedSecret: SecretEntry?
    @State private var showingAddSheet = false
    @State private var selectedCategory: String? = nil
    
    var categories: [String] {
        let paths = vaultManager.secrets.map { $0.path.split(separator: "/").first.map(String.init) ?? "Other" }
        return Array(Set(paths)).sorted()
    }
    
    var filteredSecrets: [SecretEntry] {
        var result = vaultManager.secrets
        
        if let category = selectedCategory {
            result = result.filter { $0.path.hasPrefix(category + "/") || $0.path == category }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding()
                
                // Categories
                List(selection: $selectedCategory) {
                    Section("Categories") {
                        Button(action: { selectedCategory = nil }) {
                            Label("All Items", systemImage: "tray.full.fill")
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedCategory == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                        
                        ForEach(categories, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Label(category.capitalized, systemImage: categoryIcon(for: category))
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedCategory == category ? Color.accentColor.opacity(0.2) : Color.clear)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { vaultManager.lock() }) {
                        Image(systemName: "lock.fill")
                    }
                    .help("Lock Vault")
                }
            }
        } content: {
            // Secret list
            List(filteredSecrets, selection: $selectedSecret) { secret in
                SecretRow(secret: secret)
                    .tag(secret)
            }
            .listStyle(.inset)
            .frame(minWidth: 250)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            // Detail view
            if let secret = selectedSecret {
                SecretDetailView(secret: secret)
            } else {
                VStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Select a secret")
                        .foregroundColor(.gray)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSecretSheet()
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "aws": return "cloud.fill"
        case "google": return "g.circle.fill"
        case "api": return "network"
        case "ssh": return "terminal.fill"
        case "database", "db": return "cylinder.fill"
        default: return "folder.fill"
        }
    }
}

// MARK: - Secret Row

struct SecretRow: View {
    let secret: SecretEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: secret.accessLevel.icon)
                .font(.title3)
                .foregroundColor(accessColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(secret.path)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                if !secret.tags.isEmpty {
                    Text(secret.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    var accessColor: Color {
        switch secret.accessLevel {
        case .public: return .green
        case .normal: return .blue
        case .sensitive: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Secret Detail View

struct SecretDetailView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let secret: SecretEntry
    
    @State private var value: String = ""
    @State private var isRevealed = false
    @State private var isLoading = false
    @State private var copied = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: secret.accessLevel.icon)
                        .font(.title)
                        .foregroundColor(accessColor)
                    
                    VStack(alignment: .leading) {
                        Text(secret.path)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(secret.accessLevel.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Value section
                VStack(alignment: .leading, spacing: 12) {
                    Text("SECRET VALUE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    
                    HStack {
                        if isRevealed {
                            Text(value)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text("••••••••••••••••")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: toggleReveal) {
                                Image(systemName: isRevealed ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            
                            Button(action: copyValue) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(copied ? .green : .secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Tags
                if !secret.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TAGS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        
                        HStack {
                            ForEach(secret.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Delete button
                Button(role: .destructive, action: deleteSecret) {
                    Label("Delete Secret", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding(24)
        }
        .frame(minWidth: 300)
    }
    
    var accessColor: Color {
        switch secret.accessLevel {
        case .public: return .green
        case .normal: return .blue
        case .sensitive: return .orange
        case .critical: return .red
        }
    }
    
    private func toggleReveal() {
        if isRevealed {
            isRevealed = false
            value = ""
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
            
            copied = true
            
            // Clear after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                NSPasteboard.general.clearContents()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copied = false
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
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Add Secret")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Path")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., github/token", text: $path)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Secret value", text: $value)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Access Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $accessLevel) {
                        ForEach(SecretEntry.AccessLevel.allCases, id: \.self) { level in
                            Label(level.rawValue.capitalized, systemImage: level.icon)
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(path.isEmpty || value.isEmpty || isLoading)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
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
        VStack(alignment: .leading, spacing: 12) {
            if vaultManager.isUnlocked {
                HStack {
                    Image(systemName: "lock.open.fill")
                        .foregroundColor(.green)
                    Text("Unlocked")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                Text("Quick Copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(vaultManager.secrets.prefix(5)) { secret in
                    Button(action: { copySecret(secret.path) }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text(secret.path)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                Button("Lock Vault") {
                    vaultManager.lock()
                }
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.red)
                    Text("Locked")
                        .fontWeight(.medium)
                }
                
                Text("Open ClawBox to unlock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button("Quit ClawBox") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Custom Styles

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
    }
}

struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultManager.shared)
}
