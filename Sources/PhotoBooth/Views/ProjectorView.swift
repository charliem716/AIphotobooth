import SwiftUI
import Combine

extension Notification.Name {
    static let photoCapture = Notification.Name("photoCapture")
    static let processingStart = Notification.Name("processingStart")
    static let processingDone = Notification.Name("processingDone")
    static let resetProjector = Notification.Name("resetProjector")
}

enum ProjectorState {
    case idle                    // "AI Photo Booth" screen
    case showingOriginal        // Original photo + processing overlay
    case processingComplete     // "Get ready for the reveal!" warning
    case showingThemed         // Final themed image display
}

struct ProjectorView: View {
    @State private var originalImage: NSImage?
    @State private var themedImage: NSImage?
    @State private var showThemed = false
    @State private var showControls = false
    @State private var isFullscreen = false
    @State private var projectorState: ProjectorState = .idle
    @State private var processingStartTime: Date?
    @State private var showWarning = false
    @State private var warningCountdown = 3
    @State private var selectedThemeName: String = ""
    @AppStorage("fadeRevealDuration") private var fadeRevealDuration = 1.0
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
                
            case .showingOriginal:
                originalWithProcessingView
                
            case .processingComplete:
                if showWarning {
                    warningView
                } else {
                    originalWithProcessingView
                }
                
            case .showingThemed:
                themedImageView
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
            resetToIdle()
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
                    .opacity(showThemed ? 1 : 0)
                    .animation(.easeInOut(duration: fadeRevealDuration), value: showThemed)
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
            projectorState = .showingOriginal
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
        projectorState = .processingComplete
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
        projectorState = .showingThemed
        showThemed = false
        
        // Trigger fade animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: fadeRevealDuration)) {
                showThemed = true
            }
        }
        
        // Keep themed image visible until next photo cycle
        // (No auto-reset - stays until next photo is taken)
    }
    
    private func resetToIdle() {
        projectorState = .idle
        originalImage = nil
        themedImage = nil
        showThemed = false
        showWarning = false
        processingStartTime = nil
        selectedThemeName = ""
    }
}

// Window Manager for External Display
class ProjectorWindowManager: ObservableObject {
    @Published var isProjectorWindowVisible = false
    private var projectorWindow: NSWindow?
    
    func showProjectorWindow() {
        // Find external display - always use second screen if available
        let screens = NSScreen.screens
        
        print("🔍 DEBUG: Total screens detected: \(screens.count)")
        for (index, screen) in screens.enumerated() {
            print("🔍 DEBUG: Screen \(index): \(screen.localizedName) - Frame: \(screen.frame)")
        }
        
        // Ensure we have at least 2 screens
        guard screens.count > 1 else {
            print("⚠️ Only one screen detected. Projector window requires a second display.")
            print("⚠️ Please connect an external display and set it to extended mode (not mirrored)")
            return
        }
        
        // Always use the second screen (index 1) to keep main interface on laptop
        let screen = screens[1]
        
        print("📺 Main screen (laptop): \(screens[0].localizedName)")
        print("📺 Projector screen: \(screen.localizedName)")
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
            window.contentView = NSHostingView(rootView: projectorView)
            
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
        projectorWindow?.orderOut(nil)
        isProjectorWindowVisible = false
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