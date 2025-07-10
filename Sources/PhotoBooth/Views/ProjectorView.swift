import SwiftUI
import Combine

struct ProjectorView: View {
    @State private var originalImage: NSImage?
    @State private var themedImage: NSImage?
    @State private var showThemed = false
    @AppStorage("fadeRevealDuration") private var fadeRevealDuration = 1.0
    
    private let photoPublisher = NotificationCenter.default
        .publisher(for: .newPhotoCapture)
    
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
                }
            }
        }
        .onReceive(photoPublisher) { notification in
            handleNewPhoto(notification)
        }
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
    private var projectorWindow: NSWindow?
    
    func showProjectorWindow() {
        // Find external display
        let screens = NSScreen.screens
        let projectorScreenIndex = UserDefaults.standard.integer(forKey: "projectorScreenIndex")
        
        guard projectorScreenIndex < screens.count else { return }
        let screen = screens[projectorScreenIndex]
        
        // Create window if needed
        if projectorWindow == nil {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            window.level = .screenSaver
            window.isReleasedWhenClosed = false
            window.backgroundColor = .black
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.fullScreenPrimary, .stationary]
            
            // Set content view
            let projectorView = ProjectorView()
            window.contentView = NSHostingView(rootView: projectorView)
            
            projectorWindow = window
        }
        
        projectorWindow?.makeKeyAndOrderFront(nil)
        projectorWindow?.orderFrontRegardless()
    }
    
    func hideProjectorWindow() {
        projectorWindow?.orderOut(nil)
    }
    
    func closeProjectorWindow() {
        projectorWindow?.close()
        projectorWindow = nil
    }
} 