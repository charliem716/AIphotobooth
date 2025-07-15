import SwiftUI
import AVFoundation

struct ProjectorCountdownView: View {
    @EnvironmentObject private var viewModel: PhotoBoothViewModel
    
    var body: some View {
        ZStack {
            if viewModel.uiStateViewModel.isCountingDown {
                // Transparent background to show live camera preview
                Color.clear
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("GET READY!")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 3, x: 2, y: 2)
                        .overlay(
                            Text("GET READY!")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.clear)
                                .background(
                                    Text("GET READY!")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .blur(radius: 1)
                                )
                        )
                    
                    Text(viewModel.uiStateViewModel.countdown > 0 ? "\(viewModel.uiStateViewModel.countdown)" : "📸")
                        .font(.system(size: 240, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 6, x: 4, y: 4)
                        .overlay(
                            Text(viewModel.uiStateViewModel.countdown > 0 ? "\(viewModel.uiStateViewModel.countdown)" : "📸")
                                .font(.system(size: 240, weight: .heavy, design: .rounded))
                                .foregroundColor(.clear)
                                .background(
                                    Text(viewModel.uiStateViewModel.countdown > 0 ? "\(viewModel.uiStateViewModel.countdown)" : "📸")
                                        .font(.system(size: 240, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .blur(radius: 2)
                                )
                        )
                        .id("countdown-\(viewModel.uiStateViewModel.countdown)") // Force view refresh
                }
            }
        }
        .opacity(viewModel.uiStateViewModel.isCountingDown ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiStateViewModel.isCountingDown)
        .zIndex(1000)
        .onAppear {
            logInfo("\(LoggingService.Emoji.projector) ProjectorCountdownView appeared", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Projector ViewModel ID: \(ObjectIdentifier(viewModel))", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Initial state - isCountingDown: \(viewModel.uiStateViewModel.isCountingDown), countdown: \(viewModel.uiStateViewModel.countdown)", category: .projector)
        }
        .onChange(of: viewModel.uiStateViewModel.isCountingDown) { _, newValue in
            logDebug("\(LoggingService.Emoji.projector) Countdown state changed - isCountingDown: \(newValue)", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Projector ViewModel ID: \(ObjectIdentifier(viewModel))", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Full state - countdown: \(viewModel.uiStateViewModel.countdown), isCountingDown: \(newValue)", category: .projector)
        }
        .onChange(of: viewModel.uiStateViewModel.countdown) { _, newValue in
            logDebug("\(LoggingService.Emoji.projector) Countdown value changed - countdown: \(newValue)", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Projector ViewModel ID: \(ObjectIdentifier(viewModel))", category: .projector)
            logDebug("\(LoggingService.Emoji.projector) Full state - isCountingDown: \(viewModel.uiStateViewModel.isCountingDown), countdown: \(newValue)", category: .projector)
        }
    }
}

#Preview {
    ProjectorCountdownView()
                    .environmentObject(PhotoBoothViewModel())
        .frame(width: 800, height: 600)
} 