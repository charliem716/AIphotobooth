import SwiftUI

struct SettingsView: View {
    @AppStorage("projectorScreenIndex") private var projectorScreenIndex = 1
    @AppStorage("fadeRevealDuration") private var fadeRevealDuration = 1.0
    @AppStorage("cacheRetentionDays") private var cacheRetentionDays = 7
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .bold()
                .padding(.bottom)
            
            GroupBox("Display Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Projector Screen:")
                        Picker("", selection: $projectorScreenIndex) {
                            ForEach(0..<NSScreen.screens.count, id: \.self) { index in
                                Text("Screen \(index + 1)")
                                    .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
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
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
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