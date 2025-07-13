import SwiftUI
import OpenAI
import AVFoundation
import Combine

@MainActor
class PhotoBoothViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var isCameraConnected = false
    @Published var selectedTheme: PhotoTheme?
    @Published var countdown = 0
    @Published var isCountingDown = false
    @Published var isProcessing = false
    @Published var lastCapturedImage: NSImage?
    @Published var lastThemedImage: NSImage?
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - New State Properties for UI Updates
    @Published var isReadyForNextPhoto = true
    @Published var minimumDisplayTimeRemaining = 0
    @Published var isInMinimumDisplayPeriod = false
    
    // MARK: - Camera Selection Properties
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraDevice: AVCaptureDevice?
    
    // MARK: - Camera Properties
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Services
    private var openAI: OpenAI?
    
    // MARK: - Other Properties
    private var countdownTimer: Timer?
    var minimumDisplayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Settings
    @AppStorage("minimumDisplayDuration") var minimumDisplayDuration = 10.0
    
    // MARK: - Themes
    let themes: [PhotoTheme] = [
        PhotoTheme(id: 1, name: "Studio Ghibli", prompt: "Transform this photo into Studio Ghibli anime style with soft watercolor backgrounds, whimsical characters, and magical atmosphere like Spirited Away or My Neighbor Totoro"),
        PhotoTheme(id: 2, name: "Simpsons", prompt: "Transform this photo into The Simpsons cartoon style with yellow skin, big eyes, overbite, and the iconic Springfield art style"),
        PhotoTheme(id: 3, name: "Rick and Morty", prompt: "Transform this photo into Rick and Morty animation style with exaggerated features, drooling mouths, unibrows, and sci-fi elements"),
        PhotoTheme(id: 4, name: "Dragon Ball Z", prompt: "Transform this photo into Dragon Ball Z anime style with spiky hair, intense expressions, power auras, and dynamic action poses"),
        PhotoTheme(id: 5, name: "Scooby Doo", prompt: "Transform this photo into Scooby Doo cartoon style with retro animation design and bright colors"),
        PhotoTheme(id: 6, name: "SpongeBob", prompt: "Transform this photo into SpongeBob SquarePants style with underwater Bikini Bottom setting, bright colors, and zany cartoon expressions"),
        PhotoTheme(id: 7, name: "South Park", prompt: "Transform this photo into South Park style with simple geometric shapes, cut-out animation look, beady eyes, and Colorado mountain town setting"),
        PhotoTheme(id: 8, name: "Pixar", prompt: "Transform this photo into Pixar animation style with vibrant colors, expressive cartoon features, and the distinctive 3D animated look of characters from Toy Story, Finding Nemo, and The Incredibles"),
        PhotoTheme(id: 9, name: "Flintstones", prompt: "Transform this photo into The Flintstones cartoon style with stone age setting, prehistoric elements, and classic Hanna-Barbera 60s animation design")
    ]
    
    override init() {
        super.init()
        setupServices()
        setupCamera()
    }
    
    deinit {
        minimumDisplayTimer?.invalidate()
        countdownTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupServices() {
        print("🔧 DEBUG: Setting up services...")
        
        // Initialize OpenAI
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_KEY"] {
            print("🔧 DEBUG: OpenAI API key found (length: \(apiKey.count))")
            print("🔧 DEBUG: API key starts with: \(String(apiKey.prefix(10)))...")
            openAI = OpenAI(apiToken: apiKey)
            print("✅ OpenAI service initialized")
        } else {
            print("❌ OpenAI API key not found in environment")
            showError(message: "OpenAI API key not found. Please add OPENAI_KEY to your .env file")
        }
    }
    
    private func setupCamera() {
        // Request camera permission first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            initializeCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.initializeCaptureSession()
                    } else {
                        self?.showError(message: "Camera access denied. Please enable camera access in System Preferences.")
                    }
                }
            }
        case .denied, .restricted:
            showError(message: "Camera access denied. Please enable camera access in System Preferences.")
        @unknown default:
            showError(message: "Unknown camera permission status.")
        }
    }
    
    private func initializeCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        findAndSetupContinuityCamera()
    }
    

    
    // MARK: - Camera Methods
    func refreshAvailableCameras() {
        print("🔍 [DEBUG] Starting comprehensive camera discovery...")
        
        // Try multiple discovery approaches for better iPhone detection
        let allDeviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .continuityCamera,
            .external
        ]
        
        print("🔍 [DEBUG] Searching for device types: \(allDeviceTypes.map { $0.rawValue })")
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: allDeviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        availableCameras = discoverySession.devices
        print("🔍 [DEBUG] Found \(availableCameras.count) total cameras:")
        
        for (index, device) in availableCameras.enumerated() {
            let isConnected = device.isConnected ? "✅ Connected" : "❌ Disconnected"
            let position = device.position.description
            print("   \(index + 1). \(device.localizedName)")
            print("      Type: \(device.deviceType.rawValue)")
            print("      Position: \(position)")
            print("      Status: \(isConnected)")
            print("      Unique ID: \(device.uniqueID)")
            
            // Special detection for potential iPhones
            if device.localizedName.lowercased().contains("iphone") ||
               device.localizedName.lowercased().contains("charlie") ||
               device.localizedName.contains("15 Pro") ||
               device.deviceType == .continuityCamera ||
               device.deviceType == .external {
                print("      ⭐ POTENTIAL CONTINUITY CAMERA DETECTED!")
            }
        }
        
        // Also try the default video devices approach
        let defaultDevices = AVCaptureDevice.devices(for: .video)
        print("🔍 [DEBUG] Default video devices: \(defaultDevices.count)")
        for device in defaultDevices {
            if !availableCameras.contains(device) {
                print("   Additional device: \(device.localizedName) (Type: \(device.deviceType.rawValue))")
                availableCameras.append(device)
            }
        }
        
        print("🔍 [DEBUG] Total cameras after comprehensive search: \(availableCameras.count)")
    }
    
    func selectCamera(_ device: AVCaptureDevice) {
        print("📱 [DEBUG] Manually selecting camera: \(device.localizedName)")
        selectedCameraDevice = device
        setupCamera(with: device)
    }
    
    func forceContinuityCameraConnection() {
        print("📱 [DEBUG] Forcing Continuity Camera connection...")
        refreshAvailableCameras()
        
        // Look for Charlie's iPhone specifically first
        if let charlieCamera = availableCameras.first(where: { 
            $0.localizedName.contains("Charlie") || $0.localizedName.contains("15 Pro")
        }) {
            print("📱 Found Charlie's iPhone: \(charlieCamera.localizedName)")
            selectCamera(charlieCamera)
        }
        // Then look for continuity camera type
        else if let continuityCamera = availableCameras.first(where: { $0.deviceType == .continuityCamera }) {
            print("📱 Found Continuity Camera: \(continuityCamera.localizedName)")
            selectCamera(continuityCamera)
        }
        // Then look for external cameras
        else if let externalCamera = availableCameras.first(where: { $0.deviceType == .external }) {
            print("📱 Found external camera: \(externalCamera.localizedName)")
            selectCamera(externalCamera)
        } else {
            print("❌ No Continuity Camera found")
            showError(message: getContinuityCameraSetupHelp())
        }
    }
    
    private func getContinuityCameraSetupHelp() -> String {
        return """
        Continuity Camera not found. To set up Continuity Camera:
        
        📱 **iPhone Setup:**
        1. iPhone must be running iOS 16 or later
        2. Sign in with the same Apple ID as your Mac
        3. Enable Two-Factor Authentication
        4. Turn on Bluetooth and Wi-Fi
        
        💻 **Mac Setup:**
        1. Mac must be running macOS Ventura 13 or later
        2. Sign in with same Apple ID as iPhone
        3. Enable Bluetooth and Wi-Fi
        4. Make sure both devices are on the same network
        
        🔗 **Connection Steps:**
        1. Place iPhone on a stand/tripod in landscape orientation
        2. Lock the iPhone screen (press power button)
        3. Keep iPhone close to Mac (within Bluetooth range)
        4. Wait 10-15 seconds for automatic detection
        5. iPhone should appear in camera list automatically
        
        💡 **Troubleshooting:**
        - Try turning Bluetooth off/on on both devices
        - Restart both iPhone and Mac
        - Check that Continuity Camera is enabled in iPhone Settings > General > AirPlay & Handoff
        - Make sure both devices are signed into the same iCloud account
        """
    }
    
    func findAndSetupContinuityCamera() {
        // Use the simple approach that was working
        refreshAvailableCameras()
        
        // Try to find the best available camera
        var selectedCamera: AVCaptureDevice?
        
        // First look for Charlie's iPhone specifically
        if let charlieCamera = availableCameras.first(where: { 
            $0.localizedName.contains("Charlie") || $0.localizedName.contains("15 Pro")
        }) {
            print("📱 Found Charlie's iPhone: \(charlieCamera.localizedName)")
            selectedCamera = charlieCamera
        }
        // Then try continuity camera type
        else if let continuityCamera = availableCameras.first(where: { $0.deviceType == .continuityCamera }) {
            print("📱 Found Continuity Camera: \(continuityCamera.localizedName)")
            selectedCamera = continuityCamera
        }
        // Then try external cameras
        else if let externalCamera = availableCameras.first(where: { $0.deviceType == .external }) {
            print("📱 Found external camera: \(externalCamera.localizedName)")
            selectedCamera = externalCamera
        }
        // Fallback to built-in camera
        else if let builtInCamera = availableCameras.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            print("💻 Using built-in camera: \(builtInCamera.localizedName)")
            selectedCamera = builtInCamera
        }
        
        if let camera = selectedCamera {
            selectedCameraDevice = camera
            setupCamera(with: camera)
        } else {
            print("❌ No camera found")
            showError(message: "No camera detected. Please connect your iPhone via Continuity Camera or ensure your Mac has a built-in camera.")
        }
    }
    
    private func setupCamera(with device: AVCaptureDevice) {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
                
                // Setup photo output
                let output = AVCapturePhotoOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    photoOutput = output
                }
                
                isCameraConnected = true
                print("✅ Camera connected: \(device.localizedName)")
                
            } else {
                throw PhotoBoothError.cameraNotFound
            }
        } catch {
            print("❌ Failed to setup camera: \(error.localizedDescription)")
            isCameraConnected = false
            showError(message: "Failed to setup camera: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
        
        if !isSessionRunning {
            session.startRunning()
            isSessionRunning = true
        }
    }
    
    // MARK: - Photo Capture and Processing
    func startCapture() {
        print("🎬 [DEBUG] Starting photo capture workflow")
        print("🎨 [DEBUG] Selected theme: \(selectedTheme?.name ?? "None")")
        print("🔍 [DEBUG] ViewModel object ID: \(ObjectIdentifier(self))")
        
        guard selectedTheme != nil else {
            print("❌ [DEBUG] No theme selected")
            showError(message: "Please select a theme first")
            return
        }
        
        // Cancel any existing countdown timer
        countdownTimer?.invalidate()
        
        print("✅ [DEBUG] Starting countdown timer...")
        
        // Start countdown with explicit animation
        withAnimation(.easeInOut(duration: 0.2)) {
            isCountingDown = true
            countdown = 3
        }
        
        print("🔍 [DEBUG] Countdown state set - isCountingDown: \(isCountingDown), countdown: \(countdown)")
        print("🖥️ [DEBUG] Countdown overlay should now be VISIBLE")
        print("📺 [DEBUG] Notifying projector to start countdown...")
        
        // Notify projector to start countdown
        NotificationCenter.default.post(
            name: .countdownStart,
            object: nil
        )
        
        // Play initial countdown sound
        AudioServicesPlaySystemSound(1057) // Tock sound
        
        // Start countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                print("⏰ [DEBUG] Countdown tick - current: \(self.countdown), isCountingDown: \(self.isCountingDown)")
                
                if self.countdown > 1 {
                    // Continue countdown
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.countdown -= 1
                    }
                    AudioServicesPlaySystemSound(1057) // Tock sound
                    print("⏰ [DEBUG] Countdown updated to: \(self.countdown)")
                    print("🖥️ [DEBUG] Overlay showing: \(self.countdown)")
                } else {
                    // Countdown finished - show camera icon
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.countdown = 0
                    }
                    print("📸 [DEBUG] Countdown finished, showing camera icon...")
                    print("🖥️ [DEBUG] Overlay showing: 📸")
                    
                    AudioServicesPlaySystemSound(1108) // Camera shutter sound
                    timer.invalidate()
                    self.countdownTimer = nil
                    
                    // Start photo capture
                    self.capturePhoto()
                    
                    // Keep countdown overlay visible briefly to show camera icon
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isCountingDown = false
                        }
                        print("🔍 [DEBUG] Countdown ended - isCountingDown: \(self.isCountingDown)")
                        print("🖥️ [DEBUG] Countdown overlay should now be HIDDEN")
                        print("✅ [DEBUG] Countdown sequence complete")
                    }
                }
            }
        }
    }
    
    private func capturePhoto() {
        print("📸 [DEBUG] Capturing photo...")
        
        guard let photoOutput = photoOutput else {
            print("❌ [DEBUG] Photo output not available")
            showError(message: "Camera not ready")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        
        print("📸 [DEBUG] Taking photo with settings...")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Image Processing
    func processImage(_ image: NSImage) async {
        print("🎨 [DEBUG] Starting image processing...")
        print("🎨 [DEBUG] Selected theme: \(selectedTheme?.name ?? "None")")
        print("🎨 [DEBUG] OpenAI configured: \(openAI != nil ? "YES" : "NO")")
        
        guard let theme = selectedTheme,
              openAI != nil else { 
            print("❌ [DEBUG] Missing theme or OpenAI service")
            return 
        }
        
        await MainActor.run {
            isProcessing = true
        }
        lastCapturedImage = image
        
        do {
            // Save original image
            let originalPath = try await saveOriginalImage(image)
            print("💾 Original photo saved to: \(originalPath.path)")
            
            // Notify projector to show original image immediately
            NotificationCenter.default.post(
                name: .photoCapture,
                object: nil,
                userInfo: [
                    "original": originalPath,
                    "theme": theme.name
                ]
            )
            
            // Generate themed image with retry logic
            print("🎨 Starting AI image generation...")
            
            // Notify projector that processing has started
            NotificationCenter.default.post(
                name: .processingStart,
                object: nil,
                userInfo: [
                    "theme": theme.name
                ]
            )
            
            let themedImage = try await generateThemedImage(from: image, theme: theme)
            lastThemedImage = themedImage
            
            // Notify projector that processing is complete
            NotificationCenter.default.post(
                name: .processingDone,
                object: nil,
                userInfo: [
                    "theme": theme.name
                ]
            )
            
            // Save themed image
            let themedPath = try await saveThemedImage(themedImage)
            print("💾 Themed photo saved to: \(themedPath.path)")
            
            // Show success message
            await MainActor.run {
                showError(message: "Photos saved to Pictures/booth folder!")
            }
            
            // Notify external display
            NotificationCenter.default.post(
                name: .newPhotoCapture,
                object: nil,
                userInfo: [
                    "original": originalPath,
                    "themed": themedPath
                ]
            )
            
            print("✅ Photo booth process completed successfully!")
            
            // Reset theme selection to force user to choose theme for next photo
            await MainActor.run {
                selectedTheme = nil
                print("🔄 Theme selection reset - user must choose theme for next photo")
            }
            
        } catch {
            print("❌ [DEBUG] Photo booth process failed: \(error.localizedDescription)")
            print("❌ [DEBUG] Error type: \(type(of: error))")
            
            // Show user-friendly error message
            let friendlyMessage = getFriendlyErrorMessage(for: error)
            await MainActor.run {
                showError(message: friendlyMessage)
                // Also reset theme on error
                selectedTheme = nil
            }
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    private func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage {
        guard openAI != nil else {
            print("❌ OpenAI service not configured")
            throw PhotoBoothError.serviceNotConfigured
        }
        
        print("🔧 DEBUG: Starting image generation with OpenAI")
        print("🔧 DEBUG: Theme selected: \(theme.name)")
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔧 DEBUG: Generating themed image (attempt \(attempt)/\(maxRetries))...")
                
                // Ensure image is landscape and properly sized for API consistency
                guard let landscapeImage = cropToLandscape(image) else {
                    print("❌ Failed to crop image to landscape")
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                print("📏 DEBUG: Image cropped to 3:2 aspect ratio for OpenAI API")
                
                // Convert processed NSImage to JPEG data for the API
                guard let tiffData = landscapeImage.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                print("📸 Using direct image editing with GPT-image-1...")
                
                // Create the theme-specific prompt
                let editPrompt = """
                Transform this photo into \(theme.name) style while preserving the exact same people, faces, poses, and composition from the original photo. \(theme.prompt)
                
                IMPORTANT: Keep all the people exactly as they appear in the original photo - same faces, same expressions, same positioning. Only change the art style, not the people or their appearance.
                """
                
                print("🔧 DEBUG: Edit prompt: \(editPrompt)")
                
                // Direct API call for image editing
                guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_KEY"] else {
                    throw PhotoBoothError.serviceNotConfigured
                }
                
                let url = URL(string: "https://api.openai.com/v1/images/edits")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                
                // Create multipart form data
                let boundary = UUID().uuidString
                request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                var body = Data()
                
                // Add model field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
                body.append("gpt-image-1\r\n".data(using: .utf8)!)
                
                // Add prompt field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(editPrompt)\r\n".data(using: .utf8)!)
                
                // Add size field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
                body.append("1536x1024\r\n".data(using: .utf8)!)
                
                // Add image field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(jpegData)
                body.append("\r\n".data(using: .utf8)!)
                
                // Close boundary
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                request.httpBody = body
                request.timeoutInterval = 120 // Increase timeout to 2 minutes
                
                print("🔧 DEBUG: Sending image edit request to OpenAI...")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                print("🔧 DEBUG: Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("❌ API Error: \(errorData)")
                    }
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                // Parse response
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]],
                      let firstItem = dataArray.first,
                      let b64Json = firstItem["b64_json"] as? String else {
                    print("❌ Failed to parse JSON response")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔧 DEBUG: Response was: \(responseString.prefix(200))...")
                    }
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                print("✅ Successfully parsed API response, got base64 image data")
                
                // Decode base64 image
                guard let imageData = Data(base64Encoded: b64Json),
                      let editedImage = NSImage(data: imageData) else {
                    print("❌ Failed to decode base64 image data")
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                print("✅ Successfully created edited image from API response")
                await MainActor.run {
                    logImageDimensions(editedImage, label: "Themed image from OpenAI")
                }
                return editedImage
                
            } catch {
                lastError = error
                print("❌ Image editing failed on attempt \(attempt)")
                print("🔧 DEBUG: Error details: \(error)")
                
                if attempt < maxRetries {
                    let delay = Double(1 << (attempt - 1))
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        print("❌ All \(maxRetries) attempts failed. Last error: \(lastError?.localizedDescription ?? "Unknown")")
        throw lastError ?? PhotoBoothError.imageGenerationFailed
    }
    
    // MARK: - File Management
    
    // MARK: - Image Processing Utilities
    private func logImageDimensions(_ image: NSImage, label: String) {
        print("📏 [DEBUG] \(label): \(image.size.width) x \(image.size.height)")
    }
    
    private func cropToLandscape(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let originalAspectRatio = originalWidth / originalHeight
        let targetAspectRatio: CGFloat = 1536.0 / 1024.0 // 3:2 = 1.5
        
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        
        if originalAspectRatio > targetAspectRatio {
            // Image is wider than target - crop width (use full height)
            cropHeight = originalHeight
            cropWidth = cropHeight * targetAspectRatio
        } else {
            // Image is taller than target - crop height (use full width)
            cropWidth = originalWidth
            cropHeight = cropWidth / targetAspectRatio
        }
        
        // Calculate crop origin to center the crop
        let cropX = (originalWidth - cropWidth) / 2
        let cropY = (originalHeight - cropHeight) / 2
        
        // Create crop rectangle
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Crop the image
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        // Create new NSImage from cropped image at original resolution
        let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: cropWidth, height: cropHeight))
        
        print("📏 Cropped to 3:2 aspect ratio: \(Int(cropWidth)) × \(Int(cropHeight)) (maintained original resolution)")
        return croppedImage
    }
    
    private func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage? {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        newImage.unlockFocus()
        return newImage
    }
    
    private func saveOriginalImage(_ image: NSImage) async throws -> URL {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let boothURL = picturesURL.appendingPathComponent("booth")
        
        try FileManager.default.createDirectory(at: boothURL, withIntermediateDirectories: true)
        
        let fileName = "original_\(Date().timeIntervalSince1970).jpg"
        let fileURL = boothURL.appendingPathComponent(fileName)
        
        // Crop the original image to 1536x1024 landscape for consistency with themed images
        guard let landscapeImage = cropToLandscape(image),
              let tiffData = landscapeImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw PhotoBoothError.imageSaveFailed
        }
        
        try jpegData.write(to: fileURL)
        print("💾 Original image cropped to 3:2 aspect ratio (maintaining original resolution)")
        return fileURL
    }
    
    private func saveThemedImage(_ image: NSImage) async throws -> URL {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let boothURL = picturesURL.appendingPathComponent("booth")
        
        let fileName = "themed_\(Date().timeIntervalSince1970).jpg"
        let fileURL = boothURL.appendingPathComponent(fileName)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw PhotoBoothError.imageSaveFailed
        }
        
        try jpegData.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Error Handling
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        // Notify projector to show error
        NotificationCenter.default.post(
            name: .showError,
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    private func getFriendlyErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection. Please check your network and try again."
            case .timedOut:
                return "Request timed out. The AI service might be busy. Try a simpler theme like Simpsons or SpongeBob."
            default:
                return "Network error occurred. Please check your connection and try again."
            }
        }
        
        if error.localizedDescription.contains("moderation") {
            return "This image couldn't be processed due to content policies. Please try a different theme or photo."
        }
        
        if error is PhotoBoothError {
            switch error as! PhotoBoothError {
            case .serviceNotConfigured:
                return "Service configuration error. Please check your API keys."
            case .imageGenerationFailed:
                return "We had trouble creating your AI photo. Please try again!"
            case .imageSaveFailed:
                return "Couldn't save your photo. Please check disk space and try again."
            case .cameraNotFound:
                return "Could not find the camera. Please ensure it's connected and try again."
            }
        } else {
            return "Something went wrong. Please try the photo booth again!"
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension PhotoBoothViewModel: @preconcurrency AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 [DEBUG] Photo capture completed")
        
        if let error = error {
            print("❌ [DEBUG] Photo capture error: \(error)")
            Task { @MainActor in
                showError(message: "Photo capture failed: \(error.localizedDescription)")
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = NSImage(data: data) else {
            print("❌ [DEBUG] Could not get image data from photo")
            Task { @MainActor in
                showError(message: "Failed to process captured photo")
            }
            return
        }
        
        print("✅ [DEBUG] Photo captured successfully, size: \(data.count) bytes")
        
        Task { @MainActor in
            logImageDimensions(image, label: "Captured image")
            await processImage(image)
        }
    }
}

// MARK: - Supporting Types
struct PhotoTheme: Identifiable {
    let id: Int
    let name: String
    let prompt: String
}

enum PhotoBoothError: Error {
    case serviceNotConfigured
    case imageGenerationFailed
    case imageSaveFailed
    case cameraNotFound
}

extension Notification.Name {
    static let newPhotoCapture = Notification.Name("newPhotoCapture")
}

// MARK: - Extensions
extension AVCaptureDevice.Position {
    var description: String {
        switch self {
        case .back:
            return "Back"
        case .front:
            return "Front"
        case .unspecified:
            return "Unspecified"
        @unknown default:
            return "Unknown"
        }
    }
} 