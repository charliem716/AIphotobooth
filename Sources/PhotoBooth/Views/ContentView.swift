import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoBoothViewModel
    @EnvironmentObject var projectorManager: ProjectorWindowManager
    @AppStorage("autoShowProjector") private var autoShowProjector = true
    
    var body: some View {
        ControlCenterView()
            .environmentObject(viewModel)
            .environmentObject(projectorManager)
            .onAppear {
                // Set the viewModel on the projector manager
                projectorManager.setViewModel(viewModel)
                
                // Debug: Verify shared ViewModel instance
                        logDebug("\(LoggingService.Emoji.info) Control Center ViewModel ID: \(ObjectIdentifier(viewModel))", category: .app)
        logDebug("\(LoggingService.Emoji.projector) Setting projector manager ViewModel to same instance", category: .projector)
                
                // Auto-show projector on startup if setting is enabled and there are multiple displays
                // Only if slideshow is not active
                if autoShowProjector && NSScreen.screens.count > 1 && !projectorManager.isProjectorWindowVisible && !viewModel.isSlideShowActive {
                    // Modern async delay to ensure viewModel is properly set
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        projectorManager.showProjectorWindow()
                    }
                }
                
                // Configure main window
                Task { @MainActor in
                    if let window = NSApplication.shared.mainWindow {
                        window.title = "AI Photo Booth - Control Center"
                        window.titlebarAppearsTransparent = false
                        window.isMovableByWindowBackground = false
                        
                        // Ensure window can be resized properly
                        window.isRestorable = true
                        window.collectionBehavior = [.fullScreenPrimary, .moveToActiveSpace]
                        window.level = .normal
                        
                        // Explicitly enable resizing
                        window.styleMask.insert(.resizable)
                        window.minSize = NSSize(width: 800, height: 700)
                        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                    }
                }
            }
            .frame(minWidth: 800, minHeight: 700)
    }
}

#Preview {
    ContentView()
                    .environmentObject(PhotoBoothViewModel())
        .environmentObject(ProjectorWindowManager())
} 


 