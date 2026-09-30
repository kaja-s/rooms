- [x] :ConformanceTests: are XCTest test cases in Swift, one or more `.swift` files per functional spec, compiled into the package's `ConformanceTests` target.
  Verified: every suite in plain_module/tests/NN_*/ is XCTest compiled into the ConformanceTests target; one folder per functional spec (31)

- [x] :ConformanceTests: `@testable import RoomsCore` and `@testable import RoomsKit`, and drive the app only through `AppController` and its view models with a `FakeWindowSystem`; they never call the Accessibility API, open a window, register a hotkey, or need a macOS permission.
  Verified: every file uses @testable import RoomsCore/RoomsKit and drives AppController with FakeWindowSystem; no AXUIElement, hotkey, or window calls

- [x] :ConformanceTests: give `AppController` a `RoomStore` in a fresh temporary directory per test.
  Verified: each Harness creates a RoomStore in a fresh UUID temporary directory and removes it in deinit

- [x] :ConformanceTests: must be implemented and executed; no test is skipped.
  Verified: 125 conformance tests executed, 0 failures, no XCTSkip

- [x] :ConformanceTests: are prepared via the prepare script [test_scripts/prepare_environment_swift.sh](test_scripts/prepare_environment_swift.sh).
  Verified: prepare_environment_swift.sh run before the suites (exit 0)

- [x] :ConformanceTests: are executed via the run script [test_scripts/run_conformance_tests_swift.sh](test_scripts/run_conformance_tests_swift.sh).
  Verified: every suite executed via run_conformance_tests_swift.sh (exit 0)
