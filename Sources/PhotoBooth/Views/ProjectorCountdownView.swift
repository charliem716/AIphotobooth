import SwiftUI
import AVFoundation

struct ProjectorCountdownView: View {
    let session: AVCaptureSession?
    @EnvironmentObject var viewModel: PhotoBoothViewModel
    
    var body: some View {
        ZStack {
            // Base camera view (always visible)
            ProjectorCameraView(session: session)
            
            // Countdown overlay (always rendered, controlled by opacity)
            ZStack {
                // Full screen semi-transparent overlay
                Color.black.opacity(0.6)
                    .ignoresSafeArea(.all)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.red, lineWidth: 4)
                    )
                
                VStack(spacing: 30) {
                    Text("Get Ready!")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(viewModel.countdown > 0 ? "\(viewModel.countdown)" : "📸")
                        .font(.system(size: 240, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .id("countdown-\(viewModel.countdown)") // Force view refresh
                }
            }
            .opacity(viewModel.isCountingDown ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isCountingDown)
            .zIndex(1000)
        }
        .onAppear {
            print("🎬 [PROJECTOR] ProjectorCountdownView appeared")
            print("📺 [DEBUG] Projector ViewModel ID: \(ObjectIdentifier(viewModel))")
            print("🔍 [DEBUG] Initial state - isCountingDown: \(viewModel.isCountingDown), countdown: \(viewModel.countdown)")
        }
        .onChange(of: viewModel.isCountingDown) { newValue in
            print("🎬 [PROJECTOR] Countdown state changed - isCountingDown: \(newValue)")
            print("📺 [DEBUG] Projector ViewModel ID: \(ObjectIdentifier(viewModel))")
            print("🔍 [DEBUG] Full state - countdown: \(viewModel.countdown), isCountingDown: \(newValue)")
        }
        .onChange(of: viewModel.countdown) { newValue in
            print("🎬 [PROJECTOR] Countdown value changed - countdown: \(newValue)")
            print("📺 [DEBUG] Projector ViewModel ID: \(ObjectIdentifier(viewModel))")
            print("🔍 [DEBUG] Full state - isCountingDown: \(viewModel.isCountingDown), countdown: \(newValue)")
        }
    }
    

}

#Preview {
    ProjectorCountdownView(session: nil)
        .environmentObject(PhotoBoothViewModel())
        .frame(width: 800, height: 600)
} 