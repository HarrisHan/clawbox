//
//  ContentView.swift
//  ClawBox iOS
//
//  Modern UI with glass morphism and gradient accents
//

import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    
    var body: some View {
        ZStack {
            // Background
            Color.clawBackground
                .ignoresSafeArea()
            
            // Content
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
        }
        // .preferredColorScheme(.dark)  // Comment out to allow system theme
    }
}

// MARK: - Initialize View

struct InitializeView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showContent = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)
                
                // Logo with animation
                ClawBoxLogo(size: 120)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                
                VStack(spacing: 12) {
                    Text("Welcome to ClawBox")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.clawText)
                    
                    Text("Create a master password to secure your secrets")
                        .font(.body)
                        .foregroundColor(.clawTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                VStack(spacing: 16) {
                    ClawTextField(
                        placeholder: "Master Password",
                        text: $password,
                        isSecure: true,
                        icon: "lock.fill"
                    )
                    
                    ClawTextField(
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        isSecure: true,
                        icon: "lock.fill"
                    )
                    
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .foregroundColor(.clawAccent)
                        .font(.caption)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Password requirements
                    VStack(alignment: .leading, spacing: 8) {
                        PasswordRequirement(
                            text: "At least 8 characters",
                            isMet: password.count >= 8
                        )
                        PasswordRequirement(
                            text: "Passwords match",
                            isMet: !password.isEmpty && password == confirmPassword
                        )
                    }
                    .padding(.top, 8)
                    
                    Button(action: initialize) {
                        Text("Create Vault")
                    }
                    .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                    .disabled(password.count < 8 || password != confirmPassword || isLoading)
                    .opacity(password.count < 8 || password != confirmPassword ? 0.6 : 1)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
    
    private func initialize() {
        guard password == confirmPassword else {
            withAnimation {
                errorMessage = "Passwords do not match"
            }
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try vaultManager.initialize(password: password)
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
}

// MARK: - Password Requirement

struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .clawSuccess : .clawTextSecondary)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .clawText : .clawTextSecondary)
        }
    }
}

// MARK: - Unlock View

