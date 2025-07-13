import SwiftUI

struct ControlCenterView: View {
    @EnvironmentObject var viewModel: PhotoBoothViewModel
    @EnvironmentObject var projectorManager: ProjectorWindowManager
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content area
            HStack(spacing: 20) {
                // Left side - Theme selection and controls
                VStack(spacing: 20) {
                    themeSelectionGrid
                    takePhotoButton
                    projectorControls
                }
                .frame(maxWidth: .infinity)
                
                // Right side - Status and preview
                VStack(spacing: 20) {
                    statusDisplay
                    lastPhotoPreview
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))

        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(projectorManager)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("AI Photo Booth - Control Center")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Camera selection dropdown
                Menu {
                    ForEach(viewModel.availableCameras, id: \.uniqueID) { camera in
                        Button(action: {
                            viewModel.selectCamera(camera)
                        }) {
                            HStack {
                                Text(camera.localizedName)
                                if camera.deviceType == .continuityCamera {
                                    Image(systemName: "iphone")
                                } else if camera.deviceType == .external {
                                    Image(systemName: "camera.macro")
                                } else {
                                    Image(systemName: "camera")
                                }
                                
                                if viewModel.selectedCameraDevice?.uniqueID == camera.uniqueID {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        print("🔄 Manual camera refresh requested")
                        viewModel.findAndSetupContinuityCamera()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Cameras")
                        }
                    }
                    
                    Button(action: {
                        print("📱 Force Continuity Camera connection requested")
                        viewModel.forceContinuityCameraConnection()
                    }) {
                        HStack {
                            Image(systemName: "iphone")
                            Text("Force Continuity Camera")
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "camera")
                        Text(viewModel.selectedCameraDevice?.localizedName ?? "Select Camera")
                            .lineLimit(1)
                    }
                    .font(.title2)
                }
                .help("Select Camera")
                .buttonStyle(.bordered)
                
                // Settings button
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.title2)
                }
                .help("Settings")
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(NSColor.controlBackgroundColor))
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Theme Selection Grid
    private var themeSelectionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme Selection")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(viewModel.themes.prefix(8), id: \.id) { theme in
                    ThemeButton(
                        theme: theme,
                        isSelected: viewModel.selectedTheme?.id == theme.id,
                        isEnabled: viewModel.isReadyForNextPhoto && !viewModel.isProcessing,
                        action: {
                            selectTheme(theme)
                        }
                    )
                }
                
                // Empty slot for 3x3 grid
                Rectangle()
                    .fill(Color.clear)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Take Photo Button
    private var takePhotoButton: some View {
        Button(action: {
            viewModel.startCapture()
        }) {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.title2)
                Text("TAKE PHOTO")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .disabled(!canTakePhoto)
        .opacity(canTakePhoto ? 1.0 : 0.6)
        .scaleEffect(canTakePhoto ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.2), value: canTakePhoto)
        .buttonStyle(.plain)
    }
    
    // MARK: - Projector Controls
    private var projectorControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projector Controls")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                // Show/Hide Projector
                Button(action: {
                    if projectorManager.isProjectorWindowVisible {
                        projectorManager.hideProjectorWindow()
                    } else {
                        projectorManager.showProjectorWindow()
                    }
                }) {
                    HStack {
                        Image(systemName: projectorManager.isProjectorWindowVisible ? "tv.fill" : "tv")
                        Text(projectorManager.isProjectorWindowVisible ? "Hide" : "Show")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                // Always allow projector controls (supports single display mode)
                
                // Reset Projector
                Button(action: {
                    NotificationCenter.default.post(
                        name: .resetProjector,
                        object: nil
                    )
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!projectorManager.isProjectorWindowVisible)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Status Display
    private var statusDisplay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(label: "Camera", value: viewModel.isCameraConnected ? "Connected" : "Disconnected", 
                         color: viewModel.isCameraConnected ? .green : .red)
                
                StatusRow(label: "Projector", value: projectorManager.isProjectorWindowVisible ? "Active" : "Hidden",
                         color: projectorManager.isProjectorWindowVisible ? .green : .gray)
                
                StatusRow(label: "Ready", value: viewModel.isReadyForNextPhoto ? "Yes" : "Processing...",
                         color: viewModel.isReadyForNextPhoto ? .green : .orange)
                
                if viewModel.isInMinimumDisplayPeriod {
                    StatusRow(label: "Display Timer", value: "\(viewModel.minimumDisplayTimeRemaining)s",
                             color: .blue)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Last Photo Preview
    private var lastPhotoPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Photo")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                // Original photo
                VStack(spacing: 4) {
                    if let originalImage = viewModel.lastCapturedImage {
                        Image(nsImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    }
                    Text("Original")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Themed photo
                VStack(spacing: 4) {
                    if let themedImage = viewModel.lastThemedImage {
                        Image(nsImage: themedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    }
                    Text("Themed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    private var canTakePhoto: Bool {
        viewModel.isCameraConnected && 
        viewModel.selectedTheme != nil && 
        viewModel.isReadyForNextPhoto && 
        !viewModel.isCountingDown && 
        !viewModel.isProcessing
    }
    
    // MARK: - Actions
    private func selectTheme(_ theme: PhotoTheme) {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.selectedTheme = theme
        }
        
        // If in minimum display period, selecting theme returns to live feed
        if viewModel.isInMinimumDisplayPeriod {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.isInMinimumDisplayPeriod = false
                viewModel.isReadyForNextPhoto = true
            }
            viewModel.minimumDisplayTimer?.invalidate()
            
            // Notify projector to return to live feed
            NotificationCenter.default.post(
                name: .resetProjector,
                object: nil
            )
        }
    }
}

// MARK: - Theme Button
struct ThemeButton: View {
    let theme: PhotoTheme
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(theme.name)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(NSColor.controlColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Status Row
struct StatusRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

#Preview {
    ControlCenterView()
        .environmentObject(PhotoBoothViewModel())
        .environmentObject(ProjectorWindowManager())
        .frame(width: 800, height: 600)
} 