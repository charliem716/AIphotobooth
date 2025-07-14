/**
 * PhotoBoothApp.swift
 * PhotoBooth
 *
 * Main application entry point for the PhotoBooth SwiftUI app.
 * 
 * This app provides a complete photo booth experience with:
 * - Real-time camera preview and photo capture
 * - AI-powered themed image generation using OpenAI's GPT-image-1 model
 * - Dual-display support with projector mode for external screens
 * - Slideshow functionality for displaying captured photos
 * - Modern SwiftUI architecture with service-based design
 *
 * The app uses environment variables for configuration and supports
 * both local and Continuity Camera capture modes.
 *
 * Author: AI Photo Booth Team
 * Created: 2024
 */

import SwiftUI
import SwiftDotenv

/// Main application structure providing app lifecycle and window management
@main
struct PhotoBoothApp: App {
    /// Shared view model for photo booth operations and state management
    @StateObject private var sharedViewModel = PhotoBoothViewModel()
    
    /// Manager for projector/external display functionality
    @StateObject private var projectorManager = ProjectorWindowManager()
    
    /// Initialize the application and load environment configuration
    init() {
        // Load environment variables from .env file for API keys and configuration
        do {
            try Dotenv.configure()
        } catch {
            logWarning("\(LoggingService.Emoji.config) Could not load .env file", category: .configuration)
        }
    }
    
    /// Main application scene configuration with window management and commands
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedViewModel)
                .environmentObject(projectorManager)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 1000, height: 800)
        .commands {
            // Add standard window commands including fullscreen
            SidebarCommands()
            ToolbarCommands()
            
            // Custom commands for projector control
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Projector") {
                    if projectorManager.isProjectorWindowVisible {
                        projectorManager.hideProjectorWindow()
                    } else {
                        projectorManager.showProjectorWindow()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
        
        /// Settings window for app configuration
        Settings {
            SettingsView()
        }
    }
} 