import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoBoothViewModel
    @State private var showingSettings = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Side - Camera Preview
            ZStack {
                CameraPreviewView(session: viewModel.captureSession)
                    .background(Color.black)
                    .overlay(
                        Group {
                            if !viewModel.isCameraConnected {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    Text("Connect your iPhone")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Text("Enable Continuity Camera in Settings")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    )
                
                // Countdown Overlay
                if viewModel.isCountingDown && viewModel.countdown > 0 {
                    Text("\(viewModel.countdown)")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }
                
                // Processing Overlay
                if viewModel.isProcessing {
                    VStack {
                        ProgressView()
                            .scaleEffect(2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Creating your AI masterpiece...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.7))
                }
            }
            .frame(width: 500)
            
            // Right Side - Controls
            VStack(spacing: 20) {
                // Theme Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Your Theme")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(viewModel.themes) { theme in
                            ThemeButton(
                                theme: theme,
                                isSelected: viewModel.selectedTheme?.id == theme.id
                            ) {
                                viewModel.selectedTheme = theme
                            }
                        }
                    }
                }
                
                // Capture Button
                Button(action: {
                    viewModel.startCapture()
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        viewModel.selectedTheme != nil
                            ? Color.accentColor
                            : Color.gray
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.selectedTheme == nil || viewModel.isCountingDown || viewModel.isProcessing)
                
                // Last captured images preview
                if viewModel.lastCapturedImage != nil || viewModel.lastThemedImage != nil {
                    HStack(spacing: 10) {
                        if let original = viewModel.lastCapturedImage {
                            VStack {
                                Text("Original")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(nsImage: original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 90)
                                    .cornerRadius(8)
                            }
                        }
                        
                        if let themed = viewModel.lastThemedImage {
                            VStack {
                                Text("AI Themed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(nsImage: themed)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 90)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top)
                }
                
                Spacer()
            }
            .frame(width: 400)
            .padding()
        }
        .frame(width: 900, height: 600)
        .alert("Info", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    viewModel.findAndSetupContinuityCamera()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reconnect Camera")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}



struct ThemeButton: View {
    let theme: PhotoTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeGradient)
                    .frame(height: 60)
                    .overlay(
                        Image(systemName: themeIcon)
                            .font(.title2)
                            .foregroundColor(.white)
                    )
                
                Text(theme.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var themeGradient: LinearGradient {
        switch theme.id {
        case 1: // Studio Ghibli
            return LinearGradient(colors: [.blue, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2: // Simpsons
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3: // Rick and Morty
            return LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 4: // Dragon Ball Z
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 5: // Scooby Doo
            return LinearGradient(colors: [.brown, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 6: // SpongeBob
            return LinearGradient(colors: [.yellow, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 7: // South Park
            return LinearGradient(colors: [.red, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 8: // Batman TAS
            return LinearGradient(colors: [.black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 9: // Flintstones
            return LinearGradient(colors: [.orange, .brown], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var themeIcon: String {
        switch theme.id {
        case 1: return "leaf.fill"           // Studio Ghibli (nature)
        case 2: return "house.fill"          // Simpsons (Springfield)
        case 3: return "bolt.circle.fill"    // Rick and Morty (sci-fi)
        case 4: return "flame.fill"          // Dragon Ball Z (power)
        case 5: return "magnifyingglass"     // Scooby Doo (mystery)
        case 6: return "drop.fill"           // SpongeBob (underwater)
        case 7: return "snow"                // South Park (Colorado)
        case 8: return "moon.stars.fill"     // Batman TAS (night)
        case 9: return "hammer.fill"         // Flintstones (stone age)
        default: return "photo.fill"
        }
    }
} 


 