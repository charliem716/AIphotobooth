import SwiftUI
import Combine

extension Notification.Name {
    static let photoCapture = Notification.Name("photoCapture")
    static let processingStart = Notification.Name("processingStart")
    static let processingDone = Notification.Name("processingDone")
    static let resetProjector = Notification.Name("resetProjector")
    static let countdownStart = Notification.Name("countdownStart")
    static let showError = Notification.Name("showError")
    static let returnToLiveCamera = Notification.Name("returnToLiveCamera")
    static let hideProjectorForSlideshow = Notification.Name("hideProjectorForSlideshow")
    static let restoreProjectorAfterSlideshow = Notification.Name("restoreProjectorAfterSlideshow")
}

enum ProjectorState {
    case idle                    // "AI Photo Booth" screen
    case liveCamera             // Live camera feed
    case countdown              // Countdown overlay on camera
    case showingOriginal        // Original photo + processing overlay
    case processingComplete     // "Get ready for the reveal!" warning
    case showingThemed         // Final themed image display
    case minimumDisplay        // Minimum display period for themed image
    case error                 // Error state with funny message
}

struct ProjectorView: View {
    @EnvironmentObject var viewModel: PhotoBoothViewModel
    @State private var originalImage: NSImage?
    @State private var themedImage: NSImage?
    @State private var showControls = false
    @State private var isFullscreen = false
    @State private var projectorState: ProjectorState = .liveCamera
    @State private var processingStartTime: Date?
    @State private var showWarning = false
    @State private var warningCountdown = 3
    @State private var selectedThemeName: String = ""
    @State private var errorMessage: String = ""
    @AppStorage("warningDuration") private var warningDuration = 3.0
    
    private let photoPublisher = NotificationCenter.default
        .publisher(for: .newPhotoCapture)
    private let photoCapturePublisher = NotificationCenter.default
        .publisher(for: .photoCapture)
    private let processingStartPublisher = NotificationCenter.default
        .publisher(for: .processingStart)
    private let processingDonePublisher = NotificationCenter.default
        .publisher(for: .processingDone)
    private let resetProjectorPublisher = NotificationCenter.default
        .publisher(for: .resetProjector)
    private let countdownStartPublisher = NotificationCenter.default
        .publisher(for: .countdownStart)
    private let showErrorPublisher = NotificationCenter.default
        .publisher(for: .showError)
    private let returnToLiveCameraPublisher = NotificationCenter.default
        .publisher(for: .returnToLiveCamera)
    
    var onClose: (() -> Void)?
    var onToggleFullscreen: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Main content based on projector state
            switch projectorState {
            case .idle:
                idleView
                
            case .liveCamera:
                ProjectorCameraView(session: viewModel.captureSession)
                
            case .countdown:
                ProjectorCountdownView(
                    session: viewModel.captureSession
                )
                
            case .showingOriginal:
                originalWithProcessingView
                
            case .processingComplete:
                if showWarning {
                    warningView
                } else {
                    originalWithProcessingView
                }
                
            case .showingThemed, .minimumDisplay:
                themedImageView
                
            case .error:
                ErrorMessageView(errorMessage: errorMessage)
            }
            
