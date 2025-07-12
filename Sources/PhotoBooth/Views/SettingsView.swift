import SwiftUI

struct SettingsView: View {
    @AppStorage("fadeRevealDuration") private var fadeRevealDuration = 1.0
    @AppStorage("cacheRetentionDays") private var cacheRetentionDays = 7
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectorManager: ProjectorWindowManager
    
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
                            if NSScreen.screens.count <= 1 {
                                Text("Single Display")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Multi-Display")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text("Main Interface: Always on laptop screen (Screen 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if NSScreen.screens.count <= 1 {
                            Text("⚠️ Connect a second display to use projector features")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("✓ Projector: Automatically uses Screen 2")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        // Manual projector controls
                        if NSScreen.screens.count > 1 {
                            HStack {
                                Button(projectorManager.isProjectorWindowVisible ? "Hide Projector" : "Show Projector") {
                                    if projectorManager.isProjectorWindowVisible {
                                        projectorManager.hideProjectorWindow()
                                    } else {
                                        projectorManager.showProjectorWindow()
                                    }
                                }
                                .buttonStyle(.bordered)
                                
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
                }
                .padding()
            }
            
            GroupBox("Cache Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Keep photos for:")
                        Picker("", selection: $cacheRetentionDays) {
                            Text("3 days").tag(3)
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    Button("Clear Cache Now") {
                        clearCache()
                    }
                }
                .padding()
            }
            
            GroupBox("API Information") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("OpenAI Status:")
                        Text(ProcessInfo.processInfo.environment["OPENAI_KEY"] != nil ? "Configured ✓" : "Not configured ✗")
                            .foregroundColor(ProcessInfo.processInfo.environment["OPENAI_KEY"] != nil ? .green : .red)
                    }
                    
                    HStack {
                        Text("Twilio Status:")
                        Text(isTwilioConfigured() ? "Configured ✓" : "Not configured ✗")
                            .foregroundColor(isTwilioConfigured() ? .green : .red)
                    }
                    
                    Text("Note: Edit .env file to configure API credentials")
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
    }
    
    private func isTwilioConfigured() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["TWILIO_SID"] != nil && 
               env["TWILIO_TOKEN"] != nil && 
               env["TWILIO_FROM"] != nil
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
            print("Failed to clear cache: \(error)")
        }
    }
} 