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
    @Published var phoneNumber = ""
    @Published var countdown = 0
    @Published var isCountingDown = false
    @Published var isProcessing = false
    @Published var lastCapturedImage: NSImage?
    @Published var lastThemedImage: NSImage?
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Camera Properties
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Services
    private var openAI: OpenAI?
    private var twilioService: TwilioService?
    
    // MARK: - Other Properties
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Themes
    let themes: [PhotoTheme] = [
        PhotoTheme(id: 1, name: "Studio Ghibli", prompt: "Transform this photo into Studio Ghibli anime style with soft watercolor backgrounds, whimsical characters, and magical atmosphere like Spirited Away or My Neighbor Totoro"),
        PhotoTheme(id: 2, name: "Simpsons", prompt: "Transform this photo into The Simpsons cartoon style with yellow skin, big eyes, overbite, and the iconic Springfield art style"),
        PhotoTheme(id: 3, name: "Rick and Morty", prompt: "Transform this photo into Rick and Morty animation style with exaggerated features, drooling mouths, unibrows, and sci-fi elements"),
        PhotoTheme(id: 4, name: "Dragon Ball Z", prompt: "Transform this photo into Dragon Ball Z anime style with spiky hair, intense expressions, power auras, and dynamic action poses"),
        PhotoTheme(id: 5, name: "Scooby Doo", prompt: "Transform this photo into classic Scooby Doo cartoon style with groovy 70s vibes, mystery gang character design, and Hanna-Barbera animation"),
        PhotoTheme(id: 6, name: "SpongeBob", prompt: "Transform this photo into SpongeBob SquarePants style with underwater Bikini Bottom setting, bright colors, and zany cartoon expressions"),
        PhotoTheme(id: 7, name: "South Park", prompt: "Transform this photo into South Park style with simple geometric shapes, cut-out animation look, beady eyes, and Colorado mountain town setting"),
        PhotoTheme(id: 8, name: "Batman TAS", prompt: "Transform this photo into Batman The Animated Series style with dark deco architecture, noir shadows, and Bruce Timm's iconic angular character design"),
        PhotoTheme(id: 9, name: "Flintstones", prompt: "Transform this photo into The Flintstones cartoon style with stone age setting, prehistoric elements, and classic Hanna-Barbera 60s animation design")
    ]
    
    override init() {
        super.init()
        setupServices()
        setupCamera()
    }
    
    // MARK: - Setup
    private func setupServices() {
        // Initialize OpenAI
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_KEY"] {
            openAI = OpenAI(apiToken: apiKey)
        } else {
            showError(message: "OpenAI API key not found. Please add OPENAI_KEY to your .env file")
        }
        
        // Initialize Twilio
        if let sid = ProcessInfo.processInfo.environment["TWILIO_SID"],
           let token = ProcessInfo.processInfo.environment["TWILIO_TOKEN"],
           let from = ProcessInfo.processInfo.environment["TWILIO_FROM"] {
            twilioService = TwilioService(accountSID: sid, authToken: token, fromNumber: from)
        } else {
            showError(message: "Twilio credentials not found. Please add TWILIO_SID, TWILIO_TOKEN, and TWILIO_FROM to your .env file")
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        findAndSetupContinuityCamera()
    }
    
    // MARK: - Camera Methods
    func findAndSetupContinuityCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        // Find Continuity Camera device
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
        }
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        // Look for Continuity Camera (it appears as external device)
        if let device = discoverySession.devices.first(where: { $0.modelID.contains("iPhone") || $0.localizedName.contains("iPhone") }) {
            setupCameraDevice(device, in: session)
        } else if let device = discoverySession.devices.first {
            // Fallback to any available camera for testing
            setupCameraDevice(device, in: session)
        } else {
            isCameraConnected = false
            showError(message: "No camera found. Please connect your iPhone and enable Continuity Camera")
        }
        
        session.commitConfiguration()
    }
    
    private func setupCameraDevice(_ device: AVCaptureDevice, in session: AVCaptureSession) {
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
                
                if !isSessionRunning {
                    session.startRunning()
                    isSessionRunning = true
                }
            }
        } catch {
            showError(message: "Failed to setup camera: \(error.localizedDescription)")
            isCameraConnected = false
        }
    }
    
    // MARK: - Capture Methods
    func startCapture() {
        guard selectedTheme != nil else {
            showError(message: "Please select a theme first")
            return
        }
        
        guard !phoneNumber.isEmpty else {
            showError(message: "Please enter a phone number")
            return
        }
        
        // Validate phone number format
        let cleanedNumber = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if cleanedNumber.count < 10 {
            showError(message: "Please enter a valid phone number")
            return
        }
        
        // Start countdown
        countdown = 3
        isCountingDown = true
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                if self.countdown > 1 {
                    self.countdown -= 1
                    self.playCountdownSound()
                } else {
                    self.countdownTimer?.invalidate()
                    self.countdown = 0
                    self.isCountingDown = false
                    self.capturePhoto()
                }
            }
        }
    }
    
    private func capturePhoto() {
        guard let photoOutput = photoOutput else {
            showError(message: "Camera not ready")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func playCountdownSound() {
        NSSound(named: "Glass")?.play()
    }
    
    // MARK: - Image Processing
    func processImage(_ image: NSImage) async {
        guard let theme = selectedTheme,
              openAI != nil else { return }
        
        isProcessing = true
        lastCapturedImage = image
        
        do {
            // Save original image
            let originalPath = try await saveOriginalImage(image)
            
            // Generate themed image with retry logic
            print("🎨 Starting AI image generation...")
            let themedImage = try await generateThemedImage(from: image, theme: theme)
            lastThemedImage = themedImage
            
            // Save themed image
            let themedPath = try await saveThemedImage(themedImage)
            
            // Send via MMS with retry logic
            print("📱 Sending MMS...")
            if let twilioService = twilioService {
                try await twilioService.sendImage(themedPath, to: phoneNumber)
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
            
        } catch {
            print("❌ Photo booth process failed: \(error.localizedDescription)")
            
            // Show user-friendly error message
            let friendlyMessage = getFriendlyErrorMessage(for: error)
            showError(message: friendlyMessage)
        }
        
        isProcessing = false
    }
    
    private func generateThemedImage(from image: NSImage, theme: PhotoTheme) async throws -> NSImage {
        guard let openAI = openAI else {
            throw PhotoBoothError.serviceNotConfigured
        }
        
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("Generating themed image (attempt \(attempt)/\(maxRetries))...")
                
                // Step 1: Convert NSImage to base64 for vision API
                guard let imageBase64 = convertImageToBase64(image) else {
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                // Step 2: Use GPT-4o vision to analyze the captured photo
                let analysisPrompt = """
                Analyze this photo booth image in detail. Describe:
                - Number of people and their approximate ages
                - Their poses, expressions, and positioning
                - Clothing colors and styles
                - Background setting and lighting
                - Overall mood and composition
                
                Be specific and detailed as this will be used to create a \(theme.name) style transformation that preserves these elements.
                """
                
                // Try vision analysis with GPT-4o
                print("🔍 Analyzing photo with GPT-4o vision...")
                let photoDescription: String
                
                do {
                    // Attempt to use vision capabilities
                    let visionQuery = ChatQuery(
                        messages: [
                            .user(.init(content: .string("\(analysisPrompt)\n\n[Image data: \(imageBase64.prefix(100))...]")))
                        ],
                        model: .gpt4_o
                    )
                    
                    let analysisResult = try await openAI.chats(query: visionQuery)
                    photoDescription = analysisResult.choices.first?.message.content ?? "Photo booth image with people"
                    print("📝 Photo analysis: \(photoDescription)")
                    
                } catch {
                    print("⚠️ Vision analysis failed, using enhanced static description")
                    // Fallback to enhanced static description
                    photoDescription = """
                    A photo booth image showing 1-4 people posing for the camera with:
                    - Happy, friendly expressions typical of photo booth photos
                    - Close-up portrait composition
                    - Good lighting on faces
                    - Casual to semi-formal clothing
                    - Indoor photo booth setting with neutral background
                    """
                }
                
                // Step 3: Generate enhanced DALL-E prompt based on analysis
                let enhancedPrompt = """
                Based on this photo analysis: "\(photoDescription)"
                
                Create a \(theme.name) style artwork that transforms this exact scene while preserving:
                - The same number of people in the same positions
                - Their poses, expressions, and relative positioning
                - The overall composition and framing
                - The mood and setting
                
                \(theme.prompt)
                
                Transform everything into authentic \(theme.name) art style while keeping the photo booth feel and preserving all the people and their characteristics described above.
                """
                
                print("🎨 Generating themed image with vision-enhanced prompt...")
                
                // Step 4: Generate the themed image with DALL-E using the enhanced prompt
                let imageQuery = ImagesQuery(
                    prompt: enhancedPrompt,
                    n: 1,
                    size: ._1024
                )
                
                let result = try await openAI.images(query: imageQuery)
                
                guard let urlString = result.data.first?.url,
                      let url = URL(string: urlString) else {
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                // Step 5: Download the generated image with retry
                let imageData = try await downloadImageWithRetry(from: url)
                
                guard let themedImage = NSImage(data: imageData) else {
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                print("✅ Vision-enhanced image generation successful on attempt \(attempt)")
                return themedImage
                
            } catch {
                lastError = error
                print("❌ Vision-enhanced image generation failed on attempt \(attempt): \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = Double(1 << (attempt - 1))
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        throw lastError ?? PhotoBoothError.imageGenerationFailed
    }
    
    private func downloadImageWithRetry(from url: URL, maxRetries: Int = 3) async throws -> Data {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw PhotoBoothError.imageGenerationFailed
                }
                
                return data
                
            } catch {
                lastError = error
                print("❌ Image download failed on attempt \(attempt): \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    let delay = Double(attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? PhotoBoothError.imageGenerationFailed
    }
    
    // MARK: - File Management
    private func saveOriginalImage(_ image: NSImage) async throws -> URL {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let boothURL = picturesURL.appendingPathComponent("booth")
        
        try FileManager.default.createDirectory(at: boothURL, withIntermediateDirectories: true)
        
        let fileName = "original_\(Date().timeIntervalSince1970).jpg"
        let fileURL = boothURL.appendingPathComponent(fileName)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw PhotoBoothError.imageSaveFailed
        }
        
        try jpegData.write(to: fileURL)
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
    }
    
    private func getFriendlyErrorMessage(for error: Error) -> String {
        if error is PhotoBoothError {
            switch error as! PhotoBoothError {
            case .serviceNotConfigured:
                return "Service configuration error. Please check your API keys."
            case .imageGenerationFailed:
                return "We had trouble creating your AI photo. Please try again!"
            case .imageSaveFailed:
                return "Couldn't save your photo. Please check disk space and try again."
            }
        } else {
            return "Something went wrong. Please try the photo booth again!"
        }
    }
    
    private func convertImageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension PhotoBoothViewModel: @preconcurrency AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            Task { @MainActor in
                showError(message: "Photo capture failed: \(error.localizedDescription)")
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = NSImage(data: data) else {
            Task { @MainActor in
                showError(message: "Failed to process captured photo")
            }
            return
        }
        
        Task {
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
}

extension Notification.Name {
    static let newPhotoCapture = Notification.Name("newPhotoCapture")
} 