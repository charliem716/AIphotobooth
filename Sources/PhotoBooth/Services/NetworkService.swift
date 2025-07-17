import Foundation
import os.log

// MARK: - URLSession Protocol

/// Protocol for URLSession to enable testing
public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession Extension

extension URLSession: URLSessionProtocol {
    // URLSession already implements data(for:) async throws -> (Data, URLResponse)
}

// MARK: - Network Types

/// HTTP Methods supported by the NetworkService
public enum HTTPMethod: String, CaseIterable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

/// Network request configuration
public struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Data?
    let timeout: TimeInterval
    
    public init(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timeout: TimeInterval = 30.0
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// Network response container
public struct NetworkResponse {
    let data: Data
    let response: HTTPURLResponse
    let statusCode: Int
    
    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
        self.statusCode = response.statusCode
    }
}

/// Network errors
public enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case noResponse
    case invalidResponse
    case statusCode(Int, Data?)
    case timeout
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case networkUnavailable
    case requestFailed(Error)
    case retryExhausted(lastError: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString):
            return "Invalid URL: \(urlString)"
        case .noResponse:
            return "No response received"
        case .invalidResponse:
            return "Invalid response format"
        case .statusCode(let code, _):
            return "HTTP Status Code: \(code)"
        case .timeout:
            return "Request timed out"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .retryExhausted(let lastError):
            return "Retry exhausted. Last error: \(lastError.localizedDescription)"
        }
    }
}

/// Retry configuration
public struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let retryableStatusCodes: Set<Int>
    
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.retryableStatusCodes = retryableStatusCodes
    }
    
    /// Default retry configuration
    public static let `default` = RetryConfiguration()
    
    /// No retry configuration
    public static let none = RetryConfiguration(maxRetries: 0)
}

// MARK: - NetworkService Protocol

/// Protocol defining network service operations
@MainActor
public protocol NetworkServiceProtocol {
    /// Perform a network request with retry logic
    func performRequest(_ request: NetworkRequest, retryConfig: RetryConfiguration) async throws -> NetworkResponse
    
    /// Perform a simple GET request
    func get(url: URL, headers: [String: String]?) async throws -> NetworkResponse
    
    /// Perform a POST request with JSON body
    func post(url: URL, body: Data?, headers: [String: String]?) async throws -> NetworkResponse
    
    /// Perform a PUT request with JSON body
    func put(url: URL, body: Data?, headers: [String: String]?) async throws -> NetworkResponse
    
    /// Perform a DELETE request
    func delete(url: URL, headers: [String: String]?) async throws -> NetworkResponse
    
    /// Download data from URL with progress tracking
    func download(from url: URL, headers: [String: String]?) async throws -> Data
    
    /// Upload data to URL
    func upload(data: Data, to url: URL, headers: [String: String]?) async throws -> NetworkResponse
}

// MARK: - NetworkService Implementation

