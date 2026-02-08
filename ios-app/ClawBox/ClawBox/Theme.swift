//
//  Theme.swift
//  ClawBox iOS
//
//  Design system and theme
//

import SwiftUI

// MARK: - Colors

// MARK: - Adaptive Colors (Light + Dark Mode)

extension Color {
    // Primary Gold - works well on both light and dark
    static let clawPrimary = Color(light: .init(red: 0.75, green: 0.55, blue: 0.10),
                                    dark: .init(red: 1.0, green: 0.78, blue: 0.31))
    static let clawSecondary = Color(light: .init(red: 0.65, green: 0.45, blue: 0.05),
                                      dark: .init(red: 0.85, green: 0.65, blue: 0.20))
    
    static let clawAccent = Color(red: 0.95, green: 0.30, blue: 0.30)       // Red (errors)
    static let clawSuccess = Color(red: 0.20, green: 0.75, blue: 0.50)      // Green
    static let clawWarning = Color(red: 0.95, green: 0.65, blue: 0.20)      // Orange
    
    // Backgrounds - adaptive
    static let clawBackground = Color(light: .init(red: 0.96, green: 0.96, blue: 0.97),
                                       dark: .init(red: 0.06, green: 0.06, blue: 0.08))
    static let clawSurface = Color(light: .init(white: 1.0),
                                    dark: .init(red: 0.10, green: 0.10, blue: 0.12))
    static let clawSurfaceLight = Color(light: .init(red: 0.94, green: 0.94, blue: 0.95),
                                         dark: .init(red: 0.14, green: 0.14, blue: 0.17))
    static let clawText = Color(light: .init(red: 0.10, green: 0.10, blue: 0.12),
                                 dark: .white)
    static let clawTextSecondary = Color(light: .init(white: 0.45),
                                          dark: .init(white: 0.55))
    
    // Gradient colors
    static let goldLight = Color(red: 0.95, green: 0.75, blue: 0.25)
    static let goldDark = Color(red: 0.80, green: 0.55, blue: 0.10)
    
    static var clawGradient: LinearGradient {
        LinearGradient(
            colors: [goldLight, goldDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var clawGradientSubtle: LinearGradient {
        LinearGradient(
            colors: [goldLight.opacity(0.25), goldDark.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Helper for adaptive colors
extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    var padding: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.clawSurface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Glass Card Style

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                ZStack {
                    Color.clawSurface.opacity(0.7)
                    Color.clawGradientSubtle
                }
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardStyle())
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                configuration.label
            }
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.clawGradient)
        .cornerRadius(14)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .opacity(configuration.isPressed ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.clawPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.clawPrimary.opacity(0.15))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.clawPrimary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(Color.clawSurfaceLight)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Custom Text Field

struct ClawTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.clawTextSecondary)
                    .frame(width: 24)
            }
            
            if isSecure && !isRevealed {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.clawTextSecondary))
                    .focused($isFocused)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.clawTextSecondary))
                    .focused($isFocused)
            }
            
            if isSecure {
                Button(action: { isRevealed.toggle() }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundColor(.clawTextSecondary)
                }
            }
        }
        .foregroundColor(.clawText)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.clawSurfaceLight)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.clawPrimary : Color.white.opacity(0.1), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Logo View

struct ClawBoxLogo: View {
    var size: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Outer glow effect - gold
            Circle()
                .fill(Color.clawPrimary)
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: size * 0.35)
                .opacity(0.4)
            
            // Icon background - larger, darker
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(Color.clawSurface)
                .frame(width: size * 1.15, height: size * 1.15)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28)
                        .stroke(Color.clawPrimary.opacity(0.3), lineWidth: 2)
                )
            
            // Gold key icon
            Image(systemName: "key.fill")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(Color.clawGradient)
                .rotationEffect(.degrees(-45))
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(Color.clawGradient)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.clawText)
            
            Text(message)
                .font(.body)
                .foregroundColor(.clawTextSecondary)
                .multilineTextAlignment(.center)
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
                .padding(.top, 8)
            }
        }
        .padding(40)
    }
}

// MARK: - Secret Row

struct SecretRow: View {
    let secret: SecretEntry
    
    var iconName: String {
        let path = secret.path.lowercased()
        if path.contains("api") || path.contains("token") {
            return "key.fill"
        } else if path.contains("password") || path.contains("pass") {
            return "lock.fill"
        } else if path.contains("ssh") {
            return "terminal.fill"
        } else if path.contains("github") || path.contains("git") {
            return "chevron.left.forwardslash.chevron.right"
        } else if path.contains("aws") || path.contains("cloud") {
            return "cloud.fill"
        } else if path.contains("db") || path.contains("database") {
            return "cylinder.fill"
        } else if path.contains("email") || path.contains("mail") {
            return "envelope.fill"
        }
        return "key.fill"
    }
    
    var accessColor: Color {
        switch secret.accessLevel.lowercased() {
        case "critical": return .clawAccent
        case "sensitive": return .clawWarning
        case "normal": return .clawPrimary
        default: return .clawTextSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clawPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(.clawPrimary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(secret.path)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .foregroundColor(.clawText)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(accessColor)
                        .frame(width: 6, height: 6)
                    
                    Text(secret.accessLevel.capitalized)
                        .font(.caption)
                        .foregroundColor(.clawTextSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.clawTextSecondary)
        }
        .padding(.vertical, 8)
    }
}
