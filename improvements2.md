# PhotoBooth Comprehensive Improvement Plan

## Overview
This document outlines a systematic approach to improve the PhotoBooth codebase by combining the best elements from both architectural refactoring and feature enhancement plans. The plan prioritizes maintainability, security, and extensibility while preserving critical continuity camera functionality.

## Guardrails & Principles (applies to every phase)
- **CRITICAL**: Preserve continuity-camera code exactly as documented in PhotoBooth Cursor Rules
- Keep image generation on gpt-image-1 and continue using PhotoTheme prompts
- All new code follows Swift Concurrency best practices
- Use Context7 docs for any third-party library usage
- Each phase ends with: unit/UI test run, manual continuity-camera smoke test, and demo validation

## Phase 1: View-Model Decomposition & Coordinator Clean-up

### 1.1 Extract Specialized View Models
- Move camera logic from `PhotoBoothViewModel` to `CameraViewModel`
- Move image processing logic to `ImageProcessingViewModel`  
- Move UI state logic to `UIStateViewModel`
- Preserve all continuity camera detection and connection logic

### 1.2 Camera Logic Migration
- Move camera properties: `isSessionRunning`, `isCameraConnected`, `availableCameras`, `selectedCameraDevice`, `captureSession`
- Move camera methods: `refreshAvailableCameras`, `selectCamera`, `findAndSetupContinuityCamera`, `forceContinuityCameraConnection`
- Delegate photo capture to `CameraViewModel`

### 1.3 Image Processing Logic Migration
- Move properties: `selectedTheme`, `isProcessing`, `lastCapturedImage`, `lastThemedImage`, `themes`
- Move methods: `selectTheme`, `processPhoto`
- Handle image processing results through publishers

### 1.4 UI State Logic Migration
- Move properties: `countdown`, `isCountingDown`, `errorMessage`, `showError`, `isReadyForNextPhoto`, `minimumDisplayTimeRemaining`
- Move methods: `startCountdown`, `showError`, `startMinimumDisplayPeriod`, `stopMinimumDisplayPeriod`

### 1.5 PhotoBoothViewModel as Pure Coordinator
- Simplify init to only initialize specialized view models
- Remove delegate conformance, use Combine publishers
- Update views to bind directly to specialized view models
- Route all service access through `PhotoBoothServiceCoordinator`

## Phase 2: Dedicated Network Layer

### 2.1 NetworkService Implementation
- Create `NetworkServiceProtocol` with standardized HTTP methods
- Implement concrete `NetworkService` with retry logic, logging, error handling
- Support async/await patterns for non-blocking operations

### 2.2 Service Integration
- Refactor `OpenAIService` to use network layer
- Register `NetworkService` in `PhotoBoothServiceCoordinator`
- Ensure proper dependency injection

### 2.3 Testing & Validation
- Add unit tests with mock responses
- Test success, failure, and retry scenarios
- Validate network timeouts and error handling

## Phase 3: Secure Credential Management

### 3.1 Keychain Integration
- Create `KeychainCredentialStore` for macOS Keychain access
- Implement secure read/write operations for API keys
- Add proper error handling for Keychain operations

### 3.2 Configuration Service Updates
- Update `ConfigurationService` to prioritize Keychain over .env
- Implement migration path from .env to Keychain
- Maintain backward compatibility during transition

### 3.3 Documentation & Security
- Update `README.md` and `SETUP_GUIDE.md` with secure setup instructions
- Add CI guard against committing sensitive keys
- Document best practices for credential management

## Phase 4: Expanded Test Coverage & CI Automation

### 4.1 Test Infrastructure
- Replace placeholder code in `UserFlowTests.setupTestEnvironment()`
- Implement comprehensive mocking for all services
- Add dependency injection support for testing

### 4.2 Core Feature Testing
- Test camera capture logic (preserving continuity camera tests)
- Test OpenAI prompt generation and image processing
- Test theme loading and configuration
- Test network operations and error scenarios

### 4.3 CI/CD Integration
- Set up GitHub Actions workflow for automated testing
- Integrate `swift test` and UI tests
- Add test coverage reporting and badges

## Phase 5: Documentation & Theme Extensibility

### 5.1 Theme Documentation
- Create comprehensive guide for custom theme creation
- Provide JSON examples and schema documentation
- Document theme loading and configuration process

### 5.2 Hot-Reload Support (Optional)
- Implement file watcher in `ThemeConfigurationService`
- Add runtime theme reloading capability
- Ensure thread-safe theme updates

### 5.3 Example Gallery
- Create sample themed outputs using gpt-image-1
- Document PhotoTheme prompt effectiveness
- Provide visual examples in documentation

## Phase 6: Post-Refactor Hardening

### 6.1 Code Quality
- Run static analysis (SwiftLint)
- Address deprecation warnings (except required continuity camera APIs)
- Ensure consistent code style and documentation

### 6.2 Integration Testing
- Full regression test suite on Mac + iPhone continuity camera
- Performance testing and optimization
- Memory leak detection and resolution

### 6.3 Release & Documentation
- Tag stable release with comprehensive changelog
- Update `SETUP_GUIDE.md` with new architecture diagram
- Create migration guide for existing users

## Success Metrics
- All tests passing (unit, integration, UI)
- Continuity camera functionality preserved and tested
- Improved code maintainability and readability
- Secure credential management implemented
- Comprehensive documentation and examples
- CI/CD pipeline operational

## Risk Mitigation
- Frequent testing after each change
- Git branching strategy for each phase
- Rollback plan for continuity camera issues
- Staged rollout of new features
- Continuous validation of core functionality

---

**Next Steps**: Execute phases sequentially with approval gates, starting with Phase 1 view model decomposition. 