/// Concrete implementation of NetworkService with modern Swift patterns
@MainActor
public final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let session: URLSessionProtocol
    private let logger = Logger(subsystem: "PhotoBooth", category: "NetworkService")
    private let defaultRetryConfig: RetryConfiguration
    
    // MARK: - Initialization
    
    public init(
        session: URLSessionProtocol = URLSession.shared,
        defaultRetryConfig: RetryConfiguration = .default
    ) {
        self.session = session
        self.defaultRetryConfig = defaultRetryConfig
        
        logger.info("NetworkService initialized with default retry config: \(defaultRetryConfig.maxRetries) retries")
    }
    
    // MARK: - NetworkServiceProtocol Implementation
    
    public func performRequest(_ request: NetworkRequest, retryConfig: RetryConfiguration = .default) async throws -> NetworkResponse {
        let urlRequest = try buildURLRequest(from: request)
        
        logger.debug("📡 Starting request: \(request.method.rawValue) \(request.url)")
        
        // Perform request with retry logic
        return try await performWithRetry(urlRequest: urlRequest, retryConfig: retryConfig)
    }
    
    public func get(url: URL, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .GET, headers: headers)
        return try await performRequest(request, retryConfig: defaultRetryConfig)
    }
    
    public func post(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .POST, headers: headers, body: body)
        return try await performRequest(request, retryConfig: defaultRetryConfig)
    }
    
    public func put(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .PUT, headers: headers, body: body)
        return try await performRequest(request, retryConfig: defaultRetryConfig)
    }
    
    public func delete(url: URL, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .DELETE, headers: headers)
        return try await performRequest(request, retryConfig: defaultRetryConfig)
    }
    
    public func download(from url: URL, headers: [String: String]? = nil) async throws -> Data {
        let request = NetworkRequest(url: url, method: .GET, headers: headers)
        let response = try await performRequest(request, retryConfig: defaultRetryConfig)
        return response.data
    }
    
    public func upload(data: Data, to url: URL, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .POST, headers: headers, body: data)
        return try await performRequest(request, retryConfig: defaultRetryConfig)
    }
    
    // MARK: - Private Methods
    
    private func buildURLRequest(from request: NetworkRequest) throws -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // Add headers
        if let headers = request.headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add body
        if let body = request.body {
            urlRequest.httpBody = body
            
            // Set content type if not already set
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        return urlRequest
    }
    
    private func performWithRetry(urlRequest: URLRequest, retryConfig: RetryConfiguration) async throws -> NetworkResponse {
        var lastError: Error?
        
        for attempt in 0...retryConfig.maxRetries {
            do {
                let startTime = Date()
                let (data, response) = try await session.data(for: urlRequest)
                let duration = Date().timeIntervalSince(startTime)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                let networkResponse = NetworkResponse(data: data, response: httpResponse)
                
                // Check if status code indicates success
                if (200...299).contains(httpResponse.statusCode) {
                    logger.info("✅ Request successful: \(httpResponse.statusCode) in \(String(format: "%.3f", duration))s")
                    return networkResponse
                }
                
                // Check if we should retry based on status code
                if retryConfig.retryableStatusCodes.contains(httpResponse.statusCode) && attempt < retryConfig.maxRetries {
                    logger.warning("⚠️ Retryable status code \(httpResponse.statusCode), attempt \(attempt + 1)/\(retryConfig.maxRetries + 1)")
                    lastError = NetworkError.statusCode(httpResponse.statusCode, data)
                    await delayForRetry(attempt: attempt, config: retryConfig)
                    continue
                }
                
                // Non-retryable status code
                logger.error("❌ Non-retryable status code: \(httpResponse.statusCode)")
                throw NetworkError.statusCode(httpResponse.statusCode, data)
                
            } catch is CancellationError {
                logger.info("⏹️ Request cancelled")
                throw CancellationError()
            } catch {
                logger.error("❌ Request failed: \(error.localizedDescription)")
                lastError = error
                
                // Check if we should retry
                if attempt < retryConfig.maxRetries && isRetryableError(error) {
                    logger.warning("🔄 Retrying request, attempt \(attempt + 1)/\(retryConfig.maxRetries + 1)")
                    await delayForRetry(attempt: attempt, config: retryConfig)
                    continue
                }
                
                // Non-retryable error or max retries exceeded
                break
            }
        }
        
        // If we get here, we've exhausted retries
        let finalError = lastError ?? NetworkError.requestFailed(NSError(domain: "Unknown", code: -1))
        logger.error("💥 Request failed after \(retryConfig.maxRetries + 1) attempts")
        throw NetworkError.retryExhausted(lastError: finalError)
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors that are worth retrying
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .dnsLookupFailed, .cannotFindHost, .cannotConnectToHost,
                 .resourceUnavailable, .badServerResponse:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func delayForRetry(attempt: Int, config: RetryConfiguration) async {
        let delay = min(
            config.baseDelay * pow(config.backoffMultiplier, Double(attempt)),
            config.maxDelay
        )
        
        logger.debug("⏱️ Waiting \(String(format: "%.3f", delay))s before retry")
        
        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            // If sleep is cancelled, we should respect that
            logger.debug("⏹️ Retry delay cancelled")
        }
    }
}

// MARK: - Convenience Extensions

extension NetworkService {
    /// Perform a JSON request with automatic encoding/decoding
    public func performJSONRequest<T: Codable>(
        _ request: NetworkRequest,
        responseType: T.Type,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        let response = try await performRequest(request, retryConfig: retryConfig)
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: response.data)
        } catch {
            logger.error("❌ JSON decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingError(error)
        }
    }
    
    /// Create a JSON POST request with automatic encoding
    public func postJSON<T: Codable>(
        url: URL,
        body: T,
        headers: [String: String]? = nil
    ) async throws -> NetworkResponse {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(body)
            
            var jsonHeaders = headers ?? [:]
            jsonHeaders["Content-Type"] = "application/json"
            
            return try await post(url: url, body: jsonData, headers: jsonHeaders)
        } catch {
            logger.error("❌ JSON encoding failed: \(error.localizedDescription)")
            throw NetworkError.encodingError(error)
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension NetworkService {
    /// Create a mock network service for testing
    public static func mock(session: URLSessionProtocol) -> NetworkService {
        return NetworkService(session: session, defaultRetryConfig: .none)
    }
}
#endif 