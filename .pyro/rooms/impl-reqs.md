- [x] :RoomList: is written to disk atomically: to a temporary file in the same folder that then replaces the previous file.
  - Verified: RoomStore.save: temp file in the same folder swapped in with replaceItemAt/moveItem

- [x] When an application does not apply a requested window frame, :RoomsApp: requests it once more after 100 ms and then accepts the frame the application settled on.
  - Verified: WindowCatalog.move re-requests after wait(100) and accepts the settled frame

- [x] :Implementation: is written in Swift, Swift 5 language mode, built with Swift Package Manager (swift-tools-version 5.10), for macOS 14 or newer on Apple silicon and Intel.
  - Verified: swift-tools-version 5.10 (Swift 5 mode), macOS 14

- [x] :Implementation: is one Swift package with a `Package.swift` at the build folder root and three products: the library target `RoomsCore` (Foundation only, no AppKit), the library target `RoomsKit` (depends on `RoomsCore`, links AppKit, SwiftUI, ApplicationServices, Carbon), and the executable target `Rooms` whose `main.swift` only starts the app from `RoomsKit`.
  - Verified: RoomsCore (Foundation/CoreGraphics), RoomsKit (AppKit, SwiftUI, ApplicationServices, Carbon), Rooms executable calling RoomsApp.main()

- [x] :Implementation: has no Xcode project, no `.app` bundle, no App Sandbox, and no code signing; `swift build` and `swift run Rooms` are the only build and launch commands.
  - Verified: No project, bundle, sandbox, or signing

- [x] :RoomsApp: uses AppKit: `NSApplication` with the `.accessory` activation policy, `NSStatusItem` for :MenuBarItem:, a non-activating `NSPanel` for :Palette:, and `NSWindow` for :WindowPicker: and :GettingStarted:; view content is SwiftUI hosted in `NSHostingView`.
  - Verified: Accessory policy, NSStatusItem, non-activating NSPanel, NSWindow picker/Getting Started, NSHostingView content; overlay is a borderless NSWindow with SwiftUI content

- [x] `PaletteViewModel.panelHeight` is the height of :Palette: computed from the :PaletteDesign: tokens and the current rows; the :Palette: panel sets its frame height to exactly this value on open and whenever it changes, and never measures `NSHostingView.fittingSize` or applies a minimum height.
  Verified: PaletteViewModel.panelHeight = PaletteDesign.panelHeight(rowCount:) from tokens; PalettePanelController.contentHeight() returns it on open and on every objectWillChange; no fittingSize, no minimum

- [x] The :Palette: panel is borderless, non-opaque, with a clear background; its SwiftUI content fills the panel exactly and draws the rounded shape, fill, and border itself, and the panel shadow is invalidated after every resize so it follows the rounded shape.
  Verified: styleMask .borderless, isOpaque=false, backgroundColor .clear; PaletteView framed to panelWidth × panelHeight and draws the rounded fill, border, and clip; invalidateShadow() after every setFrame

- [x] :WindowCatalog: uses the Accessibility API (`AXUIElement`) to list, move, resize, raise, minimize, and focus windows, `NSRunningApplication` to hide and activate applications, and `CGWindowListCopyWindowInfo` for window ids and z-order.
  - Verified: AccessibilityWindowSystem uses AXUIElement, NSRunningApplication, CGWindowListCopyWindowInfo

- [x] :AppWindow: identity is the application bundle identifier, the process identifier, and the `CGWindowID`; :WindowCatalog: pairs an Accessibility window element with its `CGWindowID` through the private function `_AXUIElementGetWindow`.
  - Verified: WindowIdentity(bundleIdentifier, processIdentifier, windowID) via _AXUIElementGetWindow

- [x] :WindowPicker: snapshots are taken with `CGWindowListCreateImage` for the window's `CGWindowID`.
  - Verified: AccessibilityWindowSystem.snapshot(of:)

- [x] Global hotkeys (⌥Space, ⌃⌥1–9, ⌃⌥ arrows, ⌃⌥↩) are registered with the Carbon `RegisterEventHotKey` API; keys inside :Palette: and :WindowPicker: are handled by the panel or window itself.
  - Verified: HotkeyCenter with RegisterEventHotKey; in-palette keys via PalettePanel.sendEvent

