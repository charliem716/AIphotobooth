import SwiftUI
import AVFoundation

struct ProjectorCameraView: View {
    let session: AVCaptureSession?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.9),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Camera preview with margin
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Camera preview container
                    ZStack {
                        // Camera preview
                        if let session = session {
                            CameraPreviewView(session: session)
                                .aspectRatio(4/3, contentMode: .fit)
                                .cornerRadius(12)
                                .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
                        } else {
                            // Placeholder when no camera
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(4/3, contentMode: .fit)
                                .overlay(
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("Camera Not Connected")
                                            .font(.title2)
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.top, 8)
                                    }
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(60) // Margin around camera preview
                    
                    Spacer()
                }
                
                Spacer()
                
                // Subtle branding at bottom
                Text("AI Photo Booth")
                    .font(.title3)
                    .fontWeight(.light)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ProjectorCameraView(session: nil)
        .frame(width: 800, height: 600)
} 