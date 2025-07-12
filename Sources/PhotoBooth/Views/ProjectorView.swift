import SwiftUI
import Combine

struct ProjectorView: View {
    @State private var originalImage: NSImage?
    @State private var themedImage: NSImage?
    @State private var showThemed = false
    @State private var showControls = false
    @State private var isFullscreen = false
    @AppStorage("fadeRevealDuration") private var fadeRevealDuration = 1.0
    
    private let photoPublisher = NotificationCenter.default
        .publisher(for: .newPhotoCapture)
    
    var onClose: (() -> Void)?
    var onToggleFullscreen: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let originalImage = originalImage {
                Image(nsImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(showThemed ? 0 : 1)
            }
            
            if let themedImage = themedImage {
                Image(nsImage: themedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(showThemed ? 1 : 0)
            }
            
            if originalImage == nil && themedImage == nil {
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
            
            // Controls overlay
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
        .onReceive(photoPublisher) { notification in
            handleNewPhoto(notification)
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
    
    private func handleNewPhoto(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let originalPath = userInfo["original"] as? URL,
              let themedPath = userInfo["themed"] as? URL else { return }
        
        // Load images
        if let originalData = try? Data(contentsOf: originalPath),
           let original = NSImage(data: originalData) {
            originalImage = original
        }
        
        if let themedData = try? Data(contentsOf: themedPath),
           let themed = NSImage(data: themedData) {
            themedImage = themed
        }
        
        // Reset and start animation
        showThemed = false
        
        // Trigger fade animation after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: fadeRevealDuration)) {
                showThemed = true
            }
        }
        
        // Reset after showing for a while
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeRevealDuration + 5) {
            withAnimation(.easeOut(duration: 0.5)) {
                originalImage = nil
                themedImage = nil
                showThemed = false
            }
        }
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