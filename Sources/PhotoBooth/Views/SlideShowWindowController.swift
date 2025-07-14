import SwiftUI
import AppKit

class SlideShowWindowController: NSWindowController {
    private var slideShowViewModel: SlideShowViewModel?
    private var hostingController: NSHostingController<SlideShowView>?
    
    // MARK: - Initialization
    
    init() {
        // Create window with normal controls (not borderless)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    /// Launch the slideshow on the optimal display
    func launchSlideshow(with viewModel: SlideShowViewModel) {
        self.slideShowViewModel = viewModel
        
        // Create SwiftUI view
        let slideShowView = SlideShowView(slideShowViewModel: viewModel)
        hostingController = NSHostingController(rootView: slideShowView)
        
        // Set up window content
        guard let window = window,
              let hostingController = hostingController else { return }
        
        window.contentViewController = hostingController
        
        // Determine optimal display with fallback - prefer secondary display
        let targetScreen = getOptimalDisplayWithFallback()
        
        logInfo("\(LoggingService.Emoji.slideshow) Slideshow will launch on: \(targetScreen.localizedName)", category: .slideshow)
        
        // Add delay to ensure projector window has fully hidden/exited fullscreen if it was visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.positionWindowOnScreen(targetScreen)
            
            // Ensure window is positioned correctly and stays on target screen  
            window.setFrame(window.frame, display: true)
            logDebug("\(LoggingService.Emoji.slideshow) Slideshow positioned on: \(targetScreen.localizedName)", category: .slideshow)
        }
        
        // Log initial display configuration
        logDisplayStatus()
        
        // Start display monitoring
        startDisplayMonitoring()
        
        // Show window normally (not fullscreen)  
        window.makeKeyAndOrderFront(nil)
        // Don't center - we already positioned it correctly above
        
        // Start the slideshow
        Task {
            logDebug("\(LoggingService.Emoji.slideshow) About to start slideshow in window controller", category: .slideshow)
            await viewModel.startSlideshow()
            logDebug("\(LoggingService.Emoji.slideshow) Slideshow start completed in window controller", category: .slideshow)
        }
        
        logInfo("\(LoggingService.Emoji.slideshow) Slideshow window launched on \(targetScreen.localizedName)", category: .slideshow)
        logDebug("\(LoggingService.Emoji.slideshow) Window is visible: \(window.isVisible)", category: .slideshow)
        logDebug("\(LoggingService.Emoji.slideshow) Window frame: \(window.frame)", category: .slideshow)
    }
    
    /// Close the slideshow window
    func closeSlideshow() {
        slideShowViewModel?.stopSlideshow()
        
        if let window = window {
            // Close window immediately (no fullscreen to exit)
            window.close()
        }
        
        logInfo("\(LoggingService.Emoji.slideshow) Slideshow window closed", category: .slideshow)
    }
    
    // MARK: - Private Methods
    
    private func setupWindow() {
        guard let window = window else { return }
        
        // Window configuration
        window.title = "PhotoBooth Slideshow - Press ESC or Close Window to Exit"
        window.backgroundColor = .black
        window.level = .normal  // Use normal level to avoid interfering with system UI
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.canHide = false  // Don't allow hiding to prevent accidental dismissal
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        
        // Handle window events
        window.delegate = self
        
        // Set up fullscreen behavior
        window.collectionBehavior = [.fullScreenPrimary, .managed]
    }
    
    private func getOptimalDisplay() -> NSScreen {
        let screens = NSScreen.screens
        
        // ALWAYS prefer secondary display if available - slideshow should take precedence
        if screens.count > 1 {
            // Always use the second screen (index 1) for slideshow
            let secondaryScreen = screens[1]
            logInfo("\(LoggingService.Emoji.slideshow) Forcing slideshow to secondary display: \(secondaryScreen.localizedName)", category: .slideshow)
            return secondaryScreen
        }
        
        // Only fallback to main screen if no secondary display exists
        logInfo("\(LoggingService.Emoji.slideshow) No secondary display available, using main screen", category: .slideshow)
        return NSScreen.main ?? screens.first!
    }
    
    private func positionWindowOnScreen(_ screen: NSScreen) {
        guard let window = window else { return }
        
        // Create a large window that covers most of the screen but is not fullscreen
        let margin: CGFloat = 50
        let windowFrame = CGRect(
            x: screen.frame.origin.x + margin,
            y: screen.frame.origin.y + margin,
            width: screen.frame.width - (margin * 2),
            height: screen.frame.height - (margin * 2)
        )
        
        window.setFrame(windowFrame, display: true)
        
        logDebug("\(LoggingService.Emoji.slideshow) Positioned slideshow window on screen: \(screen.localizedName) (\(Int(windowFrame.width))x\(Int(windowFrame.height))) at (\(Int(windowFrame.origin.x)), \(Int(windowFrame.origin.y)))", category: .slideshow)
    }
    
    deinit {
        stopDisplayMonitoring()
    }
}