            // Overlay controls
            controlsOverlay
        }
        .onReceive(photoCapturePublisher) { notification in
            handlePhotoCapture(notification)
        }
        .onReceive(processingStartPublisher) { notification in
            handleProcessingStart(notification)
        }
        .onReceive(processingDonePublisher) { notification in
            handleProcessingDone(notification)
        }
        .onReceive(photoPublisher) { notification in
            handleFinalResult(notification)
        }
        .onReceive(resetProjectorPublisher) { _ in
            resetToLiveCamera()
        }
        .onReceive(countdownStartPublisher) { _ in
            handleCountdownStart()
        }
        .onReceive(showErrorPublisher) { notification in
            handleShowError(notification)
        }
        .onReceive(returnToLiveCameraPublisher) { _ in
            returnToLiveCamera()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = hovering
            }
        }
        .background(
            KeyEventHandlingView { event in
                if event.keyCode == 53 { // ESC key
                    onClose?()
                    return true
                }
                return false
            }
        )
    }
    
    // MARK: - View Components
    
    private var idleView: some View {
        VStack {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 72))
                .foregroundColor(.gray)
            Text("AI Photo Booth")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .padding(.top)
            Text("Press ESC or move mouse to show controls")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.top, 8)
        }
    }
    
    private var originalWithProcessingView: some View {
        ZStack {
            // Original image
            if let originalImage = originalImage {
                Image(nsImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            // Processing overlay
            VStack {
                Spacer()
                
                HStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Creating your AI masterpiece...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if !selectedThemeName.isEmpty {
                            Text("Processing with \(selectedThemeName) style")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let startTime = processingStartTime {
                            Text("Time elapsed: \(Int(Date().timeIntervalSince(startTime)))s")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.leading, 12)
                }
                .padding(20)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var warningView: some View {
        ZStack {
            // Keep original image visible
            if let originalImage = originalImage {
                Image(nsImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.3)
            }
            
            // Warning message
            VStack(spacing: 20) {
                Text("🎭")
                    .font(.system(size: 80))
                
                Text("Get Ready for the Reveal!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                if warningCountdown > 0 {
                    Text("\(warningCountdown)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(1.2)
                }
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    private var themedImageView: some View {
        ZStack {
            if let themedImage = themedImage {
                Image(nsImage: themedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
    
    private var controlsOverlay: some View {
        Group {
            if showControls {
                VStack {
                    HStack {
                        Button(action: {
                            onToggleFullscreen?()
                            isFullscreen.toggle()
                        }) {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(isFullscreen ? "Exit Fullscreen" : "Enter Fullscreen")
                        
                        Spacer()
                        
                        Button(action: {
                            onClose?()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handlePhotoCapture(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let originalPath = userInfo["original"] as? URL,
              let themeName = userInfo["theme"] as? String else { return }
        
        // Load and immediately show original image
        if let originalData = try? Data(contentsOf: originalPath),
           let original = NSImage(data: originalData) {
            originalImage = original
            selectedThemeName = themeName
            withAnimation(.easeInOut(duration: 0.5)) {
                projectorState = .showingOriginal
            }
            processingStartTime = Date()
        }
    }
    
    private func handleProcessingStart(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let themeName = userInfo["theme"] as? String else { return }
        
        selectedThemeName = themeName
        processingStartTime = Date()
        projectorState = .showingOriginal
    }
    
    private func handleProcessingDone(_ notification: Notification) {
        withAnimation(.easeInOut(duration: 0.3)) {
            projectorState = .processingComplete
        }
        startWarningSequence()
    }
    
    private func handleFinalResult(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let themedPath = userInfo["themed"] as? URL else { return }
        
        // Load themed image
        if let themedData = try? Data(contentsOf: themedPath),
           let themed = NSImage(data: themedData) {
            themedImage = themed
        }
        
        // Trigger the reveal sequence
        showThemedImage()
    }
    
    private func startWarningSequence() {
        showWarning = true
        warningCountdown = Int(warningDuration)
        
        // Start countdown timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            warningCountdown -= 1
            
            if warningCountdown <= 0 {
                timer.invalidate()
                showWarning = false
                showThemedImage()
            }
        }
    }
    
    private func showThemedImage() {
        // Instant transition to themed image - no fade animation
        projectorState = .showingThemed
        
        // Immediately enter minimum display period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                projectorState = .minimumDisplay
            }
            
            // Start minimum display timer
            viewModel.isInMinimumDisplayPeriod = true
            viewModel.isReadyForNextPhoto = false
            viewModel.minimumDisplayTimeRemaining = Int(viewModel.minimumDisplayDuration)
            
            // Start countdown timer
            viewModel.minimumDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                DispatchQueue.main.async {
                    viewModel.minimumDisplayTimeRemaining -= 1
                    
                    if viewModel.minimumDisplayTimeRemaining <= 0 {
                        timer.invalidate()
                        viewModel.isInMinimumDisplayPeriod = false
                        viewModel.isReadyForNextPhoto = true
                        
                        // Don't automatically return to live camera - wait for theme selection
                    }
                }
            }
        }
    }
    
    private func resetToLiveCamera() {
        projectorState = .liveCamera
        originalImage = nil
        themedImage = nil
        showWarning = false
        processingStartTime = nil
        selectedThemeName = ""
        errorMessage = ""
    }
    
    private func handleCountdownStart() {
        print("🎬 [PROJECTOR] Handling countdown start - switching to countdown state")
        
        // If we're currently showing a themed image, smoothly transition back to live camera first
        if projectorState == .showingThemed || projectorState == .minimumDisplay {
            print("🎬 [PROJECTOR] Transitioning from themed image to live camera countdown")
            withAnimation(.easeInOut(duration: 0.2)) {
                projectorState = .liveCamera
            }
            
            // Brief pause to show live camera before countdown overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.projectorState = .countdown
                }
                print("🎬 [PROJECTOR] Projector state changed to: \(self.projectorState)")
            }
        } else {
            // Direct transition to countdown if not coming from themed image
            withAnimation(.easeInOut(duration: 0.3)) {
                projectorState = .countdown
            }
            print("🎬 [PROJECTOR] Projector state changed to: \(projectorState)")
        }
    }
    
    private func handleShowError(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let message = userInfo["message"] as? String {
            errorMessage = message
        }
        projectorState = .error
        
        // Return to live camera after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            returnToLiveCamera()
        }
    }
    
    private func returnToLiveCamera() {
        withAnimation(.easeInOut(duration: 0.5)) {
            projectorState = .liveCamera
        }
    }
}

// Window Manager for External Display
class ProjectorWindowManager: ObservableObject {
    @Published var isProjectorWindowVisible = false
    @Published var availableDisplays: [NSScreen] = []
    private var projectorWindow: NSWindow?
    private weak var viewModel: PhotoBoothViewModel?
    private var wasVisibleBeforeSlideshow = false
    private var isSlideshowActive = false
    
    init() {
        setupDisplayMonitoring()
        updateAvailableDisplays()
        setupSlideshowNotifications()
    }
    
    func setViewModel(_ viewModel: PhotoBoothViewModel) {
        self.viewModel = viewModel
        
        // If projector window exists but was created without viewModel, recreate it
        if isProjectorWindowVisible && projectorWindow?.contentView != nil {
            print("🔄 [PROJECTOR] Recreating projector window with proper viewModel")
            closeProjectorWindow()
            showProjectorWindow()
        }
    }
    
    private func setupDisplayMonitoring() {
        // Monitor for display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func setupSlideshowNotifications() {
        print("🎬 Setting up slideshow notifications in ProjectorWindowManager")
        // Listen for slideshow start/stop notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideProjectorForSlideshow),
            name: .hideProjectorForSlideshow,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestoreProjectorAfterSlideshow),
            name: .restoreProjectorAfterSlideshow,
            object: nil
        )
        print("🎬 Slideshow notification observers set up")
    }
    
    @objc private func displayConfigurationChanged() {
        print("🔍 Display configuration changed")
        updateAvailableDisplays()
        
        // If projector window is visible but no longer has a valid screen, hide it
        if isProjectorWindowVisible && NSScreen.screens.count <= 1 {
            print("⚠️ External display disconnected, hiding projector window")
            hideProjectorWindow()
        }
        // Only auto-show projector if slideshow is NOT active
        else if !isProjectorWindowVisible && NSScreen.screens.count > 1 && !isSlideshowActive {
            print("✅ External display connected and slideshow not active, showing projector window")
            showProjectorWindow()
        } else if !isProjectorWindowVisible && NSScreen.screens.count > 1 && isSlideshowActive {
            print("🎬 Display change detected but slideshow is active - NOT showing projector")
        }
    }
    
    private func updateAvailableDisplays() {
        availableDisplays = NSScreen.screens
        print("🔍 Available displays: \(availableDisplays.count)")
        for (index, screen) in availableDisplays.enumerated() {
            print("   Display \(index): \(screen.localizedName) - \(screen.frame)")
        }
    }
    
    @objc private func handleHideProjectorForSlideshow() {
        print("🎬 handleHideProjectorForSlideshow() called!")
        print("🎬 Current projector window state - isVisible: \(isProjectorWindowVisible)")
        wasVisibleBeforeSlideshow = isProjectorWindowVisible
        isSlideshowActive = true
        if isProjectorWindowVisible {
            print("🎬 Actually hiding projector window now...")
            hideProjectorWindow()
            print("🎬 Projector window hidden - new state: \(isProjectorWindowVisible)")
        } else {
            print("🎬 Projector window was already hidden")
        }
    }
    
    @objc private func handleRestoreProjectorAfterSlideshow() {
        print("🎬 Restoring projector window after slideshow")
        isSlideshowActive = false
        if wasVisibleBeforeSlideshow {
            showProjectorWindow()
        }
        wasVisibleBeforeSlideshow = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func showProjectorWindow() {
        // Check if slideshow is active and prevent showing projector
        if isSlideshowActive {
            print("🚫 [PROJECTOR] Blocked projector window show - slideshow is active")
            return
        }
        
        // Find external display - always use second screen if available
        let screens = NSScreen.screens
        
        print("🔍 DEBUG: Total screens detected: \(screens.count)")
        for (index, screen) in screens.enumerated() {
            print("🔍 DEBUG: Screen \(index): \(screen.localizedName) - Frame: \(screen.frame)")
        }
        
        // Check for single display mode setting
        let singleDisplayMode = UserDefaults.standard.bool(forKey: "singleDisplayMode")
        
        // Determine which screen to use
        let screen: NSScreen
        if singleDisplayMode || screens.count <= 1 {
            // Use main screen for single display mode or when only one screen is available
            screen = screens[0]
            print("📺 Using main screen for projector (single display mode)")
        } else {
            // Use second screen for dual display mode
            screen = screens[1]
            print("📺 Using second screen for projector (dual display mode)")
        }
        
        if screens.count > 1 {
            print("📺 Main screen (laptop): \(screens[0].localizedName)")
            print("📺 Projector screen: \(screen.localizedName)")
        } else {
            print("📺 Single display mode: \(screen.localizedName)")
        }
        print("📺 Creating projector window on screen: \(screen.frame)")
        
        // Create window if needed
        if projectorWindow == nil {
            // Create a centered window on the external screen
            let windowSize = CGSize(width: min(screen.frame.width * 0.9, 1200), 
                                  height: min(screen.frame.height * 0.9, 800))
            let windowOrigin = CGPoint(
                x: screen.frame.origin.x + (screen.frame.width - windowSize.width) / 2,
                y: screen.frame.origin.y + (screen.frame.height - windowSize.height) / 2
            )
            let windowFrame = CGRect(origin: windowOrigin, size: windowSize)
            
            let window = NSWindow(
                contentRect: windowFrame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            window.title = "AI Photo Booth - Projector"
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            window.isMovableByWindowBackground = true
            window.collectionBehavior = [.moveToActiveSpace]
            
            // Add escape key handler
            window.acceptsMouseMovedEvents = true
            
            // Set content view
            let projectorView = ProjectorView(
                onClose: {
                    // Close callback
                    DispatchQueue.main.async {
                        self.hideProjectorWindow()
                    }
                },
                onToggleFullscreen: {
                    // Fullscreen toggle callback
                    DispatchQueue.main.async {
                        self.toggleFullscreen()
                    }
                }
            )
            
            // Ensure viewModel is available - if not, wait for it
            guard let viewModel = viewModel else {
                print("⚠️ [PROJECTOR] ViewModel not available yet, deferring window creation")
                return
            }
            
            window.contentView = NSHostingView(rootView: projectorView.environmentObject(viewModel))
            
            projectorWindow = window
            print("✅ Projector window created successfully")
        }
        
        print("📺 Showing projector window...")
        projectorWindow?.makeKeyAndOrderFront(nil)
        projectorWindow?.orderFrontRegardless()
        isProjectorWindowVisible = true
        print("✅ Projector window should now be visible on external display")
    }
    
    func hideProjectorWindow() {
        guard let window = projectorWindow else { return }
        
        // If window is in fullscreen, exit fullscreen first
        if window.styleMask.contains(.fullScreen) {
            print("📺 [PROJECTOR] Exiting fullscreen before hiding...")
            window.toggleFullScreen(nil)
            
            // Wait for fullscreen exit, then hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                window.orderOut(nil)
                self.isProjectorWindowVisible = false
                print("📺 [PROJECTOR] Window hidden after fullscreen exit")
            }
        } else {
            window.orderOut(nil)
            isProjectorWindowVisible = false
            print("📺 [PROJECTOR] Window hidden immediately")
        }
    }
    
    func closeProjectorWindow() {
        projectorWindow?.close()
        projectorWindow = nil
        isProjectorWindowVisible = false
    }
    
    func toggleFullscreen() {
        guard let window = projectorWindow else { return }
        window.toggleFullScreen(nil)
    }
}

// Custom view for handling key events
struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let keyView = nsView as? KeyEventView {
            keyView.onKeyDown = onKeyDown
        }
    }
}

class KeyEventView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
} 