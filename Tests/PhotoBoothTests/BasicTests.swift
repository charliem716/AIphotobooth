import XCTest
@testable import PhotoBooth

/// Basic tests to demonstrate the testing infrastructure is working
final class BasicTests: XCTestCase {
    
    func testExampleTest() {
        // Given
        let value = 42
        
        // When
        let result = value * 2
        
        // Then
        XCTAssertEqual(result, 84, "Basic math should work")
    }
    
    func testStringOperation() {
        // Given
        let greeting = "Hello"
        let name = "World"
        
        // When
        let result = "\(greeting), \(name)!"
        
        // Then
        XCTAssertEqual(result, "Hello, World!", "String concatenation should work")
    }
    
    func testAsyncOperation() async {
        // Given
        let delay = 0.1
        
        // When
        let start = Date()
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        let end = Date()
        
        // Then
        let elapsed = end.timeIntervalSince(start)
        XCTAssertGreaterThan(elapsed, delay * 0.9, "Should have waited approximately the right amount of time")
    }
    
    func testArrayOperations() {
        // Given
        let numbers = [1, 2, 3, 4, 5]
        
        // When
        let doubled = numbers.map { $0 * 2 }
        let sum = numbers.reduce(0, +)
        
        // Then
        XCTAssertEqual(doubled, [2, 4, 6, 8, 10], "Array mapping should work")
        XCTAssertEqual(sum, 15, "Array reduction should work")
    }
    
    func testErrorHandling() {
        // Given
        enum TestError: Error {
            case testFailure
        }
        
        func throwingFunction() throws -> String {
            throw TestError.testFailure
        }
        
        // When & Then
        XCTAssertThrowsError(try throwingFunction()) { error in
            XCTAssertTrue(error is TestError, "Should throw TestError")
        }
    }
    
    func testOptionalHandling() {
        // Given
        let optionalValue: Int? = 42
        let nilValue: Int? = nil
        
        // When & Then
        XCTAssertNotNil(optionalValue, "Should have value")
        XCTAssertEqual(optionalValue, 42, "Should have correct value")
        XCTAssertNil(nilValue, "Should be nil")
    }
    
    func testPerformanceExample() {
        // Given
        let largeArray = Array(1...100000)
        
        // When & Then
        measure {
            _ = largeArray.map { $0 * 2 }
        }
    }
} 