// MARK: - NSWindowDelegate
extension SlideShowWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) windowWillClose called - slideshow was active: \(slideShowViewModel?.isActive ?? false)", category: .slideshow)
        
        // Stop slideshow and notify main app
        slideShowViewModel?.stopSlideshow()
        
        // Notify main app that slideshow was closed
        NotificationCenter.default.post(
            name: .restoreProjectorAfterSlideshow,
            object: nil,
            userInfo: nil
        )
        
        slideShowViewModel = nil
        hostingController = nil
        logInfo("\(LoggingService.Emoji.slideshow) Slideshow window closed by user", category: .slideshow)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow entered fullscreen mode successfully", category: .slideshow)
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow ViewModel active: \(slideShowViewModel?.isActive ?? false)", category: .slideshow)
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow exited fullscreen mode", category: .slideshow)
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow ViewModel active: \(slideShowViewModel?.isActive ?? false)", category: .slideshow)
        // Don't auto-close when exiting fullscreen anymore
    }
    
    func windowWillEnterFullScreen(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow WILL enter fullscreen mode", category: .slideshow)
    }
    
    func windowWillExitFullScreen(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow WILL exit fullscreen mode", category: .slideshow) 
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        logDebug("\(LoggingService.Emoji.slideshow) windowShouldClose called", category: .slideshow)
        // Always allow closing
        return true
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow window became main", category: .slideshow)
    }
    
    func windowDidResignMain(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow window resigned main", category: .slideshow)
    }
    
    func windowWillMiniaturize(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow window will miniaturize", category: .slideshow)
    }
    
    // Handle ESC key and other shortcuts
    func windowDidBecomeKey(_ notification: Notification) {
        logDebug("\(LoggingService.Emoji.slideshow) Slideshow window became key", category: .slideshow)
        // Ensure window can receive key events
        window?.makeFirstResponder(hostingController?.view)
    }
}

// MARK: - Display Management Extensions
extension SlideShowWindowController {
    
    /// Handle display configuration changes
    @objc private func handleDisplayChange(_ notification: Notification) {
        guard let window = window,
              window.isVisible else { return }
        
        logDebug("\(LoggingService.Emoji.slideshow) Display configuration changed, adapting slideshow...", category: .slideshow)
        
        // If window is in fullscreen mode, don't move it around
        if window.styleMask.contains(.fullScreen) {
            logDebug("\(LoggingService.Emoji.slideshow) Window is in fullscreen - ignoring display change to prevent repositioning", category: .slideshow)
            return
        }
        
        // Get current and new optimal displays with fallback
        let currentScreen = window.screen
        let newOptimalScreen = getOptimalDisplayWithFallback()
        
        // Check if we need to move to a different display
        if currentScreen != newOptimalScreen {
            logInfo("\(LoggingService.Emoji.slideshow) Moving slideshow from \(currentScreen?.localizedName ?? "Unknown") to \(newOptimalScreen.localizedName)", category: .slideshow)
            positionWindowOnScreen(newOptimalScreen)
        } else {
            // Same display, just update position if needed (but only if not fullscreen)
            logDebug("\(LoggingService.Emoji.slideshow) Adjusting position on current display", category: .slideshow)
            positionWindowOnScreen(newOptimalScreen)
        }
        
        // Log display status for debugging
        logDisplayStatus()
    }
    
    /// Start monitoring display changes
    private func startDisplayMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        logDebug("\(LoggingService.Emoji.slideshow) Started monitoring display configuration changes", category: .slideshow)
    }
    
    /// Stop monitoring display changes
    private func stopDisplayMonitoring() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
}

// MARK: - Convenience Methods
extension SlideShowWindowController {
    
    /// Check if slideshow is currently active
    var isSlideShowActive: Bool {
        return slideShowViewModel?.isActive == true && window?.isVisible == true
    }
    
    /// Get information about current display setup
    var displayInfo: String {
        let screens = NSScreen.screens
        let mainScreen = NSScreen.main
        
        if screens.count == 1 {
            return "Single display: \(mainScreen?.localizedName ?? "Unknown")"
        } else {
            return "Multi-display: \(screens.count) screens available"
        }
    }
    
    /// Log current display status for debugging
    private func logDisplayStatus() {
        let screens = NSScreen.screens
        logDebug("\(LoggingService.Emoji.slideshow) Current display configuration:", category: .slideshow)
        logDebug("\(LoggingService.Emoji.slideshow) Total screens: \(screens.count)", category: .slideshow)
        
        for (index, screen) in screens.enumerated() {
            let isMain = screen == NSScreen.main
            let frame = screen.frame
            logDebug("\(LoggingService.Emoji.slideshow) \(index + 1). \(screen.localizedName) \(isMain ? "(Main)" : "")", category: .slideshow)
            logDebug("\(LoggingService.Emoji.slideshow) Frame: \(Int(frame.width))x\(Int(frame.height)) at (\(Int(frame.origin.x)), \(Int(frame.origin.y)))", category: .slideshow)
        }
        
        if let window = window, window.isVisible {
            let currentScreen = window.screen
            logDebug("\(LoggingService.Emoji.slideshow) Slideshow currently on: \(currentScreen?.localizedName ?? "Unknown")", category: .slideshow)
        }
    }
    
    /// Enhanced display selection with fallback logic
    private func getOptimalDisplayWithFallback() -> NSScreen {
        let screens = NSScreen.screens
        let optimalScreen = getOptimalDisplay()
        
        // Verify the selected screen is still valid
        if screens.contains(optimalScreen) {
            return optimalScreen
        } else {
            logWarning("\(LoggingService.Emoji.warning) Previously selected display no longer available, falling back to main display", category: .slideshow)
            return NSScreen.main ?? screens.first!
        }
    }
} 