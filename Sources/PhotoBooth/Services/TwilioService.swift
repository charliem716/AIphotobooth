import Foundation
import Network

class TwilioService {
    private let accountSID: String
    private let authToken: String
    private let fromNumber: String
    
    init(accountSID: String, authToken: String, fromNumber: String) {
        self.accountSID = accountSID
        self.authToken = authToken
        self.fromNumber = fromNumber
    }
    
    func sendImage(_ imageURL: URL, to phoneNumber: String) async throws {
        let cleanedNumber = formatPhoneNumber(phoneNumber)
        
        do {
            // Try to upload image with retries
            let publicImageURL = try await uploadImageWithRetry(imageURL)
            
            // Send MMS with the actual image
            try await sendMMS(to: cleanedNumber, imageURL: publicImageURL)
            
        } catch {
            print("❌ Failed to upload image after retries: \(error.localizedDescription)")
            
            // Send friendly error message instead of fake image
            try await sendErrorMessage(to: cleanedNumber)
        }
    }
    
    private func uploadImageWithRetry(_ localImageURL: URL, maxRetries: Int = 3) async throws -> String {
        guard let imageData = try? Data(contentsOf: localImageURL) else {
            throw TwilioError.imageLoadFailed
        }
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("Uploading image (attempt \(attempt)/\(maxRetries))...")
                
                let publicURL = try await uploadToImageHosting(imageData)
                print("✅ Image upload successful on attempt \(attempt)")
                return publicURL
                
            } catch {
                lastError = error
                print("❌ Image upload failed on attempt \(attempt): \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Exponential backoff: 2s, 4s, 8s
                    let delay = Double(2 << (attempt - 1))
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        throw lastError ?? TwilioError.imageUploadFailed
    }
    
    private func uploadToImageHosting(_ imageData: Data) async throws -> String {
        // Using imgur API as it's reliable for testing
        let uploadURL = URL(string: "https://api.imgur.com/3/image")!
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Client-ID 546c25a59c58ad7", forHTTPHeaderField: "Authorization") // Public test client ID
        request.timeoutInterval = 30 // 30 second timeout
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwilioError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = String(data: data, encoding: .utf8) {
                print("Image upload error response: \(errorData)")
            }
            throw TwilioError.httpError(httpResponse.statusCode)
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let link = dataDict["link"] as? String else {
            throw TwilioError.imageUploadFailed
        }
        
        return link
    }
    
    private func sendMMS(to phoneNumber: String, imageURL: String) async throws {
        let urlString = "https://api.twilio.com/2010-04-01/Accounts/\(accountSID)/Messages.json"
        guard let url = URL(string: urlString) else {
            throw TwilioError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        // Basic authentication
        let credentials = "\(accountSID):\(authToken)"
        guard let credentialData = credentials.data(using: .utf8) else {
            throw TwilioError.authenticationFailed
        }
        let base64Credentials = credentialData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // MMS parameters - include MediaUrl for image attachment
        let message = "Your AI-themed photo is ready! 🎨✨"
        
        let parameters = [
            "From": fromNumber,
            "To": phoneNumber,
            "Body": message,
            "MediaUrl": imageURL
        ]
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // URL encode parameters
        let parameterString = parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        
        request.httpBody = parameterString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwilioError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            if let errorData = String(data: data, encoding: .utf8) {
                print("Twilio API Error Response: \(errorData)")
                throw TwilioError.apiError(errorData)
            }
            throw TwilioError.httpError(httpResponse.statusCode)
        }
        
        // Success! Log the response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("✅ MMS sent successfully: \(responseString)")
        }
    }
    
    private func sendErrorMessage(to phoneNumber: String) async throws {
        let urlString = "https://api.twilio.com/2010-04-01/Accounts/\(accountSID)/Messages.json"
        guard let url = URL(string: urlString) else {
            throw TwilioError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        // Basic authentication
        let credentials = "\(accountSID):\(authToken)"
        guard let credentialData = credentials.data(using: .utf8) else {
            throw TwilioError.authenticationFailed
        }
        let base64Credentials = credentialData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Friendly error message
        let message = """
        Oops! We had trouble processing your AI photo. 😅 
        
        Please try the photo booth again - sometimes these things happen with technology! 
        
        Thanks for your patience! 🎨✨
        """
        
        let parameters = [
            "From": fromNumber,
            "To": phoneNumber,
            "Body": message
        ]
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // URL encode parameters
        let parameterString = parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        
        request.httpBody = parameterString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TwilioError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            if let errorData = String(data: data, encoding: .utf8) {
                print("Twilio SMS Error Response: \(errorData)")
                throw TwilioError.apiError(errorData)
            }
            throw TwilioError.httpError(httpResponse.statusCode)
        }
        
        print("📱 Friendly error message sent to user")
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        var cleaned = number.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        // Add country code if not present
        if !cleaned.hasPrefix("+") {
            // Assume US number if no country code
            if cleaned.hasPrefix("1") {
                cleaned = "+\(cleaned)"
            } else {
                cleaned = "+1\(cleaned)"
            }
        }
        
        return cleaned
    }
}

enum TwilioError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case imageLoadFailed
    case imageUploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Twilio API URL"
        case .authenticationFailed:
            return "Failed to authenticate with Twilio"
        case .invalidResponse:
            return "Invalid response from Twilio"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .imageLoadFailed:
            return "Failed to load image file"
        case .imageUploadFailed:
            return "Failed to upload image to hosting service"
        }
    }
} 