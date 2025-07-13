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
                
                // Auto-show projector on startup if setting is enabled and there are multiple displays
                if autoShowProjector && NSScreen.screens.count > 1 && !projectorManager.isProjectorWindowVisible {
                    // Delay slightly to ensure viewModel is properly set
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        projectorManager.showProjectorWindow()
                    }
                }
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoBoothViewModel())
        .environmentObject(ProjectorWindowManager())
} 


 