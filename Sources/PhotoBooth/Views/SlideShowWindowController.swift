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
        
        // Determine optimal display with fallback
        let targetScreen = getOptimalDisplayWithFallback()
        positionWindowOnScreen(targetScreen)
        
        // Log initial display configuration
        logDisplayStatus()
        
        // Start display monitoring
        startDisplayMonitoring()
        
        // Show window normally (not fullscreen)  
        window.makeKeyAndOrderFront(nil)
        // Don't center - we already positioned it correctly above
        
        // Start the slideshow
        Task {
            print("🎬 About to start slideshow in window controller")
            await viewModel.startSlideshow()
            print("🎬 Slideshow start completed in window controller")
        }
        
        print("🎬 Slideshow window launched on \(targetScreen.localizedName)")
        print("🎬 Window is visible: \(window.isVisible)")
        print("🎬 Window frame: \(window.frame)")
    }
    
    /// Close the slideshow window
    func closeSlideshow() {
        slideShowViewModel?.stopSlideshow()
        
        if let window = window {
            // Close window immediately (no fullscreen to exit)
            window.close()
        }
        
        print("🛑 Slideshow window closed")
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
        
        // Prefer secondary display if available
        if screens.count > 1 {
            // Find the screen that's not the main screen
            for screen in screens {
                if screen != NSScreen.main {
                    return screen
                }
            }
        }
        
        // Fallback to main screen
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
        
        print("📺 Positioned slideshow window on screen: \(screen.localizedName) (\(Int(windowFrame.width))x\(Int(windowFrame.height))) at (\(Int(windowFrame.origin.x)), \(Int(windowFrame.origin.y)))")
    }
    
    deinit {
        stopDisplayMonitoring()
    }
}

// MARK: - NSWindowDelegate
extension SlideShowWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("📺 windowWillClose called - slideshow was active: \(slideShowViewModel?.isActive ?? false)")
        
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
        print("📺 Slideshow window closed by user")
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        print("📺 Slideshow entered fullscreen mode")
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        print("📺 Slideshow exited fullscreen mode")
        // Don't auto-close when exiting fullscreen anymore
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("📺 windowShouldClose called")
        // Always allow closing
        return true
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        print("📺 Slideshow window became main")
    }
    
    func windowDidResignMain(_ notification: Notification) {
        print("📺 Slideshow window resigned main")
    }
    
    func windowWillMiniaturize(_ notification: Notification) {
        print("📺 Slideshow window will miniaturize")
    }
    
    // Handle ESC key and other shortcuts
    func windowDidBecomeKey(_ notification: Notification) {
        print("📺 Slideshow window became key")
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
        
        print("📺 Display configuration changed, adapting slideshow...")
        
        // Get current and new optimal displays with fallback
        let currentScreen = window.screen
        let newOptimalScreen = getOptimalDisplayWithFallback()
        
        // Check if we need to move to a different display
        if currentScreen != newOptimalScreen {
            print("📺 Moving slideshow from \(currentScreen?.localizedName ?? "Unknown") to \(newOptimalScreen.localizedName)")
            
            // Exit fullscreen on current display
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
                
                // Wait for fullscreen exit, then move and re-enter fullscreen
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.positionWindowOnScreen(newOptimalScreen)
                    window.toggleFullScreen(nil)
                }
            } else {
                positionWindowOnScreen(newOptimalScreen)
            }
        } else {
            // Same display, just update position if needed
            print("📺 Adjusting position on current display")
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
        print("📺 Started monitoring display configuration changes")
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
        print("📺 Current display configuration:")
        print("   Total screens: \(screens.count)")
        
        for (index, screen) in screens.enumerated() {
            let isMain = screen == NSScreen.main
            let frame = screen.frame
            print("   \(index + 1). \(screen.localizedName) \(isMain ? "(Main)" : "")")
            print("      Frame: \(Int(frame.width))x\(Int(frame.height)) at (\(Int(frame.origin.x)), \(Int(frame.origin.y)))")
        }
        
        if let window = window, window.isVisible {
            let currentScreen = window.screen
            print("   Slideshow currently on: \(currentScreen?.localizedName ?? "Unknown")")
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
            print("⚠️ Previously selected display no longer available, falling back to main display")
            return NSScreen.main ?? screens.first!
        }
    }
} 