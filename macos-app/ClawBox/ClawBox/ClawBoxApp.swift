//
//  ClawBoxApp.swift
//  ClawBox
//
//  AI-Native Secret Manager - macOS App
//

import SwiftUI

@main
struct ClawBoxApp: App {
    @StateObject private var vaultManager = VaultManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Vault") {
                Button("Lock Vault") {
                    vaultManager.lock()
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
                .disabled(!vaultManager.isUnlocked)
            }
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(vaultManager)
        }
        
        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(vaultManager)
        } label: {
            Image(systemName: vaultManager.isUnlocked ? "lock.open.fill" : "lock.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
