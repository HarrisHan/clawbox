//
//  AutoLockService.swift
//  ClawBox
//
//  Auto-lock vault after timeout or on screen lock
//

import Foundation
import Combine

/// Auto-lock policy
enum AutoLockPolicy: String, CaseIterable, Codable {
    case never = "never"
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case onScreenLock = "screen"
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .onScreenLock: return "When screen locks"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .never: return nil
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        case .oneHour: return 3600
        case .onScreenLock: return nil
        }
    }
}

/// Auto-lock service
class AutoLockService: ObservableObject {
    static let shared = AutoLockService()
    
    @Published var policy: AutoLockPolicy = .fiveMinutes {
        didSet {
            savePolicy()
            resetTimer()
        }
    }
    
    private var timer: Timer?
    private var lastActivity = Date()
    private var cancellables = Set<AnyCancellable>()
    private var onLock: (() -> Void)?
    
    private init() {
        loadPolicy()
        setupScreenLockObserver()
    }
    
    /// Start monitoring with lock callback
    func start(onLock: @escaping () -> Void) {
        self.onLock = onLock
        lastActivity = Date()  // Reset activity timestamp
        resetTimer()
    }
    
    /// Record user activity to reset timer
    func recordActivity() {
        lastActivity = Date()
        resetTimer()
    }
    
    /// Stop monitoring
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Private
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        
        guard let interval = policy.timeInterval else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let elapsed = Date().timeIntervalSince(self.lastActivity)
            if elapsed >= interval {
                self.triggerLock()
            }
        }
    }
    
    private func triggerLock() {
        timer?.invalidate()
        timer = nil
        onLock?()
    }
    
    private func setupScreenLockObserver() {
        // Observe screen lock notifications
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name("com.apple.screenIsLocked"))
            .sink { [weak self] _ in
                if self?.policy == .onScreenLock {
                    self?.triggerLock()
                }
            }
            .store(in: &cancellables)
    }
    
    private func savePolicy() {
        UserDefaults.standard.set(policy.rawValue, forKey: "autoLockPolicy")
    }
    
    private func loadPolicy() {
        if let rawValue = UserDefaults.standard.string(forKey: "autoLockPolicy"),
           let policy = AutoLockPolicy(rawValue: rawValue) {
            self.policy = policy
        }
    }
}
