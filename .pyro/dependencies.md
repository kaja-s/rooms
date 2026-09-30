# Dependencies for rendering rooms.plain

## Implementation
| Dependency | Required by | Status |
|---|---|---|
| Swift toolchain (Swift 5 language mode, tools 5.10) | impl reqs: Swift, SwiftPM | present: swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101) |
| Swift Package Manager | impl reqs: swift build / swift run | present: Swift Package Manager - Swift 6.3.3 |
| macOS SDK 14+ with AppKit, SwiftUI, ApplicationServices, Carbon, CoreGraphics, os.log | impl reqs: frameworks | present: Xcode 26.6 (26.5.1) |
| No third-party packages | impl reqs name none | n/a |

## Tests
| Dependency | Required by | Status |
|---|---|---|
| XCTest | :UnitTests: and :ConformanceTests: | present |
| bash | test_scripts/*.sh | present: GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25) |
| test_scripts/run_unittests_swift.sh | :UnitTests: run script | present |
| test_scripts/prepare_environment_swift.sh | :ConformanceTests: prepare script | present |
| test_scripts/run_conformance_tests_swift.sh | :ConformanceTests: run script | present |

All dependencies present. Nothing to install.
