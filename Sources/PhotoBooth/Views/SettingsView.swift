import SwiftUI

struct SettingsView: View {
    @AppStorage("fadeRevealDuration") private var fadeRevealDuration = 1.0
    @AppStorage("warningDuration") private var warningDuration = 3.0
    @AppStorage("minimumDisplayDuration") private var minimumDisplayDuration = 10.0
    @AppStorage("cacheRetentionDays") private var cacheRetentionDays = 7
    @AppStorage("singleDisplayMode") private var singleDisplayMode = false
    @AppStorage("autoShowProjector") private var autoShowProjector = true
    @AppStorage("imageQuality") private var imageQuality = "high"
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectorManager: ProjectorWindowManager
    @StateObject private var cacheService = CacheManagementService()
    @State private var showingCacheManagement = false
    
    // Configuration service dependency
    private let configurationService: ConfigurationService
    
    // MARK: - Initialization
    init(configurationService: ConfigurationService = ConfigurationService.shared) {
        self.configurationService = configurationService
    }
    
    private var cacheStats: CacheStatistics {
        cacheService.cacheStatistics
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .bold()
                .padding(.bottom)
            
            GroupBox("Display Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Display Configuration:")
                            Spacer()
                            if projectorManager.availableDisplays.count <= 1 {
                                Text("Single Display")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Multi-Display (\(projectorManager.availableDisplays.count) screens)")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text("Main Interface: Always on laptop screen (Screen 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if projectorManager.availableDisplays.count <= 1 {
                            Text("⚠️ Connect a second display to use projector features")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("✓ Projector: Automatically uses Screen 2")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        // Manual projector controls
                        if projectorManager.availableDisplays.count > 1 {
                            HStack {
                                Button(projectorManager.isProjectorWindowVisible ? "Hide Projector" : "Show Projector") {
                                    if projectorManager.isProjectorWindowVisible {
                                        projectorManager.hideProjectorWindow()
                                    } else {
                                        projectorManager.showProjectorWindow()
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                if projectorManager.isProjectorWindowVisible {
                                    Button("Reset Projector") {
                                        // Send reset notification to projector
                                        NotificationCenter.default.post(
                                            name: .init("resetProjector"),
                                            object: nil
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Spacer()
                                
                                Text(projectorManager.isProjectorWindowVisible ? "Projector Active" : "Projector Hidden")
                                    .font(.caption)
                                    .foregroundColor(projectorManager.isProjectorWindowVisible ? .green : .secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    HStack {
                        Text("Fade Duration:")
                        Slider(value: $fadeRevealDuration, in: 0.5...3.0, step: 0.5)
                            .frame(width: 200)
                        Text("\(fadeRevealDuration, specifier: "%.1f")s")
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Warning Duration:")
                        Slider(value: $warningDuration, in: 1.0...5.0, step: 1.0)
                            .frame(width: 200)
                        Text("\(warningDuration, specifier: "%.0f")s")
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Minimum Display Duration:")
                        Slider(value: $minimumDisplayDuration, in: 5.0...30.0, step: 1.0)
                            .frame(width: 200)
                        Text("\(minimumDisplayDuration, specifier: "%.0f")s")
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text("Single Display Mode:")
                        Spacer()
                        Toggle("", isOn: $singleDisplayMode)
                    }
                    
                    HStack {
                        Text("Auto-Show Projector:")
                        Spacer()
                        Toggle("", isOn: $autoShowProjector)
                    }
                }
                .padding()
            }
            
            GroupBox("Cache Management") {
                VStack(alignment: .leading, spacing: 12) {
                    // Cache Statistics Summary
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache Size:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(cacheStats.formattedSize)
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Files:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(cacheStats.totalFiles)")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Status:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(cacheStats.needsCleanup ? "Needs Cleanup" : "Healthy")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(cacheStats.needsCleanup ? .orange : .green)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Quick Actions
                    HStack {
                        Button("Refresh Stats") {
                            Task {
                                await cacheService.refreshCacheStatistics()
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Quick Clean (7 days)") {
                            Task {
                                try? await cacheService.cleanupCache(retentionDays: 7)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(cacheService.isCleaningUp)
                        
                        Spacer()
                        
                        Button("Advanced...") {
                            showingCacheManagement = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    // Auto-cleanup toggle
                    HStack {
                        Text("Automatic Cleanup:")
                        Spacer()
                        Toggle("", isOn: $cacheService.automaticCleanupEnabled)
                        
                        if cacheService.automaticCleanupEnabled {
                            Text("(\(cacheService.automaticCleanupRetentionDays) days)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if cacheService.isCleaningUp {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Cleaning cache...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            
            GroupBox("API Information") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("OpenAI Status:")
                        Text(configurationService.isOpenAIConfigured ? "Configured ✓" : "Not configured ✗")
                            .foregroundColor(configurationService.isOpenAIConfigured ? .green : .red)
                    }
                    
                    HStack {
                        Text("Twilio Status:")
                        Text(configurationService.isTwilioConfigured ? "Configured ✓" : "Not configured ✗")
                            .foregroundColor(configurationService.isTwilioConfigured ? .green : .red)
                    }
                    
                    HStack {
                        Text("Image Quality:")
                        Spacer()
                        Picker("Image Quality", selection: $imageQuality) {
                            Text("Low (Fast)").tag("low")
                            Text("Medium (Balanced)").tag("medium")
                            Text("High (Detailed)").tag("high")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                    }
                    
                    Text("Note: API credentials are stored securely in Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }
            
            Spacer()
            
            Divider()
            
            HStack {
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(minWidth: 500, maxWidth: 600, minHeight: 400, maxHeight: 600)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            Task {
                await cacheService.refreshCacheStatistics()
            }
        }
        .sheet(isPresented: $showingCacheManagement) {
            CacheManagementView(cacheService: cacheService)
        }
    }
    
    private func clearCache() {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let boothURL = picturesURL.appendingPathComponent("booth")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: boothURL, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
                                logError("\(LoggingService.Emoji.error) Failed to clear cache: \(error)", category: .error)
        }
    }
} 