import SwiftUI
import SwiftDotenv

@main
struct PhotoBoothApp: App {
    @StateObject private var sharedViewModel = PhotoBoothViewModel()
    @StateObject private var projectorManager = ProjectorWindowManager()
    
    init() {
        // Load environment variables
        do {
            try Dotenv.configure()
        } catch {
            print("Warning: Could not load .env file: \(error)")
        }
    }
    
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
            
            // Custom commands
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
        
        Settings {
            SettingsView()
        }
    }
} 