struct UnlockView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showContent = false
    @State private var shakeOffset: CGFloat = 0
    
    private let context = LAContext()
    
    var biometricsAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var biometricIcon: String {
        context.biometryType == .faceID ? "faceid" : "touchid"
    }
    
    var biometricType: String {
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo
            ClawBoxLogo(size: 100)
                .scaleEffect(showContent ? 1 : 0.8)
                .opacity(showContent ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.clawText)
                
                Text("Unlock your vault to continue")
                    .font(.body)
                    .foregroundColor(.clawTextSecondary)
            }
            .opacity(showContent ? 1 : 0)
            
            VStack(spacing: 20) {
                // Biometric button
                if biometricsAvailable {
                    Button(action: unlockWithBiometrics) {
                        HStack(spacing: 12) {
                            Image(systemName: biometricIcon)
                                .font(.title2)
                            Text("Unlock with \(biometricType)")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                    
                    HStack {
                        Rectangle()
                            .fill(Color.clawTextSecondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("or use password")
                            .font(.caption)
                            .foregroundColor(.clawTextSecondary)
                        
                        Rectangle()
                            .fill(Color.clawTextSecondary.opacity(0.3))
                            .frame(height: 1)
                    }
                }
                
                // Password field
                ClawTextField(
                    placeholder: "Master Password",
                    text: $password,
                    isSecure: true,
                    icon: "lock.fill"
                )
                .offset(x: shakeOffset)
                
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .foregroundColor(.clawAccent)
                    .font(.caption)
                    .transition(.opacity)
                }
                
                Button(action: unlock) {
                    Text("Unlock")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(password.isEmpty || isLoading)
                .opacity(password.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 24)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
            
            // Auto-trigger biometrics
            if biometricsAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    unlockWithBiometrics()
                }
            }
        }
    }
    
    private func unlock() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try vaultManager.unlock(password: password)
            } catch {
                await MainActor.run {
                    withAnimation {
                        errorMessage = "Invalid password"
                    }
                    // Shake animation
                    withAnimation(.default) {
                        shakeOffset = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.default) { shakeOffset = -10 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.default) { shakeOffset = 10 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.default) { shakeOffset = 0 }
                    }
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func unlockWithBiometrics() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await vaultManager.unlockWithBiometrics()
            } catch {
                await MainActor.run {
                    withAnimation {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Secrets List View

struct SecretsListView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showExportSheet = false
    @State private var showContent = false
    
    var filteredSecrets: [SecretEntry] {
        if searchText.isEmpty {
            return vaultManager.secrets
        }
        return vaultManager.secrets.filter {
            $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clawBackground
                    .ignoresSafeArea()
                
                if vaultManager.secrets.isEmpty {
                    EmptyStateView(
                        icon: "key.slash",
                        title: "No Secrets Yet",
                        message: "Add your first secret to get started",
                        action: { showAddSheet = true },
                        actionTitle: "Add Secret"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(filteredSecrets.enumerated()), id: \.element.id) { index, secret in
                                NavigationLink(destination: SecretDetailView(secret: secret)) {
                                    SecretRow(secret: secret)
                                        .cardStyle(padding: 12)
                                }
                                .buttonStyle(.plain)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                    value: showContent
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Secrets")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search secrets"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showExportSheet = true }) {
                            Label("Export Vault", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { vaultManager.lock() }) {
                            Label("Lock Vault", systemImage: "lock.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.clawPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.clawGradient)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSecretView()
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView()
            }
        }
        .tint(.clawPrimary)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}

// MARK: - Secret Detail View

struct SecretDetailView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) var dismiss
    let secret: SecretEntry
    
    @State private var value = ""
    @State private var isRevealed = false
    @State private var isLoading = false
    @State private var copied = false
    @State private var showDeleteConfirm = false
    
    var accessColor: Color {
        switch secret.accessLevel.lowercased() {
        case "critical": return .clawAccent
        case "sensitive": return .clawWarning
        case "normal": return .clawPrimary
        default: return .clawTextSecondary
        }
    }
    
    var body: some View {
        ZStack {
            Color.clawBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header card
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.clawPrimary.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "key.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.clawGradient)
                        }
                        
                        // Path
                        Text(secret.path)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.clawText)
                        
                        // Access level badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(accessColor)
                                .frame(width: 8, height: 8)
                            
                            Text(secret.accessLevel.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(accessColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accessColor.opacity(0.15))
                        .cornerRadius(20)
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .padding(.horizontal, 16)
                    
                    // Value card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SECRET VALUE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.clawTextSecondary)
                        
                        HStack {
                            Text(isRevealed ? value : "••••••••••••••••")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.clawText)
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: toggleReveal) {
                                HStack {
                                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                                    Text(isRevealed ? "Hide" : "Reveal")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button(action: copyValue) {
                                HStack {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    Text(copied ? "Copied!" : "Copy")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, 16)
                    
                    // Delete button
                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Secret")
                        }
                        .foregroundColor(.clawAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.clawAccent.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this secret?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                try? vaultManager.deleteSecret(secret.path)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func toggleReveal() {
        if isRevealed {
            withAnimation {
                isRevealed = false
                value = ""
            }
        } else {
            isLoading = true
            do {
                value = try vaultManager.getSecret(secret.path)
                withAnimation {
                    isRevealed = true
                }
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
            
            withAnimation {
                copied = true
            }
            
            // Clear clipboard after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if UIPasteboard.general.string == val {
                    UIPasteboard.general.string = ""
                }
            }
            
            // Reset copied state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    copied = false
                }
            }
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
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
    @State private var accessLevel = "normal"
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    let accessLevels = ["public", "normal", "sensitive", "critical"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clawBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.clawPrimary.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(Color.clawGradient)
                        }
                        .padding(.top, 20)
                        
                        Text("Add New Secret")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.clawText)
                        
                        VStack(spacing: 16) {
                            ClawTextField(
                                placeholder: "Path (e.g., github/token)",
                                text: $path,
                                icon: "folder"
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            
                            ClawTextField(
                                placeholder: "Secret Value",
                                text: $value,
                                isSecure: true,
                                icon: "key"
                            )
                            
                            // Access level picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ACCESS LEVEL")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.clawTextSecondary)
                                
                                HStack(spacing: 8) {
                                    ForEach(accessLevels, id: \.self) { level in
                                        AccessLevelButton(
                                            level: level,
                                            isSelected: accessLevel == level,
                                            action: { accessLevel = level }
                                        )
                                    }
                                }
                            }
                            
                            if let error = errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                }
                                .foregroundColor(.clawAccent)
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Button(action: save) {
                            Text("Save Secret")
                        }
                        .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                        .disabled(path.isEmpty || value.isEmpty || isLoading)
                        .opacity(path.isEmpty || value.isEmpty ? 0.6 : 1)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.clawTextSecondary)
                }
            }
        }
    }
    
    private func save() {
        isLoading = true
        do {
            try vaultManager.setSecret(path: path, value: value, accessLevel: accessLevel)
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            dismiss()
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

// MARK: - Access Level Button

struct AccessLevelButton: View {
    let level: String
    let isSelected: Bool
    let action: () -> Void
    
    var color: Color {
        switch level.lowercased() {
        case "critical": return .clawAccent
        case "sensitive": return .clawWarning
        case "normal": return .clawPrimary
        default: return .clawTextSecondary
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(level.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.15))
                .cornerRadius(8)
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFormat = "json"
    @State private var exportedContent = ""
    @State private var copied = false
    
    let formats = [
        ("json", "JSON", "doc.text"),
        ("env", "ENV", "terminal"),
        ("yaml", "YAML", "doc.plaintext")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clawBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Export Vault")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.clawText)
                        .padding(.top, 20)
                    
                    // Format selector
                    HStack(spacing: 12) {
                        ForEach(formats, id: \.0) { format in
                            Button(action: { selectedFormat = format.0 }) {
                                VStack(spacing: 8) {
                                    Image(systemName: format.2)
                                        .font(.title2)
                                    Text(format.1)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(selectedFormat == format.0 ? .white : .clawTextSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(
                                    selectedFormat == format.0 ? 
                                        AnyShapeStyle(Color.clawGradient) : 
                                        AnyShapeStyle(Color.clawSurface)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Preview
                    if !exportedContent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PREVIEW")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.clawTextSecondary)
                            
                            ScrollView {
                                Text(exportedContent)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.clawText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        }
                        .cardStyle()
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: exportVault) {
                            Text("Generate Export")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        if !exportedContent.isEmpty {
                            Button(action: copyExport) {
                                HStack {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    Text(copied ? "Copied!" : "Copy to Clipboard")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.clawTextSecondary)
                }
            }
        }
    }
    
    private func exportVault() {
        // TODO: Implement actual export from VaultManager
        exportedContent = "{\n  \"secrets\": [\n    // Export will appear here\n  ]\n}"
    }
    
    private func copyExport() {
        UIPasteboard.general.string = exportedContent
        
        withAnimation {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultManager())
}
