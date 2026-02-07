//
//  ClawBoxApp.swift
//  ClawBox
//
//  AI-Native Secret Manager - iOS App
//

import SwiftUI

@main
struct ClawBoxApp: App {
    @StateObject private var vaultManager = VaultManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultManager)
        }
    }
}
