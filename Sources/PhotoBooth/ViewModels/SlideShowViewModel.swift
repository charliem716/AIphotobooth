import SwiftUI
import Combine
import Foundation

@MainActor
class SlideShowViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var photoPairs: [PhotoPair] = []
    @Published var currentPairIndex = 0
    @Published var displayDuration: Double = 5.0  // 5 seconds for each image (original and themed)
    @Published var isShowingOriginal = true
    @Published var lastFolderScan = Date.distantPast
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let boothDirectory: URL
    private var currentTimerTask: Task<Void, Never>?
    
    // MARK: - Caching Properties
    private var imageCache: [Int: PhotoPair] = [:]
    private let cacheSize = 5 // Pre-load next 5 photo pairs
    
    // MARK: - Background Scanning Properties
    private let scanInterval: TimeInterval = 10.0 // Scan every 10 seconds
    
    // MARK: - Initialization
    init() {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        self.boothDirectory = picturesURL.appendingPathComponent("booth")
        
        // Listen for new photo notifications
        NotificationCenter.default.publisher(for: .newPhotoCapture)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.scanForPhotoPairs()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Start the slideshow if photos are available
    func startSlideshow() async {
        logInfo("\(LoggingService.Emoji.slideshow) SlideShowViewModel.startSlideshow() called", category: .slideshow)
        
        await scanForPhotoPairs()
        logInfo("\(LoggingService.Emoji.slideshow) After scan: found \(photoPairs.count) photo pairs", category: .slideshow)
        
        guard !photoPairs.isEmpty else {
            logWarning("\(LoggingService.Emoji.warning) No photo pairs available for slideshow", category: .slideshow)
            errorMessage = "No photo pairs available for slideshow"
            return
        }
        
        logDebug("\(LoggingService.Emoji.slideshow) Setting isActive to true...", category: .slideshow)
        isActive = true
        logDebug("\(LoggingService.Emoji.slideshow) isActive is now: \(isActive)", category: .slideshow)
        
        currentPairIndex = 0
        isShowingOriginal = true
        
        // Initialize cache for smooth performance
        updateImageCache()
        
        // Start background scanning for new photos
        startBackgroundScanning()
        
        startSlideTimer()
        
        logInfo("\(LoggingService.Emoji.slideshow) Slideshow started with \(photoPairs.count) photo pairs - isActive: \(isActive)", category: .slideshow)
        
        // Add a delay to check if it immediately becomes inactive using modern async
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            logDebug("\(LoggingService.Emoji.debug) One second later - isActive: \(self.isActive)", category: .slideshow)
        }
    }
    
    /// Stop the slideshow and cleanup
    func stopSlideshow() {
        logInfo("\(LoggingService.Emoji.slideshow) stopSlideshow() called - was active: \(isActive)", category: .slideshow)
        logDebug("\(LoggingService.Emoji.slideshow) Call stack: \(Thread.callStackSymbols.prefix(5))", category: .slideshow)
        
        isActive = false
        
        // Cancel any running timer task
        currentTimerTask?.cancel()
        currentTimerTask = nil
        
        // Modern async patterns handle cleanup automatically
        errorMessage = nil
        
        // Stop background scanning
        stopBackgroundScanning()
        
        // Clear cache to free memory
        clearImageCache()
        
        logInfo("\(LoggingService.Emoji.slideshow) Slideshow stopped")
    }
    
    /// Scan the booth folder for matching photo pairs
    func scanForPhotoPairs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check if booth directory exists and is accessible
            if !FileManager.default.fileExists(atPath: boothDirectory.path) {
                logInfo("\(LoggingService.Emoji.config) Creating booth directory: \(boothDirectory.path)", category: .slideshow)
                try FileManager.default.createDirectory(at: boothDirectory, withIntermediateDirectories: true)
                photoPairs = []
                isLoading = false
                return
            }
            
            // Verify directory permissions
            guard FileManager.default.isReadableFile(atPath: boothDirectory.path) else {
                throw SlideShowError.directoryPermissionDenied(boothDirectory.path)
            }
            
            // Scan for files with error handling
            let files: [URL]
            do {
                files = try FileManager.default.contentsOfDirectory(at: boothDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            } catch {
                throw SlideShowError.directoryReadFailed(error.localizedDescription)
            }
            
            // Filter and validate files
            let validFiles = files.filter { file in
                let filename = file.lastPathComponent
                let isValidPhoto = (filename.hasPrefix("original_") || filename.hasPrefix("themed_")) && filename.hasSuffix(".jpg")
                
                // Check file size to avoid corrupted files
                if isValidPhoto {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        if fileSize < 1024 { // Less than 1KB is likely corrupted
                            logWarning("\(LoggingService.Emoji.warning) Skipping suspiciously small file: \(filename) (\(fileSize) bytes)", category: .slideshow)
                            return false
                        }
                    } catch {
                        logWarning("\(LoggingService.Emoji.warning) Could not check file size for: \(filename)", category: .slideshow)
                        return false
                    }
                }
                
                return isValidPhoto
            }
            
            logDebug("\(LoggingService.Emoji.slideshow) Scanning \(validFiles.count) valid photo files from \(files.count) total files", category: .slideshow)
            
            let newPairs = await discoverPhotoPairs(from: validFiles)
            
            // Sort by timestamp (newest first for attraction value)
            photoPairs = newPairs.sorted(by: >)
            lastFolderScan = Date()
            
            logInfo("\(LoggingService.Emoji.slideshow) Successfully found \(photoPairs.count) complete photo pairs", category: .slideshow)
            
            // Clear error if scan was successful
            if !photoPairs.isEmpty {
                errorMessage = nil
            }
            
        } catch {
            let friendlyError = getFriendlyErrorMessage(for: error)
            errorMessage = friendlyError
            logError("\(LoggingService.Emoji.error) Error scanning for photo pairs: \(error)", category: .slideshow)
        }
        
        isLoading = false
    }
    
    /// Update the display duration for slideshow timing
    func updateDisplayDuration(_ seconds: Double) {
        displayDuration = max(2.0, min(10.0, seconds)) // Clamp between 2-10 seconds
        
        // If slideshow is active, restart timer with new duration
        if isActive {
            startSlideTimer()
        }
    }
    
    /// Advance to the next photo in the slideshow
    func nextPhoto() {
        guard !photoPairs.isEmpty else { 
            logWarning("nextPhoto() called but no photo pairs available", category: .slideshow)
            return 
        }
        
        if isShowingOriginal {
            // Switch to themed version of current pair
            logDebug("Switching to themed image for pair \(currentPairIndex + 1)", category: .slideshow)
            isShowingOriginal = false
        } else {
            // Move to next pair and show original
            let previousIndex = currentPairIndex
            currentPairIndex = (currentPairIndex + 1) % photoPairs.count
            logDebug("Moving to next pair: \(previousIndex + 1) -> \(currentPairIndex + 1), showing original", category: .slideshow)
            isShowingOriginal = true
            
            // Update cache when moving to new photo pair
            updateImageCache()
        }
        
        logDebug("Now showing: \(isShowingOriginal ? "Original" : "Themed") image \(currentPairIndex + 1)/\(photoPairs.count)", category: .slideshow)
        startSlideTimer()
    }
    
    /// Get the currently displayed image (with caching support)
    var currentImage: NSImage? {
        guard !photoPairs.isEmpty,
              currentPairIndex < photoPairs.count else { return nil }
        
        // Use cached version if available, otherwise use original
        let currentPair = imageCache[currentPairIndex] ?? photoPairs[currentPairIndex]
        return isShowingOriginal ? currentPair.originalImage : currentPair.themedImage
    }
    
    /// Get slideshow progress info
    var progressInfo: String {
        guard !photoPairs.isEmpty else { return "No photos" }
        let photoNum = currentPairIndex + 1
        let imageType = isShowingOriginal ? "Original" : "Themed"
        return "\(imageType) \(photoNum) of \(photoPairs.count)"
    }
    
    // MARK: - Cache Management
    
    /// Pre-load images around the current index for smooth transitions
    private func updateImageCache() {
        guard !photoPairs.isEmpty else { return }
        
        // Clear old cache entries that are far from current position
        let keepIndices = Set(getCacheIndices())
        imageCache = imageCache.filter { keepIndices.contains($0.key) }
        
        // Pre-load new images in background
        Task {
            for index in getCacheIndices() {
                if imageCache[index] == nil && index < photoPairs.count {
                    await loadImageIntoCache(at: index)
                }
            }
        }
    }
    
    /// Get indices that should be cached around current position
    private func getCacheIndices() -> [Int] {
        let startIndex = max(0, currentPairIndex - 1)
        let endIndex = min(photoPairs.count - 1, currentPairIndex + cacheSize)
        return Array(startIndex...endIndex)
    }
    
    /// Load a specific photo pair into cache
    private func loadImageIntoCache(at index: Int) async {
        guard index < photoPairs.count else { return }
        
        let pair = photoPairs[index]
        
        // Images are already loaded in PhotoPair init, so just add to cache
        await MainActor.run {
            imageCache[index] = pair
        }
        
        logDebug("\(LoggingService.Emoji.slideshow) Cached photo pair at index \(index)", category: .slideshow)
    }
    
    /// Clear all cached images to free memory
    private func clearImageCache() {
        imageCache.removeAll()
        logDebug("\(LoggingService.Emoji.slideshow) Image cache cleared", category: .slideshow)
    }
    
    // MARK: - Background Scanning
    
    /// Start periodic background scanning for new photos using modern async patterns
    private func startBackgroundScanning() {
        logDebug("\(LoggingService.Emoji.refresh) Background photo scanning started (every \(scanInterval)s)", category: .slideshow)
        
        // Start modern async background scanning
        Task { @MainActor in
            await runBackgroundScanning()
        }
    }
    
    /// Stop background scanning (modernized for async patterns)
    private func stopBackgroundScanning() {
        logDebug("\(LoggingService.Emoji.debug) Background photo scanning stopped", category: .slideshow)
        // Async tasks will automatically cancel when isActive becomes false
    }
    
    /// Perform a background scan for new photos
    private func performBackgroundScan() async {
        let previousCount = photoPairs.count
        await scanForPhotoPairs()
        
        // If new photos were found, update cache
        if photoPairs.count > previousCount {
            let newPhotosCount = photoPairs.count - previousCount
            logInfo("\(LoggingService.Emoji.camera) Found \(newPhotosCount) new photo pair(s) during background scan", category: .slideshow)
            
            // Update cache to include new photos
            updateImageCache()
        }
    }
    
    // MARK: - Modern Async Timer Implementations
    
    /// Modern async background scanning implementation
    @MainActor
    private func runBackgroundScanning() async {
                 while isActive {
             try? await Task.sleep(for: .seconds(scanInterval))
             
             if isActive {
                 logDebug("\(LoggingService.Emoji.refresh) Running background photo scan", category: .slideshow)
                 await performBackgroundScan()
             }
         }
    }
    
    // MARK: - Private Methods
    
    private func startSlideTimer() {
        // Cancel any existing timer task
        currentTimerTask?.cancel()
        
        // Start modern async slide timing
        currentTimerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(displayDuration))
            if isActive && !Task.isCancelled {
                nextPhoto()
            }
        }
    }
    
    private func discoverPhotoPairs(from files: [URL]) async -> [PhotoPair] {
        var pairs: [PhotoPair] = []
        var originalFiles: [(url: URL, timestamp: String)] = []
        var themedFiles: [(url: URL, timestamp: String)] = []
        
        // Parse and group files by exact timestamp
        for file in files {
            let filename = file.lastPathComponent
            
            if filename.hasPrefix("original_") && filename.hasSuffix(".jpg") {
                let timestampString = String(filename.dropFirst("original_".count).dropLast(".jpg".count))
                originalFiles.append((url: file, timestamp: timestampString))
            } else if filename.hasPrefix("themed_") && filename.hasSuffix(".jpg") {
                let timestampString = String(filename.dropFirst("themed_".count).dropLast(".jpg".count))
                themedFiles.append((url: file, timestamp: timestampString))
            }
        }
        
        logDebug("\(LoggingService.Emoji.slideshow) Found \(originalFiles.count) original files and \(themedFiles.count) themed files", category: .slideshow)
        
        // Match original and themed files by exact timestamp
        for original in originalFiles {
            // Find themed file with exact matching timestamp
            let matchingThemed = themedFiles.first { themed in
                themed.timestamp == original.timestamp
            }
            
            if let themed = matchingThemed {
                // Convert timestamp string to TimeInterval for PhotoPair
                guard let timestampDouble = Double(original.timestamp) else {
                    logWarning("\(LoggingService.Emoji.warning) Invalid timestamp format: \(original.timestamp)", category: .slideshow)
                    continue
                }
                let date = Date(timeIntervalSince1970: timestampDouble)
                
                if let photoPair = PhotoPair(originalURL: original.url, themedURL: themed.url, timestamp: date) {
                    pairs.append(photoPair)
                    logDebug("\(LoggingService.Emoji.success) Paired: \(original.url.lastPathComponent) + \(themed.url.lastPathComponent)", category: .slideshow)
                } else {
                    logWarning("\(LoggingService.Emoji.warning) Failed to create PhotoPair for \(original.url.lastPathComponent)", category: .slideshow)
                }
            } else {
                logWarning("\(LoggingService.Emoji.warning) No matching themed file found for \(original.url.lastPathComponent)", category: .slideshow)
            }
        }
        
        return pairs
    }
    

    
    // MARK: - Error Handling
    
    /// Convert technical errors to user-friendly messages
    private func getFriendlyErrorMessage(for error: Error) -> String {
        if let slideShowError = error as? SlideShowError {
            switch slideShowError {
            case .directoryPermissionDenied(let path):
                return "Cannot access photo folder at \(path). Please check permissions."
            case .directoryReadFailed(let details):
                return "Failed to read photo folder: \(details)"
            case .noValidPhotos:
                return "No valid photo pairs found. Take some photos with the booth first!"
            case .cacheError(let details):
                return "Image loading error: \(details)"
            }
        }
        
        // Handle system errors
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSFileReadNoPermissionError:
                return "Permission denied accessing photo folder. Please check folder permissions."
            case NSFileReadNoSuchFileError:
                return "Photo folder not found. Photos will be created when you use the booth."
            default:
                return "File system error: \(nsError.localizedDescription)"
            }
        }
        
        return "An unexpected error occurred: \(error.localizedDescription)"
    }
}

// MARK: - Supporting Types

/// Specific errors for slideshow operations
enum SlideShowError: Error, LocalizedError {
    case directoryPermissionDenied(String)
    case directoryReadFailed(String)
    case noValidPhotos
    case cacheError(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryPermissionDenied(let path):
            return "Permission denied for directory: \(path)"
        case .directoryReadFailed(let details):
            return "Directory read failed: \(details)"
        case .noValidPhotos:
            return "No valid photo pairs found"
        case .cacheError(let details):
            return "Cache error: \(details)"
        }
    }
}

// MARK: - Extensions
extension Notification.Name {
    static let slideshowStarted = Notification.Name("slideshowStarted")
    static let slideshowStopped = Notification.Name("slideshowStopped")
} 