- [x] :RoomList: is stored as one JSON file at `~/Library/Application Support/Rooms/rooms.json`, encoded with `Codable`, dates in ISO 8601, and loaded at launch; a missing or unreadable file is treated as an empty :RoomList: and the unreadable file is kept as `rooms.json.corrupt`.
  - Verified: RoomStore at ~/Library/Application Support/Rooms/rooms.json, ISO 8601, corrupt file kept

- [x] The first-launch flag for :GettingStarted: is stored in `UserDefaults` under the key `hasLaunchedBefore`.
  - Verified: UserDefaults key hasLaunchedBefore

- [x] `RoomsCore` contains the pure logic as separate types: `Room`, `AppWindow`, `Layout`, `LayoutEngine`, `RoomStore` (JSON persistence), `RoomMatcher` (name matching and ordering), `WindowMatcher` (re-finding saved windows), and `SnapGrid` (My Layout snapping).
  - Verified: Room, AppWindow, Layout, LayoutEngine, RoomStore, RoomMatcher, WindowMatcher, SnapGrid

- [x] `RoomsKit` defines a `WindowSystem` protocol covering every call :WindowCatalog: makes to the Accessibility API, `NSRunningApplication`, and window snapshots; `AccessibilityWindowSystem` is the real implementation, and every other type in `RoomsKit` receives a `WindowSystem` by injection.
  - Verified: WindowSystem protocol; AccessibilityWindowSystem injected

- [x] `RoomsKit` exposes an `AppController` facade that owns the `RoomStore`, :CurrentRoom:, the `WindowSystem`, and one view model per surface (`PaletteViewModel`, `WindowPickerViewModel`, `StatusMenuModel`, `GettingStartedModel`); every user action in :Palette:, :WindowPicker:, and the :MenuBarItem: menu is a method on one of these view models, and views only bind to them.
  - Verified: AppController owns store, current room, window system, four view models; overlay and palette views bind only to PaletteViewModel

- [x] Every Accessibility call that fails for one window is logged with `os.Logger` (subsystem `dev.rooms.app`) and that window is skipped; a failure never stops the rest of the operation or crashes :RoomsApp:.
  - Verified: subsystem dev.rooms.app; failing windows skipped

- [x] All layout arithmetic uses AppKit screen coordinates in points and integral frames, rounded to whole points.
  - Verified: LayoutEngine rounds to whole points; overlay y-flips from AppKit coordinates

- [x] `RoomsKit` includes `FakeWindowSystem`, a public in-memory `WindowSystem` whose applications, windows, screens, permission flags, and recorded operations are set and read directly by test code.
  - Verified: Public FakeWindowSystem with recorded operations

- [x] `RoomStore` and `AppController` take the JSON file location by injection, defaulting to the Application Support path.
  - Verified: RoomStore(fileURL:), AppController(store:)

- [x] `Package.swift` declares the test targets `RoomsCoreTests` (depends on `RoomsCore`), `RoomsKitTests` (depends on `RoomsKit`), and `ConformanceTests` at `Tests/ConformanceTests` (depends on `RoomsCore` and `RoomsKit`), the last holding only an empty `Placeholder.swift` with no test cases.
  - Verified: RoomsCoreTests, RoomsKitTests, ConformanceTests with empty Placeholder.swift

- [x] :UnitTests: use XCTest and live in `Tests/RoomsCoreTests` and `Tests/RoomsKitTests`, one test file per type under test.
  - Verified: Tests/RoomsCoreTests and Tests/RoomsKitTests, one file per type

- [x] :UnitTests: of `RoomsKit` drive view models and `AppController` with `FakeWindowSystem` and a `RoomStore` in a temporary directory; they never call the Accessibility API, open a window, register a hotkey, or touch the user's Application Support folder.
  - Verified: TestHarness with FakeWindowSystem and temp RoomStore

- [x] :UnitTests: are executed via the run script [test_scripts/run_unittests_swift.sh](test_scripts/run_unittests_swift.sh).
  - Verified: run_unittests_swift.sh: 87 tests, 0 failures
