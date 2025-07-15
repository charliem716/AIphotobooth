import SwiftUI

struct ControlCenterView: View {
    @EnvironmentObject var viewModel: PhotoBoothViewModel
    @EnvironmentObject var projectorManager: ProjectorWindowManager
    @State private var showingSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main content area with ScrollView
                ScrollView {
                    if geometry.size.width > 900 {
                        // Wide layout - side by side
                        HStack(alignment: .top, spacing: 20) {
                            // Left side - Theme selection and controls
                            VStack(spacing: 20) {
                                themeSelectionGrid
                                takePhotoButton
                                projectorControls
                                slideShowControls
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Right side - Status and preview
                            VStack(spacing: 20) {
                                statusDisplay
                                lastPhotoPreview
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(20)
                    } else {
                        // Narrow layout - stacked vertically
                        VStack(spacing: 20) {
                            themeSelectionGrid
                            takePhotoButton
                            
                            HStack(alignment: .top, spacing: 20) {
                                statusDisplay
                                lastPhotoPreview
                            }
                            
                            projectorControls
                            slideShowControls
                        }
                        .padding(20)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingSettings) {
            SettingsView(configurationService: viewModel.configurationService as! ConfigurationService)
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
                    ForEach(viewModel.cameraViewModel.availableCameras, id: \.uniqueID) { camera in
                        Button(action: {
                            Task {
                                await viewModel.cameraViewModel.selectCamera(camera)
                            }
                        }) {
                            HStack {
                                Text(camera.localizedName)
                                if camera.deviceType == .continuityCamera {
                                    Image(systemName: "iphone")
                                        .foregroundColor(.blue)
                                }
                                if camera == viewModel.cameraViewModel.selectedCameraDevice {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "video")
                            .foregroundColor(.blue)
                        Text(viewModel.cameraViewModel.selectedCameraDevice?.localizedName ?? "No camera selected")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Refresh camera button
                Button("↻ Refresh Cameras") {
                    Task {
                        await viewModel.cameraViewModel.refreshAvailableCameras()
                    }
                }
                .buttonStyle(.bordered)
                
                // Force continuity camera connection (consolidated)
                Button("📱 Force iPhone Connection") {
                    Task {
                        await viewModel.cameraViewModel.forceContinuityCameraConnection()
                    }
                }
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
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme Selection")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Adaptive columns based on available width
                let columnCount = max(2, min(4, Int(geometry.size.width / 120)))
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.imageProcessingViewModel.themes, id: \.id) { theme in
                        ThemeButton(
                            theme: theme,
                            isSelected: viewModel.imageProcessingViewModel.selectedTheme?.id == theme.id,
                            isEnabled: viewModel.uiStateViewModel.isReadyForNextPhoto && !viewModel.imageProcessingViewModel.isProcessing,
                            action: {
                                selectTheme(theme)
                            }
                        )
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .frame(height: 200) // Fixed height for the grid area
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
    
    // MARK: - Slideshow Controls
    private var slideShowControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Slideshow")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Photo count and status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Photo Pairs:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.slideShowPhotoPairCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isSlideShowActive ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isSlideShowActive ? "Running" : "Stopped")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Speed control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speed: \(String(format: "%.0f", viewModel.slideShowDisplayDuration))s per image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Slider(
                    value: Binding(
                        get: { viewModel.slideShowDisplayDuration },
                        set: { viewModel.updateSlideShowDuration($0) }
                    ),
                    in: 2...10,
                    step: 1
                ) {
                    Text("Display Duration")
                }
                .disabled(viewModel.slideShowPhotoPairCount == 0)
            }
            
            // Control buttons
            HStack(spacing: 12) {
                if viewModel.isSlideShowActive {
                    // Stop button
                    Button(action: {
                        viewModel.stopSlideshow()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    // Start button
                    Button(action: {
                        Task {
                            await viewModel.startSlideshow()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .disabled(viewModel.slideShowPhotoPairCount == 0)
                }
            }
            
            if viewModel.slideShowPhotoPairCount == 0 {
                Text("Take some photos to enable slideshow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
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
                StatusRow(label: "Camera", value: viewModel.cameraViewModel.isCameraConnected ? "Connected" : "Disconnected",
                         color: viewModel.cameraViewModel.isCameraConnected ? .green : .red)
                
                StatusRow(label: "Projector", value: projectorManager.isProjectorWindowVisible ? "Active" : "Hidden",
                         color: projectorManager.isProjectorWindowVisible ? .green : .gray)
                
                StatusRow(label: "OpenAI", value: viewModel.isOpenAIConfigured ? "Configured" : "Not Configured",
                         color: viewModel.isOpenAIConfigured ? .green : .red)
                
                StatusRow(label: "Themes", value: viewModel.isThemeConfigurationLoaded ? "\(viewModel.imageProcessingViewModel.themes.count) Available" : "Loading...",
                         color: viewModel.isThemeConfigurationLoaded ? .green : .orange)
                
                StatusRow(label: "Ready", value: canTakePhoto ? "Yes" : "Not Ready",
                         color: canTakePhoto ? .green : .orange)
                
                // Add processing status row
                if viewModel.imageProcessingViewModel.isProcessing {
                    let processingStatus = viewModel.imageProcessingViewModel.getProcessingStatusSummary()
                    StatusRow(label: "Processing", value: processingStatus.statusText,
                             color: .blue)
                    
                    // Show current processing step with icon
                    HStack {
                        Image(systemName: processingStatus.statusIcon)
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(processingStatus.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if viewModel.uiStateViewModel.isInMinimumDisplayPeriod {
                    StatusRow(label: "Display Timer", value: "\(viewModel.uiStateViewModel.minimumDisplayTimeRemaining)s",
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Photo")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Original photo
                VStack(spacing: 8) {
                    if let originalImage = viewModel.imageProcessingViewModel.lastCapturedImage {
                        Image(nsImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 140)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 140)
                            .cornerRadius(12)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text("No photo yet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    Text("Original")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                // Themed photo
                VStack(spacing: 8) {
                    if let themedImage = viewModel.imageProcessingViewModel.lastThemedImage {
                        Image(nsImage: themedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 140)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 140)
                            .cornerRadius(12)
                            .overlay(
                                VStack {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text("Processing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    Text("Themed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    private var canTakePhoto: Bool {
        viewModel.cameraViewModel.isCameraConnected && 
        viewModel.imageProcessingViewModel.selectedTheme != nil && 
        viewModel.uiStateViewModel.isReadyForNextPhoto && 
        !viewModel.uiStateViewModel.isCountingDown && 
        !viewModel.imageProcessingViewModel.isProcessing &&
        viewModel.isThemeConfigurationLoaded &&
        viewModel.isOpenAIConfigured
    }
    
    // MARK: - Actions
    private func selectTheme(_ theme: PhotoTheme) {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.imageProcessingViewModel.selectTheme(theme)
        }
        
        // Let the PhotoBoothViewModel handle the minimum display period logic
        // and return to live camera view appropriately
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
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 40)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
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