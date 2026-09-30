- [x] :ConformanceTests: are XCTest test cases in Swift, one or more `.swift` files per functional spec, compiled into the package's `ConformanceTests` target.
  - Verified: plain_module/tests/<nn>_<spec>/ConformanceTests.swift, one folder per functional spec (30), compiled into the ConformanceTests target by the run script

- [x] :ConformanceTests: `@testable import RoomsCore` and `@testable import RoomsKit`, and drive the app only through `AppController` and its view models with a `FakeWindowSystem`; they never call the Accessibility API, open a window, register a hotkey, or need a macOS permission.
  - Verified: Each file @testable imports both modules and drives AppController and its view models through a FakeWindowSystem; folders 11, 12 and 30 assert on RoomsCore/RoomsKit values directly, still with no Accessibility calls, windows, hotkeys or permissions

- [x] :ConformanceTests: give `AppController` a `RoomStore` in a fresh temporary directory per test.
  - Verified: Harness creates a temporary directory with its own RoomStore per test instance

- [x] :ConformanceTests: must be implemented and executed; no test is skipped.
  - Verified: All 30 folders executed via the run script with exit 0; no XCTSkip anywhere

- [x] :ConformanceTests: are prepared via the prepare script [test_scripts/prepare_environment_swift.sh](test_scripts/prepare_environment_swift.sh).
  - Verified: test_scripts/prepare_environment_swift.sh ran once (exit 0) and populated /tmp/swift_code

- [x] :ConformanceTests: are executed via the run script [test_scripts/run_conformance_tests_swift.sh](test_scripts/run_conformance_tests_swift.sh).
  - Verified: test_scripts/run_conformance_tests_swift.sh ran once per folder (30 runs, all exit 0)
