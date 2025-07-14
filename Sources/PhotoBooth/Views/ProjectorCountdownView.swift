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
            logInfo("\(LoggingService.Emoji.projector) ProjectorCountdownView appeared", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Projector ViewModel ID: \(ObjectIdentifier(viewModel))", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Initial state - isCountingDown: \(viewModel.isCountingDown), countdown: \(viewModel.countdown)", category: .projector)
        }
        .onChange(of: viewModel.isCountingDown) { _, newValue in
            logDebug("\(LoggingService.Emoji.projector) Countdown state changed - isCountingDown: \(newValue)", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Projector ViewModel ID: \(ObjectIdentifier(viewModel))", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Full state - countdown: \(viewModel.countdown), isCountingDown: \(newValue)", category: .projector)
        }
        .onChange(of: viewModel.countdown) { _, newValue in
            logDebug("\(LoggingService.Emoji.projector) Countdown value changed - countdown: \(newValue)", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Projector ViewModel ID: \(ObjectIdentifier(viewModel))", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Full state - isCountingDown: \(viewModel.isCountingDown), countdown: \(newValue)", category: .projector)
        }
    }
    

}

#Preview {
    ProjectorCountdownView(session: nil)
                    .environmentObject(PhotoBoothViewModel())
        .frame(width: 800, height: 600)
} 