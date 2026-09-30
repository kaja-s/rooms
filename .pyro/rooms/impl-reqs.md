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

- [x] `AppController` publishes the latest :Notification: as `notification` (a `RoomsNotification` with `message` and `applications`); `NotificationDesign` in `RoomsKit` holds its checkable :NotificationDesign: values.
  Verified: AppController.@Published notification: RoomsNotification? (message, applications); NotificationDesign enum in ViewModels.swift holds the design values

- [x] :Notification: is a borderless, non-activating `NSPanel` with SwiftUI content in `NSHostingView`, at window level `.popUpMenu`, with the collection behavior `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, and `.ignoresCycle`, ignoring mouse events and never becoming key.
  Verified: DialogPresenter.showNotification builds a NotificationPanel (.borderless, .nonactivatingPanel; canBecomeKey/Main false) hosting NotificationView in NSHostingView, level .popUpMenu, collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle], ignoresMouseEvents

- [x] :WindowCatalog: uses the Accessibility API (`AXUIElement`) to list, move, resize, raise, minimize, and focus windows, `NSRunningApplication` to hide and activate applications, and `CGWindowListCopyWindowInfo` for window ids and z-order.
  - Verified: AccessibilityWindowSystem uses AXUIElement, NSRunningApplication, CGWindowListCopyWindowInfo

- [x] :WindowCatalog: finds full-screen windows through `CGWindowListCopyWindowInfo` (a window of the application at layer 0 whose bounds equal a screen's frame and that the Accessibility API does not list), because the Accessibility API lists only the windows of the current Space; it takes one out of full screen by activating the application with `NSRunningApplication` and setting the window's `AXFullScreen` attribute to false.
  Verified: AccessibilityWindowSystem.applicationsWithFullScreenWindows uses CGWindowListCopyWindowInfo (layer 0, not on screen, bounds equal a CGDisplayBounds); exitFullScreen activates via NSRunningApplication and sets AXFullScreen false; AppController.showRoom calls them for apps of missing windows

- [x] :WindowCatalog: finds the applications with a window on another desktop through `CGWindowListCopyWindowInfo`: a window of the application at layer 0, at least 100 by 100 points, not on the current Space, not in full screen, and not listed by the Accessibility API.
  Verified: AccessibilityWindowSystem.applicationsWithWindowsOnOtherDesktops uses CGWindowListCopyWindowInfo: layer 0, ≥ 100×100, not on screen, not display-sized (full screen), not in listWindows(); AppController.notifyMissing uses it for the "on another desktop" message

- [x] `FakeWindowSystem` can put a window in full screen or on another desktop; such a window is not listed, like the Accessibility API.
  Verified: FakeWindowSystem.setFullScreen/setOnOtherDesktop; listWindows skips both; applicationsWithFullScreenWindows / applicationsWithWindowsOnOtherDesktops report them

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

- [x] `RoomsCore` contains the pure logic as separate types: `Room`, `AppWindow`, `Layout`, `LayoutEngine`, `RoomStore` (JSON persistence), `RoomMatcher` (name matching and ordering), and `WindowMatcher` (re-finding saved windows).
  Verified: RoomsCore has Models.swift (Room, AppWindow, Layout), LayoutEngine, RoomStore, RoomMatcher, WindowMatcher; SnapGrid removed; Foundation/CoreGraphics only

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

- [x] `FakeWindowSystem` can give a window a resize delay in milliseconds, applied on its fake clock advanced by `wait(milliseconds:)`, and can make a window ignore resize requests.
  Verified: FakeWindowSystem.setResizeBehavior(of:delayMilliseconds:ignoresResize:); pending frames applied when wait(milliseconds:) advances the fake clock past the delay; ignoresResize keeps the size

- [x] A stored :Layout: value `myLayout` from an earlier version of :RoomsApp: loads as Auto, and stored `myLayoutFrames` are ignored.
  Verified: Layout.init(from:) decodes "myLayout" as .auto; Room has no myLayoutFrames property so the stored key is ignored by Codable; covered by ModelsTests and conformance 12 testLegacyMyLayoutLoadsAsAuto

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
