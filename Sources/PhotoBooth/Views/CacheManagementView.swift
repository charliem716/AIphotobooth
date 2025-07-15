import SwiftUI
import os.log

struct CacheManagementView: View {
    @ObservedObject var cacheService: CacheManagementService
    @State private var showingCleanupAlert = false
    @State private var showingCleanupProgress = false
    @State private var selectedRetentionDays = 7
    @State private var showingExportSheet = false
    @State private var exportedScriptURL: URL?
    @State private var cleanupResult: String = ""
    @State private var showingResultAlert = false
    
    // Retention day options
    private let retentionOptions = [1, 3, 7, 14, 30, 60, 90]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Manage photo cache, monitor storage usage, and configure automatic cleanup.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Cache Statistics
                CacheStatisticsCard(statistics: cacheService.cacheStatistics)
                    .onAppear {
                        Task {
                            await cacheService.refreshCacheStatistics()
                        }
                    }
                
                // MARK: - Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        QuickActionButton(
                            title: "Refresh Stats",
                            systemImage: "arrow.clockwise",
                            color: .blue,
                            isLoading: false
                        ) {
                            Task {
                                await cacheService.refreshCacheStatistics()
                            }
                        }
                        
                        QuickActionButton(
                            title: "Quick Clean",
                            systemImage: "trash",
                            color: .orange,
                            isLoading: cacheService.isCleaningUp
                        ) {
                            selectedRetentionDays = 7
                            showingCleanupAlert = true
                        }
                        
                        QuickActionButton(
                            title: "Export Script",
                            systemImage: "square.and.arrow.up",
                            color: .green,
                            isLoading: false
                        ) {
                            exportCleanupScript()
                        }
                        
                        QuickActionButton(
                            title: "Reset Settings",
                            systemImage: "arrow.counterclockwise",
                            color: .red,
                            isLoading: false
                        ) {
                            resetToDefaults()
                        }
                    }
                }
                
                // MARK: - Automatic Cleanup Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Automatic Cleanup")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Automatic Cleanup", isOn: $cacheService.automaticCleanupEnabled)
                            .font(.subheadline)
                        
                        if cacheService.automaticCleanupEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Retention Period")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Retention Days", selection: $cacheService.automaticCleanupRetentionDays) {
                                    ForEach(retentionOptions, id: \.self) { days in
                                        Text(retentionText(for: days))
                                            .tag(days)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                if let lastCleanup = cacheService.lastCleanupDate {
                                    Text("Last cleanup: \(lastCleanup.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No cleanup performed yet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 16)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // MARK: - Manual Cleanup
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manual Cleanup")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remove photos older than:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Retention Days", selection: $selectedRetentionDays) {
                            ForEach(retentionOptions, id: \.self) { days in
                                Text(retentionText(for: days))
                                    .tag(days)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Button(action: {
                            showingCleanupAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clean Cache")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cacheService.isCleaningUp)
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // MARK: - Cache Health
                CacheHealthView(statistics: cacheService.cacheStatistics)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Cache Management")
        .alert("Clean Cache", isPresented: $showingCleanupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                performCleanup()
            }
        } message: {
            Text("This will remove all photos older than \(selectedRetentionDays) \(selectedRetentionDays == 1 ? "day" : "days"). This action cannot be undone.")
        }
        .alert("Cleanup Complete", isPresented: $showingResultAlert) {
            Button("OK") { }
        } message: {
            Text(cleanupResult)
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedScriptURL {
                ScriptExportView(scriptURL: url)
            }
        }
        .overlay(
            Group {
                if cacheService.isCleaningUp {
                    CleanupProgressView()
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func retentionText(for days: Int) -> String {
        switch days {
        case 1: return "1 day"
        case 7: return "1 week"
        case 14: return "2 weeks"
        case 30: return "1 month"
        case 60: return "2 months"
        case 90: return "3 months"
        default: return "\(days) days"
        }
    }
    
    private func performCleanup() {
        Task {
            do {
                let initialStats = cacheService.cacheStatistics
                try await cacheService.cleanupCache(retentionDays: selectedRetentionDays)
                await cacheService.refreshCacheStatistics()
                
                let finalStats = cacheService.cacheStatistics
                let filesRemoved = initialStats.totalFiles - finalStats.totalFiles
                let sizeFreed = initialStats.totalSizeBytes - finalStats.totalSizeBytes
                
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
                formatter.countStyle = .file
                
                cleanupResult = "Successfully removed \(filesRemoved) files and freed \(formatter.string(fromByteCount: sizeFreed)) of storage."
                showingResultAlert = true
            } catch {
                cleanupResult = "Cleanup failed: \(error.localizedDescription)"
                showingResultAlert = true
            }
        }
    }
    
    private func exportCleanupScript() {
        Task {
            do {
                let scriptURL = try cacheService.exportCacheCleanupScript()
                await MainActor.run {
                    exportedScriptURL = scriptURL
                    showingExportSheet = true
                }
            } catch {
                cleanupResult = "Failed to export script: \(error.localizedDescription)"
                showingResultAlert = true
            }
        }
    }
    
    private func resetToDefaults() {
        cacheService.automaticCleanupEnabled = false
        cacheService.automaticCleanupRetentionDays = 7
        selectedRetentionDays = 7
    }
}

// MARK: - Supporting Views

struct CacheStatisticsCard: View {
    let statistics: CacheStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatisticItem(
                    title: "Total Size",
                    value: statistics.formattedSize,
                    icon: "externaldrive",
                    color: statistics.needsCleanup ? .orange : .blue
                )
                
                StatisticItem(
                    title: "File Count",
                    value: "\(statistics.totalFiles)",
                    icon: "doc.on.doc",
                    color: .green
                )
                
                StatisticItem(
                    title: "Cache Age",
                    value: statistics.cacheAgeDays > 0 ? "\(statistics.cacheAgeDays) days" : "New",
                    icon: "clock",
                    color: statistics.cacheAgeDays > 30 ? .red : .gray
                )
                
                StatisticItem(
                    title: "Status",
                    value: statistics.needsCleanup ? "Needs Cleanup" : "Healthy",
                    icon: statistics.needsCleanup ? "exclamationmark.triangle" : "checkmark.circle",
                    color: statistics.needsCleanup ? .red : .green
                )
            }
            
            Text("Statistics updated when cache operations are performed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(6)
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: systemImage)
                    }
                }
                .frame(width: 16, height: 16)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding()
            .background(color)
            .cornerRadius(8)
        }
        .disabled(isLoading)
    }
}

struct CacheHealthView: View {
    let statistics: CacheStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Health")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HealthIndicator(
                    title: "Storage Usage",
                    status: storageHealthStatus,
                    message: storageHealthMessage
                )
                
                HealthIndicator(
                    title: "Cache Age",
                    status: ageHealthStatus,
                    message: ageHealthMessage
                )
                
                HealthIndicator(
                    title: "File Count",
                    status: fileCountHealthStatus,
                    message: fileCountHealthMessage
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var storageHealthStatus: HealthStatus {
        let sizeInGB = Double(statistics.totalSizeBytes) / (1024 * 1024 * 1024)
        if sizeInGB > 2.0 { return .warning }
        if sizeInGB > 1.0 { return .caution }
        return .healthy
    }
    
    private var storageHealthMessage: String {
        let sizeInGB = Double(statistics.totalSizeBytes) / (1024 * 1024 * 1024)
        if sizeInGB > 2.0 { return "Cache is using significant storage space" }
        if sizeInGB > 1.0 { return "Cache size is moderate" }
        return "Cache size is optimal"
    }
    
    private var ageHealthStatus: HealthStatus {
        if statistics.cacheAgeDays > 60 { return .warning }
        if statistics.cacheAgeDays > 30 { return .caution }
        return .healthy
    }
    
    private var ageHealthMessage: String {
        if statistics.cacheAgeDays > 60 { return "Cache contains very old files" }
        if statistics.cacheAgeDays > 30 { return "Cache contains old files" }
        return "Cache age is reasonable"
    }
    
    private var fileCountHealthStatus: HealthStatus {
        if statistics.totalFiles > 1000 { return .warning }
        if statistics.totalFiles > 500 { return .caution }
        return .healthy
    }
    
    private var fileCountHealthMessage: String {
        if statistics.totalFiles > 1000 { return "Very high number of cached files" }
        if statistics.totalFiles > 500 { return "High number of cached files" }
        return "File count is reasonable"
    }
}

struct HealthIndicator: View {
    let title: String
    let status: HealthStatus
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(6)
    }
}

struct CleanupProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Cleaning cache...")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Please wait while old files are being removed")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

struct ScriptExportView: View {
    let scriptURL: URL
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Cleanup Script Exported")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("The cache cleanup script has been exported to:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(scriptURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                
                Button("Open in Finder") {
                    NSWorkspace.shared.selectFile(scriptURL.path, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Script Export")
        }
    }
}

enum HealthStatus {
    case healthy
    case caution
    case warning
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .caution: return .orange
        case .warning: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle"
        case .caution: return "exclamationmark.triangle"
        case .warning: return "xmark.circle"
        }
    }
} 