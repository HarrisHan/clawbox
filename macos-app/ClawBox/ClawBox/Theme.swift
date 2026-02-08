//
//  Theme.swift
//  ClawBox macOS
//
//  Black & Gold Theme with Light/Dark Mode Support
//

import SwiftUI

// MARK: - Adaptive Colors

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
                                       dark: .init(red: 0.08, green: 0.08, blue: 0.10))
    static let clawSurface = Color(light: .init(white: 1.0),
                                    dark: .init(red: 0.12, green: 0.12, blue: 0.14))
    static let clawSurfaceLight = Color(light: .init(red: 0.94, green: 0.94, blue: 0.95),
                                         dark: .init(red: 0.16, green: 0.16, blue: 0.18))
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
}

// Helper for adaptive colors
extension Color {
    init(light: Color, dark: Color) {
        self.init(NSColor { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
    }
}

// MARK: - Modern Button Styles

struct ModernPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
            }
            configuration.label
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Color.clawGradient)
        .cornerRadius(10)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .opacity(configuration.isPressed ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.clawPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.clawPrimary.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.clawPrimary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Modern Text Field Style

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.clawSurfaceLight)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.clawPrimary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Logo View

struct ClawBoxLogo: View {
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(Color.clawPrimary)
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: size * 0.25)
                .opacity(0.4)
            
            // Background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color.clawSurface)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22)
                        .stroke(Color.clawPrimary.opacity(0.3), lineWidth: 1.5)
                )
            
            // Key icon
            Image(systemName: "key.fill")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(Color.clawGradient)
                .rotationEffect(.degrees(-45))
        }
    }
}
