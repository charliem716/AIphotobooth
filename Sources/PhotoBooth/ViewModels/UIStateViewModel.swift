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
    private let logger = Logger(subsystem: "PhotoBooth", category: "UIState")
    
    // MARK: - Settings
    @AppStorage("minimumDisplayDuration") var minimumDisplayDuration = 10.0
    
    // MARK: - Initialization
    init() {
        logger.info("UIStateViewModel initialized")
    }
    
    deinit {
        // Modern async patterns handle cleanup automatically via cancellation
        logDebug("\(LoggingService.Emoji.debug) UIStateViewModel deinitialized", category: .ui)
    }
    
    // MARK: - Public Methods
    
    /// Start countdown with specified duration using modern async patterns
    func startCountdown(duration: Int = 3) {
        guard !isCountingDown else {
            logger.warning("Countdown already in progress")
            return
        }
        
        logger.info("\(LoggingService.Emoji.timer) Starting countdown with duration: \(duration)")
        countdown = duration
        isCountingDown = true
        
        // Post notification for countdown start (for projector display)
        NotificationCenter.default.post(name: Notification.Name("countdownStart"), object: nil)
        
        // Start modern async countdown
        Task { @MainActor in
            await runCountdown()
        }
    }
    
    /// Stop current countdown (modernized for async patterns)
    func stopCountdown() {
        logger.info("\(LoggingService.Emoji.debug) Stopping countdown")
        isCountingDown = false
        countdown = 0
    }
    
    /// Start minimum display period
    func startMinimumDisplayPeriod() {
        logger.info("Starting minimum display period: \(self.minimumDisplayDuration) seconds")
        
        isReadyForNextPhoto = false
        isInMinimumDisplayPeriod = true
        minimumDisplayTimeRemaining = Int(minimumDisplayDuration)
        
        // Start modern async minimum display period
        Task { @MainActor in
            await runMinimumDisplayPeriod()
        }
    }
    
    /// Stop minimum display period (modernized for async patterns)
    func stopMinimumDisplayPeriod() {
        logger.info("\(LoggingService.Emoji.debug) Stopping minimum display period")
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
            hideError()
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
            hideSuccess()
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
            logger.debug("Countdown: \(self.countdown)")
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
            logger.debug("Minimum display remaining: \(self.minimumDisplayTimeRemaining)")
        } else {
            logger.info("Minimum display period completed")
            stopMinimumDisplayPeriod()
        }
    }
    
    private func invalidateTimers() {
        // Modern async patterns handle cleanup automatically via cancellation
        logDebug("\(LoggingService.Emoji.debug) Async timers will cancel automatically", category: .ui)
    }
    
    // MARK: - Modern Async Timer Implementations
    
    /// Modern async countdown implementation
    @MainActor
    private func runCountdown() async {
        while countdown > 0 && isCountingDown {
            try? await Task.sleep(for: .seconds(1))
            
            if isCountingDown && countdown > 0 {
                countdown -= 1
                logDebug("\(LoggingService.Emoji.timer) Countdown: \(countdown)", category: .ui)
            }
        }
        
        if isCountingDown && countdown <= 0 {
            logInfo("\(LoggingService.Emoji.success) Countdown completed", category: .ui)
            isCountingDown = false
            
            // Post notification that countdown finished - THIS WAS MISSING!
            NotificationCenter.default.post(name: .countdownFinished, object: nil)
        }
    }
    
    /// Modern async minimum display period implementation
    @MainActor
    private func runMinimumDisplayPeriod() async {
        while minimumDisplayTimeRemaining > 0 && isInMinimumDisplayPeriod {
            try? await Task.sleep(for: .seconds(1))
            
            if isInMinimumDisplayPeriod && minimumDisplayTimeRemaining > 0 {
                minimumDisplayTimeRemaining -= 1
                logDebug("\(LoggingService.Emoji.timer) Minimum display remaining: \(minimumDisplayTimeRemaining)", category: .ui)
            }
        }
        
        if minimumDisplayTimeRemaining <= 0 {
            logInfo("\(LoggingService.Emoji.success) Minimum display period completed - photo will remain displayed until new theme is selected", category: .ui)
            stopMinimumDisplayPeriod()
            
            // Note: No longer automatically returning to live camera view
            // Photo will remain displayed until a new theme is selected
        }
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