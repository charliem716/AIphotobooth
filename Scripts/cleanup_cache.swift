#!/usr/bin/env swift

import Foundation

// Cache cleanup utility for PhotoBooth

let fileManager = FileManager.default
let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
let boothURL = picturesURL.appendingPathComponent("booth")

// Default retention: 7 days
let retentionDays = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 7 : 7
let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 24 * 60 * 60))

print("🧹 PhotoBooth Cache Cleanup")
print("📁 Cache directory: \(boothURL.path)")
print("🗓️  Removing files older than \(retentionDays) days")
print("")

do {
    // Create directory if it doesn't exist
    if !fileManager.fileExists(atPath: boothURL.path) {
        print("No cache directory found. Nothing to clean.")
        exit(0)
    }
    
    let files = try fileManager.contentsOfDirectory(at: boothURL, includingPropertiesForKeys: [.creationDateKey])
    var deletedCount = 0
    var totalSize: Int64 = 0
    
    for file in files {
        let attributes = try fileManager.attributesOfItem(atPath: file.path)
        if let creationDate = attributes[.creationDate] as? Date,
           creationDate < cutoffDate {
            let size = attributes[.size] as? Int64 ?? 0
            totalSize += size
            try fileManager.removeItem(at: file)
            deletedCount += 1
            print("❌ Deleted: \(file.lastPathComponent)")
        }
    }
    
    if deletedCount > 0 {
        let sizeInMB = Double(totalSize) / 1024.0 / 1024.0
        print("")
        print("✅ Cleanup complete!")
        print("📊 Deleted \(deletedCount) files, freed \(String(format: "%.2f", sizeInMB)) MB")
    } else {
        print("✨ No old files to clean up!")
    }
    
} catch {
    print("❌ Error during cleanup: \(error.localizedDescription)")
    exit(1)
} 