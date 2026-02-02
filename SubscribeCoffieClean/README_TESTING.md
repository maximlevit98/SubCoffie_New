# iOS Testing Guide

Comprehensive guide for running and maintaining iOS tests for SubscribeCoffieClean.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Fastlane](#fastlane)
- [CI/CD Pipeline](#cicd-pipeline)
- [Writing New Tests](#writing-new-tests)
- [Best Practices](#best-practices)

## Overview

The iOS testing suite consists of:

- **Unit Tests**: Testing models, stores, and business logic
- **UI Tests**: Testing user interface and user flows
- **Integration Tests**: Testing complete user journeys
- **Snapshot Tests**: Visual regression testing (future)

## Test Structure

```
SubscribeCoffieClean/
├── SubscribeCoffieCleanTests/
│   └── SubscribeCoffieCleanTests.swift    # Unit tests
├── SubscribeCoffieCleanUITests/
│   └── SubscribeCoffieCleanUITests.swift  # UI tests
├── fastlane/
│   ├── Fastfile                           # Fastlane configuration
│   └── Appfile                            # App configuration
├── .swiftlint.yml                         # SwiftLint configuration
└── .github/workflows/
    ├── ios-tests.yml                      # CI test workflow
    └── ios-build-release.yml              # Release build workflow
```

## Running Tests

### Prerequisites

1. **Xcode**: Version 15.2 or later
2. **Swift**: Version 5.9 or later
3. **Simulator**: iOS 17.2 or later

### Run Tests in Xcode

1. Open `SubscribeCoffieClean.xcodeproj`
2. Select scheme: `SubscribeCoffieClean`
3. Choose test navigator (⌘+6)
4. Click the play button next to test suite or individual test

**Keyboard Shortcuts:**
- Run all tests: `⌘+U`
- Run last test: `⌃+⌥+⌘+G`
- Run test under cursor: `⌃+⌥+⌘+U`

### Run Tests from Command Line

```bash
# All tests
xcodebuild test \
  -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj \
  -scheme SubscribeCoffieClean \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Unit tests only
xcodebuild test \
  -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj \
  -scheme SubscribeCoffieClean \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:SubscribeCoffieCleanTests

# UI tests only
xcodebuild test \
  -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj \
  -scheme SubscribeCoffieClean \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:SubscribeCoffieCleanUITests
```

## Fastlane

Fastlane automates building, testing, and releasing.

### Installation

```bash
# Install Fastlane
gem install fastlane

# Or using Homebrew
brew install fastlane
```

### Available Lanes

```bash
# Run all tests
fastlane test

# Run unit tests only
fastlane test_unit

# Run UI tests only
fastlane test_ui

# Run tests on multiple devices
fastlane test_multi_device

# Run SwiftLint
fastlane lint

# Build for testing
fastlane build_for_testing

# Build release version
fastlane build_release

# Full CI pipeline
fastlane ci

# Quick test for development
fastlane quick_test
```

### Example Usage

```bash
cd SubscribeCoffieClean

# Run complete CI pipeline
fastlane ci

# Run tests and generate coverage
fastlane test

# Build release IPA
fastlane build_release
```

## CI/CD Pipeline

### GitHub Actions Workflows

#### iOS Tests (`ios-tests.yml`)

- **Triggers**: Push to `main` or `develop`, Pull Requests
- **What it does**:
  - Runs SwiftLint
  - Builds app for testing
  - Runs unit tests
  - Runs UI tests
  - Generates code coverage
  - Uploads test results

**Runs on**: macOS 14, Xcode 15.2

#### iOS Build Release (`ios-build-release.yml`)

- **Triggers**: Git tags (v*), Manual dispatch
- **What it does**:
  - Increments build number
  - Builds release archive
  - Exports IPA
  - Creates GitHub release

### Running CI Locally

Simulate CI environment locally:

```bash
# Install dependencies
brew install swiftlint
gem install fastlane

# Run linting
swiftlint lint

# Run full CI pipeline
fastlane ci
```

## Writing New Tests

### Unit Test Structure

```swift
import Testing
@testable import SubscribeCoffieClean

struct MyFeatureTests {
    
    @Test func testFeatureBehavior() async throws {
        // Arrange
        let input = createTestInput()
        
        // Act
        let result = performAction(input)
        
        // Assert
        #expect(result == expectedValue)
    }
}
```

### UI Test Structure

```swift
import XCTest

final class MyFeatureUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    @MainActor
    func testUserFlow() throws {
        // Navigate to screen
        let button = app.buttons["myButton"]
        XCTAssertTrue(button.exists)
        
        // Perform action
        button.tap()
        
        // Verify result
        let result = app.staticTexts["resultLabel"]
        XCTAssertTrue(result.exists)
    }
}
```

### Test Naming Convention

- Use descriptive names: `testWalletCreationWithValidInput`
- Start with `test`: `testCartAddsItemCorrectly`
- Include expected outcome: `testLoginFailsWithInvalidCredentials`
- Group related tests in structs

### Assertions

```swift
// Swift Testing Framework
#expect(value == expectedValue)
#expect(array.isEmpty)
#expect(result != nil)

// XCTest Framework
XCTAssertEqual(value, expectedValue)
XCTAssertTrue(condition)
XCTAssertNotNil(object)
XCTAssertGreaterThan(a, b)
```

## Best Practices

### 1. Test Isolation

- Each test should be independent
- Use setup/teardown appropriately
- Don't share state between tests

```swift
override func setUpWithError() throws {
    // Setup before each test
    store = CartStore()
}

override func tearDownWithError() throws {
    // Cleanup after each test
    store = nil
}
```

### 2. Mock Data

Create mock data factories:

```swift
extension Product {
    static func mock(
        name: String = "Test Product",
        price: Int = 100
    ) -> Product {
        Product(
            id: UUID(),
            name: name,
            description: "Test",
            basePrice: price,
            category: "test",
            imageUrl: nil,
            isAvailable: true
        )
    }
}
```

### 3. UI Testing

- Use accessibility identifiers
- Wait for elements to exist
- Use predicates for complex queries

```swift
// Set accessibility identifier in SwiftUI
Button("Add to Cart") { }
    .accessibilityIdentifier("addToCartButton")

// Use in tests
let button = app.buttons["addToCartButton"]
XCTAssertTrue(button.waitForExistence(timeout: 5))
button.tap()
```

### 4. Async Testing

```swift
@Test func testAsyncOperation() async throws {
    let result = await fetchData()
    #expect(result != nil)
}
```

### 5. Performance Testing

```swift
@MainActor
func testPerformance() throws {
    measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
        // Code to measure
        performExpensiveOperation()
    }
}
```

## Test Categories

### Unit Tests

- Model initialization and validation
- Store state management
- Business logic calculations
- Data transformations

### UI Tests

- Navigation flows
- User interactions
- Form submissions
- Error states
- Loading states

### Integration Tests

- Complete user journeys
- Multi-screen flows
- Data persistence
- Network requests (mocked)

## Code Coverage

View code coverage in Xcode:

1. Enable coverage: Edit Scheme → Test → Options → Code Coverage
2. Run tests
3. View coverage: Report Navigator → Coverage tab

**Target**: 80%+ coverage for critical paths

## SwiftLint

### Running SwiftLint

```bash
# Lint all files
swiftlint lint

# Auto-fix violations
swiftlint lint --fix

# Lint specific files
swiftlint lint --path SubscribeCoffieClean/SubscribeCoffieClean
```

### Configuration

SwiftLint is configured in `.swiftlint.yml`:

- Line length: 120 chars (warning), 200 chars (error)
- File length: 500 lines (warning), 1000 lines (error)
- Function body length: 50 lines (warning), 100 lines (error)

## Troubleshooting

### Tests Not Running

```bash
# Clean build folder
xcodebuild clean -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj

# Reset simulator
xcrun simctl erase all
```

### Simulator Issues

```bash
# Kill all simulators
killall Simulator

# Boot specific simulator
xcrun simctl boot "iPhone 15 Pro"
```

### Fastlane Issues

```bash
# Update Fastlane
gem update fastlane

# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## Test Checklist

Before committing:

- [ ] All unit tests pass
- [ ] All UI tests pass
- [ ] SwiftLint warnings resolved
- [ ] Code coverage maintained or improved
- [ ] New features have tests
- [ ] Tests are independent and isolated

## CI/CD Checklist

Before pushing:

- [ ] Tests pass locally
- [ ] SwiftLint passes
- [ ] Build succeeds
- [ ] No force unwrapping or force casts
- [ ] Accessibility identifiers added for UI tests

## Contributing

When adding new features:

1. Write tests first (TDD)
2. Ensure all existing tests still pass
3. Add UI tests for new screens/flows
4. Update this README if needed
5. Run `fastlane ci` before pushing

## Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Fastlane Documentation](https://docs.fastlane.tools)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)

---

Last Updated: January 30, 2026
