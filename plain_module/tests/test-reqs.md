- [x] :ConformanceTests: are XCTest test cases in Swift, one or more `.swift` files per functional spec, compiled into the package's `ConformanceTests` target.
  - Verified: 31 folders, one per functional spec

- [x] :ConformanceTests: `@testable import RoomsCore` and `@testable import RoomsKit`, and drive the app only through `AppController` and its view models with a `FakeWindowSystem`; they never call the Accessibility API, open a window, register a hotkey, or need a macOS permission.
  - Verified: All folders drive AppController/view models or pure values through FakeWindowSystem; no AX, windows, hotkeys, permissions

- [x] :ConformanceTests: give `AppController` a `RoomStore` in a fresh temporary directory per test.
  - Verified: Harness creates a temp RoomStore per test

- [x] :ConformanceTests: must be implemented and executed; no test is skipped.
  - Verified: 31 folders executed, all exit 0, no skips

- [x] :ConformanceTests: are prepared via the prepare script [test_scripts/prepare_environment_swift.sh](test_scripts/prepare_environment_swift.sh).
  - Verified: prepare_environment_swift.sh exit 0

- [x] :ConformanceTests: are executed via the run script [test_scripts/run_conformance_tests_swift.sh](test_scripts/run_conformance_tests_swift.sh).
  - Verified: run_conformance_tests_swift.sh once per folder, all exit 0
