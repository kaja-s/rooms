- [x] :RoomList: is written to disk atomically: to a temporary file in the same folder that then replaces the previous file.
  - Verified: RoomStore.save writes a temp file in the same folder and swaps it in with replaceItemAt/moveItem (RoomStoreTests)

- [x] When an application does not apply a requested window frame, :RoomsApp: requests it once more after 100 ms and then accepts the frame the application settled on.
  - Verified: WindowCatalog.move re-requests after wait(100) and returns the settled frame (WindowCatalogTests)

- [x] :Implementation: is written in Swift, Swift 5 language mode, built with Swift Package Manager (swift-tools-version 5.10), for macOS 14 or newer on Apple silicon and Intel.
  - Verified: Package.swift swift-tools-version 5.10 (Swift 5 mode), platforms macOS 14; host-architecture build, universal via `swift build --arch arm64 --arch x86_64`

- [x] :Implementation: is one Swift package with a `Package.swift` at the build folder root and three products: the library target `RoomsCore` (Foundation only, no AppKit), the library target `RoomsKit` (depends on `RoomsCore`, links AppKit, SwiftUI, ApplicationServices, Carbon), and the executable target `Rooms` whose `main.swift` only starts the app from `RoomsKit`.
  - Verified: Products RoomsCore (Foundation/CoreGraphics only), RoomsKit (AppKit, SwiftUI, ApplicationServices, Carbon), Rooms executable whose main.swift is `RoomsApp.main()`

- [x] :Implementation: has no Xcode project, no `.app` bundle, no App Sandbox, and no code signing; `swift build` and `swift run Rooms` are the only build and launch commands.
  - Verified: No .xcodeproj, bundle, entitlements, or signing; RoomsApp.main() runs NSApplication from the plain executable

- [x] :RoomsApp: uses AppKit: `NSApplication` with the `.accessory` activation policy, `NSStatusItem` for :MenuBarItem:, a non-activating `NSPanel` for :Palette:, and `NSWindow` for :WindowPicker: and :GettingStarted:; view content is SwiftUI hosted in `NSHostingView`.
  - Verified: RoomsApp sets .accessory; StatusItemController uses NSStatusItem; PalettePanel is a .nonactivatingPanel; picker and Getting Started are NSWindow; all content is NSHostingView

- [x] :WindowCatalog: uses the Accessibility API (`AXUIElement`) to list, move, resize, raise, minimize, and focus windows, `NSRunningApplication` to hide and activate applications, and `CGWindowListCopyWindowInfo` for window ids and z-order.
  - Verified: AccessibilityWindowSystem: AXUIElement for list/move/resize/raise/minimize/focus; NSRunningApplication hide/unhide/activate; CGWindowListCopyWindowInfo for z-order

- [x] :AppWindow: identity is the application bundle identifier, the process identifier, and the `CGWindowID`; :WindowCatalog: pairs an Accessibility window element with its `CGWindowID` through the private function `_AXUIElementGetWindow`.
  - Verified: WindowIdentity(bundleIdentifier, processIdentifier, windowID); elements paired via _AXUIElementGetWindow

- [x] :WindowPicker: snapshots are taken with `CGWindowListCreateImage` for the window's `CGWindowID`.
  - Verified: AccessibilityWindowSystem.snapshot(of:) uses CGWindowListCreateImage(.optionIncludingWindow)

- [x] Global hotkeys (⌥Space, ⌃⌥1–9, ⌃⌥ arrows, ⌃⌥↩) are registered with the Carbon `RegisterEventHotKey` API; keys inside :Palette: and :WindowPicker: are handled by the panel or window itself.
  - Verified: HotkeyCenter registers ⌥Space, ⌃⌥1–9, ⌃⌥ arrows and ⌃⌥↩ via RegisterEventHotKey; PalettePanel.sendEvent and SwiftUI keyboardShortcut handle keys inside the palette and picker

- [x] :RoomList: is stored as one JSON file at `~/Library/Application Support/Rooms/rooms.json`, encoded with `Codable`, dates in ISO 8601, and loaded at launch; a missing or unreadable file is treated as an empty :RoomList: and the unreadable file is kept as `rooms.json.corrupt`.
  - Verified: RoomStore.defaultFileURL is ~/Library/Application Support/Rooms/rooms.json; Codable, ISO 8601 dates; loaded in AppController.start(); corrupt file kept as rooms.json.corrupt

