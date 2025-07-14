import SwiftUI
import Combine
import os.log

/// ViewModel responsible for UI state management, countdown, navigation, and user feedback
@MainActor
final class UIStateViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var countdown = 0
    @Published var isCountingDown = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isReadyForNextPhoto = true
    @Published var minimumDisplayTimeRemaining = 0
    @Published var isInMinimumDisplayPeriod = false
    @Published var currentView: AppView = .main
    @Published var showSuccess = false
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    private var countdownTimer: Timer?
    private var minimumDisplayTimer: Timer?
    private let logger = Logger(subsystem: "PhotoBooth", category: "UIState")
    
    // MARK: - Settings
    @AppStorage("minimumDisplayDuration") var minimumDisplayDuration = 10.0
    
    // MARK: - Initialization
    init() {
        logger.info("UIStateViewModel initialized")
    }
    
    deinit {
        invalidateTimers()
        logger.info("UIStateViewModel deinitialized")
    }
    
    // MARK: - Public Methods
    
    /// Start countdown with specified duration
    func startCountdown(duration: Int = 3) {
        guard !isCountingDown else {
            logger.warning("Countdown already in progress")
            return
        }
        
        logger.info("Starting countdown with duration: \(duration)")
        countdown = duration
        isCountingDown = true
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCountdown()
            }
        }
    }
    
    /// Stop current countdown
    func stopCountdown() {
        logger.info("Stopping countdown")
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        countdown = 0
    }
    
    /// Start minimum display period
    func startMinimumDisplayPeriod() {
        logger.info("Starting minimum display period: \(minimumDisplayDuration) seconds")
        
        isReadyForNextPhoto = false
        isInMinimumDisplayPeriod = true
        minimumDisplayTimeRemaining = Int(minimumDisplayDuration)
        
        minimumDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMinimumDisplayTimer()
            }
        }
    }
    
    /// Stop minimum display period
    func stopMinimumDisplayPeriod() {
        logger.info("Stopping minimum display period")
        minimumDisplayTimer?.invalidate()
        minimumDisplayTimer = nil
        isInMinimumDisplayPeriod = false
        minimumDisplayTimeRemaining = 0
        isReadyForNextPhoto = true
    }
    
    /// Show error message to user
    func showError(message: String, duration: TimeInterval = 5.0) {
        logger.error("Showing error: \(message)")
        errorMessage = message
        showError = true
        
        // Auto-hide after duration
        Task {
            try await Task.sleep(for: .seconds(duration))
            await hideError()
        }
    }
    
    /// Hide error message
    func hideError() {
        logger.debug("Hiding error message")
        showError = false
        errorMessage = nil
    }
    
    /// Show success message to user
    func showSuccess(message: String, duration: TimeInterval = 3.0) {
        logger.info("Showing success: \(message)")
        successMessage = message
        showSuccess = true
        
        // Auto-hide after duration
        Task {
            try await Task.sleep(for: .seconds(duration))
            await hideSuccess()
        }
    }
    
    /// Hide success message
    func hideSuccess() {
        logger.debug("Hiding success message")
        showSuccess = false
        successMessage = nil
    }
    
    /// Navigate to specific view
    func navigateTo(_ view: AppView) {
        logger.info("Navigating to view: \(view.rawValue)")
        currentView = view
    }
    
    /// Reset all UI state
    func resetAllState() {
        logger.info("Resetting all UI state")
        stopCountdown()
        stopMinimumDisplayPeriod()
        hideError()
        hideSuccess()
        currentView = .main
    }
    
    /// Check if UI is ready for photo capture
    var isReadyForPhoto: Bool {
        return isReadyForNextPhoto && 
               !isCountingDown && 
               !isInMinimumDisplayPeriod
    }
    
    /// Get UI status summary
    func getUIStatusSummary() -> UIStatusSummary {
        return UIStatusSummary(
            isCountingDown: isCountingDown,
            countdownValue: countdown,
            isInMinimumDisplay: isInMinimumDisplayPeriod,
            minimumDisplayRemaining: minimumDisplayTimeRemaining,
            isReadyForPhoto: isReadyForPhoto,
            hasError: showError,
            hasSuccess: showSuccess,
            currentView: currentView
        )
    }
    
    /// Update minimum display duration setting
    func updateMinimumDisplayDuration(_ duration: Double) {
        logger.info("Updating minimum display duration to: \(duration) seconds")
        minimumDisplayDuration = duration
    }
    
    // MARK: - Private Methods
    
    private func updateCountdown() async {
        guard isCountingDown else { return }
        
        if countdown > 0 {
            countdown -= 1
            logger.debug("Countdown: \(countdown)")
        } else {
            logger.info("Countdown completed")
            stopCountdown()
            
            // Notify that countdown finished via notification
            NotificationCenter.default.post(name: .countdownFinished, object: nil)
        }
    }
    
    private func updateMinimumDisplayTimer() async {
        guard isInMinimumDisplayPeriod else { return }
        
        if minimumDisplayTimeRemaining > 0 {
            minimumDisplayTimeRemaining -= 1
            logger.debug("Minimum display remaining: \(minimumDisplayTimeRemaining)")
        } else {
            logger.info("Minimum display period completed")
            stopMinimumDisplayPeriod()
        }
    }
    
    private func invalidateTimers() {
        countdownTimer?.invalidate()
        minimumDisplayTimer?.invalidate()
        countdownTimer = nil
        minimumDisplayTimer = nil
    }
}

// MARK: - Supporting Types

/// Application views for navigation
enum AppView: String, CaseIterable {
    case main = "Main"
    case settings = "Settings"
    case slideshow = "Slideshow"
    case camera = "Camera"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .main:
            return "house"
        case .settings:
            return "gear"
        case .slideshow:
            return "play.rectangle"
        case .camera:
            return "camera"
        }
    }
}

/// Summary of UI state for monitoring
struct UIStatusSummary {
    let isCountingDown: Bool
    let countdownValue: Int
    let isInMinimumDisplay: Bool
    let minimumDisplayRemaining: Int
    let isReadyForPhoto: Bool
    let hasError: Bool
    let hasSuccess: Bool
    let currentView: AppView
    
    var statusText: String {
        if isCountingDown {
            return "Countdown: \(countdownValue)"
        } else if isInMinimumDisplay {
            return "Display period: \(minimumDisplayRemaining)s remaining"
        } else if hasError {
            return "Error displayed"
        } else if hasSuccess {
            return "Success displayed"
        } else if isReadyForPhoto {
            return "Ready for photo"
        } else {
            return "Not ready"
        }
    }
    
    var statusIcon: String {
        if isCountingDown {
            return "timer"
        } else if isInMinimumDisplay {
            return "clock"
        } else if hasError {
            return "exclamationmark.triangle"
        } else if hasSuccess {
            return "checkmark.circle"
        } else if isReadyForPhoto {
            return "camera.fill"
        } else {
            return "pause.circle"
        }
    }
    
    var isOperational: Bool {
        return !hasError && (isReadyForPhoto || isCountingDown)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let countdownFinished = Notification.Name("countdownFinished")
    static let minimumDisplayCompleted = Notification.Name("minimumDisplayCompleted")
} 