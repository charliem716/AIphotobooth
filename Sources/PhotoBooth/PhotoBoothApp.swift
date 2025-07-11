import SwiftUI
import SwiftDotenv

@main
struct PhotoBoothApp: App {
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
                .environmentObject(PhotoBoothViewModel())
                .environmentObject(projectorManager)
        }
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
        }
    }
} 