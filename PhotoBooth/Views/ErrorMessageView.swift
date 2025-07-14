import SwiftUI

struct ErrorMessageView: View {
    let errorMessage: String
    @State private var showRetryButton = false
    
    // Collection of funny error messages
    static let funnyErrorMessages = [
        "Oops! The AI got camera shy! Let's try that again! 📸",
        "The pixels went on a coffee break! Ready for round two? ☕",
        "Houston, we have a photo problem! Let's give it another shot! 🚀",
        "The AI sneezed during processing! Bless you, AI! Let's retry! 🤧",
        "Photo booth gremlins detected! Shaking them off... Try again! 👾",
        "The camera blinked at the wrong moment! One more time! 👁️",
        "Our AI artist dropped their digital paintbrush! Back to work! 🎨",
        "The internet hamsters need a snack break! Let's wait a moment! 🐹",
        "Whoops! The style transfer got lost in translation! Retry time! 🗺️",
        "The AI is having an existential crisis! Let's help it out! 🤖"
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.red.opacity(0.8),
                    Color.orange.opacity(0.6),
                    Color.red.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Error icon with animation
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 0)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showRetryButton)
                
                // Error message
                Text(displayMessage)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 0)
                    .padding(.horizontal, 60)
                
                // Retry instructions
                if showRetryButton {
                    VStack(spacing: 15) {
                        Text("Returning to camera in a moment...")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                        
                        // Loading indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
            }
        }
        .onAppear {
            // Show retry button after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showRetryButton = true
                }
            }
        }
    }
    
    private var displayMessage: String {
        // Use provided error message or random funny message
        if errorMessage.isEmpty {
            return Self.funnyErrorMessages.randomElement() ?? Self.funnyErrorMessages[0]
        } else {
            // Try to make the error message more friendly
            return makeFriendlyErrorMessage(errorMessage)
        }
    }
    
    private func makeFriendlyErrorMessage(_ message: String) -> String {
        // Convert technical error messages to friendly ones
        let lowercased = message.lowercased()
        
        if lowercased.contains("network") || lowercased.contains("internet") {
            return "The internet hamsters need a snack break! Let's wait a moment! 🐹"
        } else if lowercased.contains("camera") {
            return "The camera blinked at the wrong moment! One more time! 👁️"
        } else if lowercased.contains("api") || lowercased.contains("openai") {
            return "Our AI artist dropped their digital paintbrush! Back to work! 🎨"
        } else if lowercased.contains("timeout") {
            return "The AI is taking a thinking break! Let's try again! 🤔"
        } else {
            return Self.funnyErrorMessages.randomElement() ?? Self.funnyErrorMessages[0]
        }
    }
}

#Preview {
    ErrorMessageView(errorMessage: "Network connection failed")
        .frame(width: 800, height: 600)
} 