- [x] The first-launch flag for :GettingStarted: is stored in `UserDefaults` under the key `hasLaunchedBefore`.
  - Verified: AppController.hasLaunchedBeforeKey = "hasLaunchedBefore" in the injected UserDefaults

- [x] `RoomsCore` contains the pure logic as separate types: `Room`, `AppWindow`, `Layout`, `LayoutEngine`, `RoomStore` (JSON persistence), `RoomMatcher` (name matching and ordering), `WindowMatcher` (re-finding saved windows), and `SnapGrid` (My Layout snapping).
  - Verified: Models.swift (Room, AppWindow, Layout), LayoutEngine, RoomStore, RoomMatcher, WindowMatcher, SnapGrid

- [x] `RoomsKit` defines a `WindowSystem` protocol covering every call :WindowCatalog: makes to the Accessibility API, `NSRunningApplication`, and window snapshots; `AccessibilityWindowSystem` is the real implementation, and every other type in `RoomsKit` receives a `WindowSystem` by injection.
  - Verified: WindowSystem.swift; AccessibilityWindowSystem is the real implementation; WindowCatalog and AppController receive it by injection

- [x] `RoomsKit` exposes an `AppController` facade that owns the `RoomStore`, :CurrentRoom:, the `WindowSystem`, and one view model per surface (`PaletteViewModel`, `WindowPickerViewModel`, `StatusMenuModel`, `GettingStartedModel`); every user action in :Palette:, :WindowPicker:, and the :MenuBarItem: menu is a method on one of these view models, and views only bind to them.
  - Verified: AppController owns RoomStore, currentRoomID, WindowSystem and the four view models; SwiftUI views call only view-model methods (footer groups are view-model properties)

- [x] Every Accessibility call that fails for one window is logged with `os.Logger` (subsystem `dev.rooms.app`) and that window is skipped; a failure never stops the rest of the operation or crashes :RoomsApp:.
  - Verified: Logger(subsystem: "dev.rooms.app") in AccessibilityWindowSystem, WindowCatalog and AppController; failing windows are skipped, nothing throws

- [x] All layout arithmetic uses AppKit screen coordinates in points and integral frames, rounded to whole points.
  - Verified: LayoutEngine works in AppKit coordinates and rounds every frame to whole points (LayoutEngineTests.testFramesAreIntegral)

- [x] `RoomsKit` includes `FakeWindowSystem`, a public in-memory `WindowSystem` whose applications, windows, screens, permission flags, and recorded operations are set and read directly by test code.
  - Verified: FakeWindowSystem.swift is public: applications, windows, hiddenApplications, permission flags, visibleArea, recorded operations

- [x] `RoomStore` and `AppController` take the JSON file location by injection, defaulting to the Application Support path.
  - Verified: RoomStore(fileURL:) defaults to RoomStore.defaultFileURL; AppController(store:) defaults to RoomStore()

- [x] `Package.swift` declares the test targets `RoomsCoreTests` (depends on `RoomsCore`), `RoomsKitTests` (depends on `RoomsKit`), and `ConformanceTests` at `Tests/ConformanceTests` (depends on `RoomsCore` and `RoomsKit`), the last holding only an empty `Placeholder.swift` with no test cases.
  - Verified: Package.swift declares RoomsCoreTests, RoomsKitTests and ConformanceTests (Tests/ConformanceTests, Placeholder.swift with no test cases)

- [x] :UnitTests: use XCTest and live in `Tests/RoomsCoreTests` and `Tests/RoomsKitTests`, one test file per type under test.
  - Verified: Tests/RoomsCoreTests (6 files) and Tests/RoomsKitTests (9 files, one per type, plus TestHarness.swift)

- [x] :UnitTests: of `RoomsKit` drive view models and `AppController` with `FakeWindowSystem` and a `RoomStore` in a temporary directory; they never call the Accessibility API, open a window, register a hotkey, or touch the user's Application Support folder.
  - Verified: RoomsKitTests use TestHarness (FakeWindowSystem + RoomStore in a temporary directory); no AX, windows, hotkeys, or Application Support access

- [x] :UnitTests: are executed via the run script [test_scripts/run_unittests_swift.sh](test_scripts/run_unittests_swift.sh).
  - Verified: test_scripts/run_unittests_swift.sh ran in this render: all unit tests passed, 0 failures
