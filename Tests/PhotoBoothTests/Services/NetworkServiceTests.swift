import XCTest
import Foundation
@testable import PhotoBooth

/// Unit tests for NetworkService
@MainActor
final class NetworkServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var networkService: NetworkService!
    private var mockSession: MockURLSession!
    
    // MARK: - Test Lifecycle
    
    override func setUp() async throws {
        continueAfterFailure = false
        mockSession = MockURLSession()
        networkService = NetworkService(session: mockSession, defaultRetryConfig: .none)
    }
    
    override func tearDown() async throws {
        networkService = nil
        mockSession = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // GIVEN: A network service
        let service = NetworkService()
        
        // THEN: It should be initialized
        XCTAssertNotNil(service)
    }
    
    func testInitializationWithCustomSession() {
        // GIVEN: A custom session
        let customSession = MockURLSession()
        
        // WHEN: Creating a network service with custom session
        let service = NetworkService(session: customSession)
        
        // THEN: It should be initialized
        XCTAssertNotNil(service)
    }
    
    // MARK: - Basic HTTP Method Tests
    
    func testGETRequest() async throws {
        // GIVEN: A mock successful response
        let testData = "Test response".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = testData
        mockSession.mockResponse = response
        
        // WHEN: Making a GET request
        let result = try await networkService.get(url: URL(string: "https://test.com")!)
        
        // THEN: Should return successful response
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.data, testData)
    }
    
    func testPOSTRequest() async throws {
        // GIVEN: A mock successful response
        let testData = "Test response".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = testData
        mockSession.mockResponse = response
        
        let postData = "Test body".data(using: .utf8)!
        
        // WHEN: Making a POST request
        let result = try await networkService.post(url: URL(string: "https://test.com")!, body: postData)
        
        // THEN: Should return successful response
        XCTAssertEqual(result.statusCode, 201)
        XCTAssertEqual(result.data, testData)
    }
    
    func testPUTRequest() async throws {
        // GIVEN: A mock successful response
        let testData = "Test response".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = testData
        mockSession.mockResponse = response
        
        let putData = "Test body".data(using: .utf8)!
        
        // WHEN: Making a PUT request
        let result = try await networkService.put(url: URL(string: "https://test.com")!, body: putData)
        
        // THEN: Should return successful response
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.data, testData)
    }
    
    func testDELETERequest() async throws {
        // GIVEN: A mock successful response
        let testData = "Test response".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = testData
        mockSession.mockResponse = response
        
        // WHEN: Making a DELETE request
        let result = try await networkService.delete(url: URL(string: "https://test.com")!)
        
        // THEN: Should return successful response
        XCTAssertEqual(result.statusCode, 204)
        XCTAssertEqual(result.data, testData)
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkError() async throws {
        // GIVEN: A NetworkService with retry configuration
        let retryNetworkService = NetworkService(session: mockSession, defaultRetryConfig: .default)
        
        // GIVEN: A network error
        mockSession.mockError = URLError(.notConnectedToInternet)
        
        // WHEN: Making a request
        // THEN: Should throw network error
        do {
            _ = try await retryNetworkService.get(url: URL(string: "https://test.com")!)
            XCTFail("Expected error to be thrown")
        } catch let error as NetworkError {
            if case .retryExhausted = error {
                // Expected - retry was exhausted
            } else {
                XCTFail("Expected retryExhausted error, got: \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got: \(error)")
        }
    }
    
    func testHTTPErrorStatus() async throws {
        // GIVEN: An HTTP error response
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = Data()
        mockSession.mockResponse = response
        
        // WHEN: Making a request
        // THEN: Should throw status code error (404 is not retryable, so it should be immediate)
        do {
            _ = try await networkService.get(url: URL(string: "https://test.com")!)
            XCTFail("Expected error to be thrown")
        } catch let error as NetworkError {
            if case .statusCode(let code, _) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Expected statusCode error, got: \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got: \(error)")
        }
    }
    
    func testInvalidResponse() async throws {
        // GIVEN: An invalid response (not HTTPURLResponse)
        mockSession.mockData = Data()
        mockSession.mockResponse = URLResponse()
        
        // WHEN: Making a request
        // THEN: Should throw invalid response error
        do {
            _ = try await networkService.get(url: URL(string: "https://test.com")!)
            XCTFail("Expected error to be thrown")
        } catch let error as NetworkError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected invalidResponse error, got: \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got: \(error)")
        }
    }
    
    // MARK: - Network Error Scenario Tests
    
    func testNetworkTimeoutError() async {
        // Given - Network timeout scenario
        mockSession.reset()
        mockSession.configureForError(URLError(.timedOut))
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/timeout")!,
            method: .GET,
            headers: ["Content-Type": "application/json"],
            body: nil
        )
        
        // When - Attempt request with timeout
        do {
            _ = try await networkService.performRequest(request)
            XCTFail("Should throw timeout error")
        } catch let error as NetworkError {
            // Then - Should handle timeout appropriately
            XCTAssertEqual(error.localizedDescription, "Request timed out", "Should handle timeout error")
        } catch {
            XCTFail("Should throw NetworkError: \(error)")
        }
    }
    
    func testNetworkConnectionError() async {
        // Given - Network connection error
        mockSession.reset()
        mockSession.configureForError(URLError(.notConnectedToInternet))
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/offline")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Attempt request without connection
        do {
            _ = try await networkService.performRequest(request)
            XCTFail("Should throw connection error")
        } catch let error as NetworkError {
            // Then - Should handle connection error appropriately
            XCTAssertTrue(error.localizedDescription.contains("connection"), "Should handle connection error")
        } catch {
            XCTFail("Should throw NetworkError: \(error)")
        }
    }
    
    func testHTTPStatusCodeErrors() async {
        // Given - Various HTTP status code errors
        let errorCodes = [400, 401, 403, 404, 429, 500, 502, 503]
        
        for statusCode in errorCodes {
            mockSession.reset()
            mockSession.configureForHTTPStatusCode(statusCode)
            
            let request = NetworkRequest(
                url: URL(string: "https://api.example.com/error/\(statusCode)")!,
                method: .GET,
                headers: nil,
                body: nil
            )
            
            // When - Attempt request with error status
            do {
                _ = try await networkService.performRequest(request)
                XCTFail("Should throw error for status code \(statusCode)")
            } catch let error as NetworkError {
                // Then - Should handle HTTP error appropriately
                XCTAssertTrue(error.localizedDescription.contains("\(statusCode)"), "Should handle HTTP \(statusCode) error")
            } catch {
                XCTFail("Should throw NetworkError for status \(statusCode): \(error)")
            }
        }
    }
    
    func testRateLimitHandling() async {
        // Given - Rate limit response (429)
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(429)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/rate-limited")!,
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: Data()
        )
        
        // When - Attempt request with rate limit
        do {
            _ = try await networkService.performRequest(request)
            XCTFail("Should throw rate limit error")
        } catch let error as NetworkError {
            // Then - Should handle rate limit appropriately
            XCTAssertTrue(error.localizedDescription.contains("429"), "Should handle rate limit error")
        } catch {
            XCTFail("Should throw NetworkError: \(error)")
        }
    }
    
    func testServerErrorHandling() async {
        // Given - Server error response (500)
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(500)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/server-error")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Attempt request with server error
        do {
            _ = try await networkService.performRequest(request)
            XCTFail("Should throw server error")
        } catch let error as NetworkError {
            // Then - Should handle server error appropriately
            XCTAssertTrue(error.localizedDescription.contains("500"), "Should handle server error")
        } catch {
            XCTFail("Should throw NetworkError: \(error)")
        }
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryConfigurationNone() async {
        // Given - No retry configuration
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(500)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/no-retry")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Attempt request with no retry
        do {
            _ = try await networkService.performRequest(request, retryConfig: .none)
            XCTFail("Should throw error without retry")
        } catch {
            // Then - Should fail immediately
            XCTAssertEqual(mockSession.requestCount, 1, "Should make only one request")
        }
    }
    
    func testRetryConfigurationDefault() async {
        // Given - Default retry configuration
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(500)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/default-retry")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Attempt request with default retry
        do {
            _ = try await networkService.performRequest(request, retryConfig: .default)
            XCTFail("Should throw error after retries")
        } catch {
            // Then - Should retry according to default configuration
            XCTAssertGreaterThan(mockSession.requestCount, 1, "Should make multiple requests")
        }
    }
    
    func testRetryConfigurationCustom() async {
        // Given - Custom retry configuration
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(500)
        
        let customRetryConfig = RetryConfiguration(
            maxRetries: 2,
            baseDelay: 0.1,
            maxDelay: 1.0,
            backoffMultiplier: 2.0
        )
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/custom-retry")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Attempt request with custom retry
        do {
            _ = try await networkService.performRequest(request, retryConfig: customRetryConfig)
            XCTFail("Should throw error after custom retries")
        } catch {
            // Then - Should retry according to custom configuration
            XCTAssertLessThanOrEqual(mockSession.requestCount, 3, "Should make at most 3 requests (1 + 2 retries)")
        }
    }
    
    func testRetrySuccessAfterFailure() async {
        // Given - Failure followed by success
        mockSession.reset()
        mockSession.configureForSuccessAfterFailures(failureCount: 2)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/retry-success")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Attempt request with retry
        do {
            let response = try await networkService.performRequest(request, retryConfig: .default)
            
            // Then - Should succeed after retries
            XCTAssertNotNil(response, "Should succeed after retries")
            XCTAssertEqual(mockSession.requestCount, 3, "Should make 3 requests (1 + 2 retries)")
        } catch {
            XCTFail("Should succeed after retries: \(error)")
        }
    }
    
    // MARK: - JSON Convenience Methods Tests
    
    func testJSONRequest() async throws {
        // GIVEN: A successful JSON response
        let responseData = """
        {"name": "Test", "value": 42}
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = responseData
        mockSession.mockResponse = response
        
        // WHEN: Making a JSON request
        let request = NetworkRequest(url: URL(string: "https://test.com")!)
        let result: TestModel = try await networkService.performJSONRequest(
            request,
            responseType: TestModel.self
        )
        
        // THEN: Should decode JSON successfully
        XCTAssertEqual(result.name, "Test")
        XCTAssertEqual(result.value, 42)
    }
    
    func testJSONRequestWithDecodingError() async throws {
        // GIVEN: Invalid JSON response
        let responseData = "Invalid JSON".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = responseData
        mockSession.mockResponse = response
        
        // WHEN: Making a JSON request
        // THEN: Should throw decoding error
        do {
            let request = NetworkRequest(url: URL(string: "https://test.com")!)
            let _: TestModel = try await networkService.performJSONRequest(
                request,
                responseType: TestModel.self
            )
            XCTFail("Expected error to be thrown")
        } catch let error as NetworkError {
            if case .decodingError = error {
                // Expected
            } else {
                XCTFail("Expected decodingError, got: \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got: \(error)")
        }
    }
    
    func testPostJSON() async throws {
        // GIVEN: A successful response
        let responseData = "Success".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )!
        mockSession.mockData = responseData
        mockSession.mockResponse = response
        
        // WHEN: Making a POST JSON request
        let testModel = TestModel(name: "Test", value: 42)
        let result = try await networkService.postJSON(
            url: URL(string: "https://test.com")!,
            body: testModel
        )
        
        // THEN: Should succeed
        XCTAssertEqual(result.statusCode, 201)
        XCTAssertEqual(result.data, responseData)
    }
    
    // MARK: - OpenAI API Integration Tests
    
    func testOpenAIImageGenerationRequest() async {
        // Given - OpenAI image generation request
        mockSession.reset()
        mockSession.configureForSuccess(with: createMockImageGenerationResponse())
        
        let imageData = createTestImageData()
        let request = NetworkRequest(
            url: URL(string: "https://api.openai.com/v1/images/generations")!,
            method: .POST,
            headers: [
                "Authorization": "Bearer test-key",
                "Content-Type": "application/json"
            ],
            body: imageData
        )
        
        // When - Perform OpenAI request
        do {
            let response = try await networkService.performRequest(request)
            
            // Then - Should handle OpenAI response
            XCTAssertNotNil(response, "Should receive OpenAI response")
            XCTAssertEqual(mockSession.requestCount, 1, "Should make one request")
        } catch {
            XCTFail("OpenAI request should succeed: \(error)")
        }
    }
    
    func testOpenAIRateLimitWithRetry() async {
        // Given - OpenAI rate limit with retry
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(429)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.openai.com/v1/images/generations")!,
            method: .POST,
            headers: [
                "Authorization": "Bearer test-key",
                "Content-Type": "application/json"
            ],
            body: createTestImageData()
        )
        
        // When - Attempt OpenAI request with rate limit
        do {
            _ = try await networkService.performRequest(request, retryConfig: .default)
            XCTFail("Should throw rate limit error")
        } catch let error as NetworkError {
            // Then - Should handle OpenAI rate limit
            XCTAssertTrue(error.localizedDescription.contains("429"), "Should handle OpenAI rate limit")
            XCTAssertGreaterThan(mockSession.requestCount, 1, "Should retry OpenAI request")
        } catch {
            XCTFail("Should throw NetworkError: \(error)")
        }
    }
    
    func testOpenAIAuthenticationError() async {
        // Given - OpenAI authentication error (401)
        mockSession.reset()
        mockSession.configureForHTTPStatusCode(401)
        
        let request = NetworkRequest(
            url: URL(string: "https://api.openai.com/v1/images/generations")!,
            method: .POST,
            headers: [
                "Authorization": "Bearer invalid-key",
                "Content-Type": "application/json"
            ],
            body: createTestImageData()
        )
        
        // When - Attempt OpenAI request with invalid auth
        do {
            _ = try await networkService.performRequest(request)
            XCTFail("Should throw authentication error")
        } catch let error as NetworkError {
            // Then - Should handle OpenAI authentication error
            XCTAssertTrue(error.localizedDescription.contains("401"), "Should handle authentication error")
        } catch {
            XCTFail("Should throw NetworkError: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testNetworkRequestPerformance() async {
        // Given - Performance test setup
        mockSession.reset()
        mockSession.configureForSuccess()
        mockSession.responseDelay = 0.01 // Fast response for testing
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/performance")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Perform multiple requests and measure performance
        let iterations = 10
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            do {
                _ = try await networkService.performRequest(request)
            } catch {
                XCTFail("Performance test request \(i) should succeed: \(error)")
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTime = timeElapsed / Double(iterations)
        
        // Then - Should complete within reasonable time
        XCTAssertLessThan(averageTime, 0.5, "Average request time should be under 0.5 seconds")
        XCTAssertEqual(mockSession.requestCount, iterations, "Should make all requests")
        
        // Log performance for debugging
        print("🔍 Performance: \(averageTime) seconds average per network request")
    }
    
    func testConcurrentNetworkRequests() async {
        // Given - Concurrent request test
        mockSession.reset()
        mockSession.configureForSuccess()
        mockSession.responseDelay = 0.1
        
        let requestCount = 5
        let requests = (0..<requestCount).map { i in
            NetworkRequest(
                url: URL(string: "https://api.example.com/concurrent/\(i)")!,
                method: .GET,
                headers: nil,
                body: nil
            )
        }
        
        // When - Perform concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask {
                    do {
                        _ = try await self.networkService.performRequest(request)
                    } catch {
                        XCTFail("Concurrent request should succeed: \(error)")
                    }
                }
            }
            await group.waitForAll()
        }
        
        // Then - Should handle concurrent requests
        XCTAssertEqual(mockSession.requestCount, requestCount, "Should handle all concurrent requests")
    }
    
    // MARK: - Network Configuration Tests
    
    func testCustomTimeoutConfiguration() async {
        // Given - Custom timeout configuration
        let customSession = MockURLSession()
        customSession.configureForTimeout(2.0)
        
        let customNetworkService = NetworkService(
            session: customSession,
            defaultRetryConfig: .none
        )
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/custom-timeout")!,
            method: .GET,
            headers: nil,
            body: nil
        )
        
        // When - Perform request with custom timeout
        do {
            _ = try await customNetworkService.performRequest(request)
            XCTFail("Should timeout with custom configuration")
        } catch {
            // Then - Should timeout according to custom configuration
            XCTAssertTrue(error.localizedDescription.contains("timed out"), "Should timeout with custom configuration")
        }
    }
    
    func testHTTPHeaderHandling() async {
        // Given - Request with custom headers
        mockSession.reset()
        mockSession.configureForSuccess()
        
        let customHeaders = [
            "Authorization": "Bearer test-token",
            "Content-Type": "application/json",
            "User-Agent": "PhotoBooth/1.0",
            "Accept": "application/json"
        ]
        
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/headers")!,
            method: .POST,
            headers: customHeaders,
            body: Data()
        )
        
        // When - Perform request with custom headers
        do {
            let response = try await networkService.performRequest(request)
            
            // Then - Should handle custom headers
            XCTAssertNotNil(response, "Should handle custom headers")
            XCTAssertEqual(mockSession.requestCount, 1, "Should make request with headers")
        } catch {
            XCTFail("Request with custom headers should succeed: \(error)")
        }
    }
    
    // MARK: - Request Body Tests
    
    func testJSONRequestBody() async {
        // Given - JSON request body
        mockSession.reset()
        mockSession.configureForSuccess()
        
        let jsonData = try! JSONEncoder().encode(["prompt": "test prompt", "size": "1024x1024"])
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/json")!,
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: jsonData
        )
        
        // When - Perform request with JSON body
        do {
            let response = try await networkService.performRequest(request)
            
            // Then - Should handle JSON body
            XCTAssertNotNil(response, "Should handle JSON body")
            XCTAssertEqual(mockSession.requestCount, 1, "Should make request with JSON body")
        } catch {
            XCTFail("Request with JSON body should succeed: \(error)")
        }
    }
    
    func testImageDataRequestBody() async {
        // Given - Image data request body
        mockSession.reset()
        mockSession.configureForSuccess()
        
        let imageData = createTestImageData()
        let request = NetworkRequest(
            url: URL(string: "https://api.example.com/image")!,
            method: .POST,
            headers: ["Content-Type": "image/jpeg"],
            body: imageData
        )
        
        // When - Perform request with image data
        do {
            let response = try await networkService.performRequest(request)
            
            // Then - Should handle image data
            XCTAssertNotNil(response, "Should handle image data")
            XCTAssertEqual(mockSession.requestCount, 1, "Should make request with image data")
        } catch {
            XCTFail("Request with image data should succeed: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testNetworkServiceIntegration() async {
        // Given - Complete network service integration test
        mockSession.reset()
        mockSession.configureForSuccess()
        
        // When - Test complete network workflow
        let requests = [
            NetworkRequest(url: URL(string: "https://api.example.com/test1")!, method: .GET, headers: nil, body: nil),
            NetworkRequest(url: URL(string: "https://api.example.com/test2")!, method: .POST, headers: ["Content-Type": "application/json"], body: Data()),
            NetworkRequest(url: URL(string: "https://api.example.com/test3")!, method: .PUT, headers: nil, body: createTestImageData())
        ]
        
        for (index, request) in requests.enumerated() {
            do {
                let response = try await networkService.performRequest(request)
                XCTAssertNotNil(response, "Integration request \(index) should succeed")
            } catch {
                XCTFail("Integration request \(index) should succeed: \(error)")
            }
        }
        
        // Then - Should handle all integration requests
        XCTAssertEqual(mockSession.requestCount, requests.count, "Should handle all integration requests")
    }
    
    // MARK: - Helper Methods
    
    private func createMockImageGenerationResponse() -> Data {
        let response = [
            "data": [
                [
                    "url": "https://example.com/generated-image.jpg",
                    "b64_json": "base64-encoded-image-data"
                ]
            ]
        ]
        return try! JSONEncoder().encode(response)
    }
    
    private func createTestImageData() -> Data {
        // Create minimal test image data
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        return imageData
    }
}

// MARK: - Mock Classes

private class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var responses: [Result<(Data, URLResponse), Error>] = []
    private var responseIndex = 0
    var requestCount: Int = 0
    var responseDelay: TimeInterval = 0.0
    
    func reset() {
        requestCount = 0
        responseIndex = 0
        responses = []
        mockData = nil
        mockResponse = nil
        mockError = nil
    }
    
    func configureForError(_ error: Error) {
        mockError = error
        mockData = nil
        mockResponse = nil
    }
    
    func configureForHTTPStatusCode(_ statusCode: Int) {
        mockError = nil
        mockData = nil
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
    
    func configureForSuccess(with data: Data? = nil) {
        mockError = nil
        mockData = data ?? "Success".data(using: .utf8)!
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }
    
    func configureForSuccessAfterFailures(failureCount: Int) {
        mockError = nil
        mockData = "Success".data(using: .utf8)!
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://test.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        for _ in 0..<failureCount {
            responses.append(.failure(URLError(.timedOut)))
        }
        responses.append(.success((mockData!, mockResponse!)))
    }
    
    func configureForTimeout(_ delay: TimeInterval) {
        mockError = URLError(.timedOut)
        mockData = nil
        mockResponse = nil
        responseDelay = delay
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        // Use responses array if available
        if responseIndex < responses.count {
            let result = responses[responseIndex]
            responseIndex += 1
            switch result {
            case .success(let (data, response)):
                return (data, response)
            case .failure(let error):
                throw error
            }
        }
        
        // Use single mock response
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? URLResponse()
        return (data, response)
    }
}

// MARK: - Test Models

private struct TestModel: Codable {
    let name: String
    let value: Int
} 