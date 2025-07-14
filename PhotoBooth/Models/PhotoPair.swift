import Foundation
import AppKit

/// Represents a matched pair of original and themed photos for slideshow display
struct PhotoPair: Identifiable {
    let id = UUID()
    let original: URL
    let themed: URL
    let timestamp: Date
    let originalImage: NSImage
    let themedImage: NSImage
    
    /// Initialize a PhotoPair from file URLs
    /// - Parameters:
    ///   - originalURL: Path to the original photo file
    ///   - themedURL: Path to the themed photo file
    ///   - timestamp: Creation timestamp extracted from filename
    init?(originalURL: URL, themedURL: URL, timestamp: Date) {
        // Validate that both files exist and are readable
        guard FileManager.default.fileExists(atPath: originalURL.path),
              FileManager.default.fileExists(atPath: themedURL.path) else {
            print("⚠️ PhotoPair init failed: Missing files")
            print("   Original: \(originalURL.path) - \(FileManager.default.fileExists(atPath: originalURL.path) ? "✅" : "❌")")
            print("   Themed: \(themedURL.path) - \(FileManager.default.fileExists(atPath: themedURL.path) ? "✅" : "❌")")
            return nil
        }
        
        // Check file permissions and readability
        guard FileManager.default.isReadableFile(atPath: originalURL.path),
              FileManager.default.isReadableFile(atPath: themedURL.path) else {
            print("⚠️ PhotoPair init failed: Files not readable")
            print("   Original readable: \(FileManager.default.isReadableFile(atPath: originalURL.path))")
            print("   Themed readable: \(FileManager.default.isReadableFile(atPath: themedURL.path))")
            return nil
        }
        
        // Load and validate images
        do {
            let originalData = try Data(contentsOf: originalURL)
            let themedData = try Data(contentsOf: themedURL)
            
            guard let originalImage = NSImage(data: originalData),
                  let themedImage = NSImage(data: themedData) else {
                print("⚠️ PhotoPair init failed: Invalid image data")
                print("   Original data size: \(originalData.count) bytes")
                print("   Themed data size: \(themedData.count) bytes")
                return nil
            }
            
            // Validate image dimensions
            guard originalImage.size.width > 0 && originalImage.size.height > 0,
                  themedImage.size.width > 0 && themedImage.size.height > 0 else {
                print("⚠️ PhotoPair init failed: Invalid image dimensions")
                print("   Original: \(originalImage.size)")
                print("   Themed: \(themedImage.size)")
                return nil
            }
            
            self.original = originalURL
            self.themed = themedURL
            self.timestamp = timestamp
            self.originalImage = originalImage
            self.themedImage = themedImage
            
        } catch {
            print("⚠️ PhotoPair init failed: \(error.localizedDescription)")
            print("   Original: \(originalURL.path)")
            print("   Themed: \(themedURL.path)")
            return nil
        }
    }
}

// MARK: - Equatable
extension PhotoPair: Equatable {
    static func == (lhs: PhotoPair, rhs: PhotoPair) -> Bool {
        lhs.original == rhs.original && lhs.themed == rhs.themed
    }
}

// MARK: - Comparable for sorting by timestamp
extension PhotoPair: Comparable {
    static func < (lhs: PhotoPair, rhs: PhotoPair) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
} 