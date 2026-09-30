- [x] :ConformanceTests: are XCTest test cases in Swift, one or more `.swift` files per functional spec, compiled into the package's `ConformanceTests` target.
  - Verified: all 31 conformance suites follow this requirement and pass

- [x] :ConformanceTests: `@testable import RoomsCore` and `@testable import RoomsKit`, and drive the app only through `AppController` and its view models with a `FakeWindowSystem`; they never call the Accessibility API, open a window, register a hotkey, or need a macOS permission.
  - Verified: all 31 conformance suites follow this requirement and pass

- [x] :ConformanceTests: give `AppController` a `RoomStore` in a fresh temporary directory per test.
  - Verified: all 31 conformance suites follow this requirement and pass

- [x] :ConformanceTests: must be implemented and executed; no test is skipped.
  - Verified: all 31 conformance suites follow this requirement and pass

- [x] :ConformanceTests: are prepared via the prepare script [test_scripts/prepare_environment_swift.sh](test_scripts/prepare_environment_swift.sh).
  - Verified: all 31 conformance suites follow this requirement and pass

- [x] :ConformanceTests: are executed via the run script [test_scripts/run_conformance_tests_swift.sh](test_scripts/run_conformance_tests_swift.sh).
  - Verified: all 31 conformance suites follow this requirement and pass
