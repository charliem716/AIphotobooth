import Foundation
@testable import PhotoBooth

/// Mock implementation of NetworkService for testing
@MainActor
final class MockNetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    var shouldSucceed = true
    var mockResponse: NetworkResponse?
    var mockError: NetworkError?
    var requestHistory: [NetworkRequest] = []
    var responseDelay: TimeInterval = 0.0
    
    // MARK: - NetworkServiceProtocol Implementation
    
    func performRequest(_ request: NetworkRequest, retryConfig: RetryConfiguration = .default) async throws -> NetworkResponse {
        requestHistory.append(request)
        
        if responseDelay > 0 {
            try await Task.sleep(for: .seconds(responseDelay))
        }
        
        if let error = mockError {
            throw error
        }
        
        if shouldSucceed {
            return mockResponse ?? NetworkResponse(
                data: Data(),
                response: HTTPURLResponse(
                    url: request.url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        } else {
            throw NetworkError.requestFailed(NSError(domain: "MockError", code: -1))
        }
    }
    
    func get(url: URL, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .GET, headers: headers)
        return try await performRequest(request)
    }
    
    func post(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .POST, headers: headers, body: body)
        return try await performRequest(request)
    }
    
    func put(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .PUT, headers: headers, body: body)
        return try await performRequest(request)
    }
    
    func delete(url: URL, headers: [String: String]? = nil) async throws -> NetworkResponse {
        let request = NetworkRequest(url: url, method: .DELETE, headers: headers)
        return try await performRequest(request)
    }
    
    func download(from url: URL, headers: [String: String]? = nil) async throws -> Data {
        let response = try await get(url: url, headers: headers)
        return response.data
    }
    
    func upload(data: Data, to url: URL, headers: [String: String]? = nil) async throws -> NetworkResponse {
        return try await post(url: url, body: data, headers: headers)
    }
    
    // MARK: - Mock Helper Methods
    
    func reset() {
        shouldSucceed = true
        mockResponse = nil
        mockError = nil
        requestHistory.removeAll()
        responseDelay = 0.0
    }
    
    func simulateSuccess(with data: Data, statusCode: Int = 200) {
        shouldSucceed = true
        mockResponse = NetworkResponse(
            data: data,
            response: HTTPURLResponse(
                url: URL(string: "https://mock.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
    
    func simulateFailure(with error: NetworkError) {
        shouldSucceed = false
        mockError = error
    }
    
    func simulateNetworkDelay(_ delay: TimeInterval) {
        responseDelay = delay
    }
    
    var lastRequest: NetworkRequest? {
        return requestHistory.last
    }
    
    var requestCount: Int {
        return requestHistory.count
    }
} 