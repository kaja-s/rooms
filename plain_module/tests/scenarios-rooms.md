# Conformance test scenarios — rooms

All scenarios drive `AppController` and its view models through `FakeWindowSystem` with a `RoomStore` in a fresh temporary directory. "Reloaded from disk" means constructing a new `RoomStore` on the same file and reading it. Visible area defaults to 1440 × 900 at origin (0, 0) unless stated.

## FS1 — Menu bar app and menu
- S1.1 `StatusMenuModel.items` has, in order: header, Show Palette (⌥Space), Edit Windows…, Rename…, Getting Started, Quit Rooms.
- S1.2 With no current room the header reads "No room" and is disabled; Edit Windows… and Rename… are disabled.
- S1.3 With a current room the header reads its name; Edit Windows… and Rename… are enabled.
- S1.4 Quit Rooms invokes the controller's quit action (recorded by a hook / `quitRequested` flag).
- S1.5 App activation policy is `.accessory` (checked through the controller's configuration value, not a live NSApp).

## FS2 — ⌥Space toggles the palette
- S2.1 `AppController.toggleHotkeyPressed()` opens the palette: `isPaletteVisible == true`, query text empty, screen = the screen under the fake pointer.
- S2.2 Pressing again closes it. Esc closes it. `clickedOutside()` closes it. `StatusMenuModel.showPalette()` opens it.
- S2.3 Palette footer hints include "↵ Go" and "esc Close".

## FS3 — Palette lists rooms
- S3.1 Rooms with lastShown dates are listed most recent first; rooms never shown follow in creation order.
- S3.2 Row shows app icons (one per window, in window order), name, subtitle "<layout name> · <count> windows" (e.g. "Auto · 3 windows").
- S3.3 Right end shows "Current" for the current room, otherwise "⌃⌥<n>" when a key is set, otherwise nothing. Current wins when both apply.
- S3.4 The first row is selected on open; ↓ and ↑ move the selection and clamp at ends.
- S3.5 Empty RoomList and empty query → empty-state text "No rooms yet. Type a name and press ↵ to create one."; no rows.

## FS4 — Fuzzy filter and Create row
- S4.1 Typing "dw" matches "Deep Work" (subsequence, case-insensitive) and not "Design".
- S4.2 Ordering: prefix matches first, then word-start matches, then the rest; ties keep unfiltered order.
- S4.3 First match selected after typing.
- S4.4 Non-empty query that is not exactly an existing name (ignoring case) appends a Create row "Create “<query>”"; it is selected when there are no matches; it is absent when the query is exactly an existing name; the empty-state text is not shown while typing.
- AT4.a Rooms Design (created first), Deep Work, Daily Build, none ever shown; typing "de" → rows: Design, Deep Work, Create “de”; Daily Build absent; Design selected.

## FS5 — Window catalog lists windows
- S5.1 Catalog returns every window the fake exposes as standard, across apps, including minimized windows and windows of hidden apps.
- S5.2 Non-standard windows (menus, tooltips, utility panels) and Rooms' own windows are excluded.
- S5.3 With Accessibility permission off, listing returns nothing and the controller presents the permission dialog: message "Rooms needs Accessibility access to see and move windows", buttons Open System Settings and Cancel; Open System Settings requests the system-settings open (recorded by the fake).

## FS6 — Create row opens the window picker
- S6.1 With query "Alpha" and the Create row selected, ↵ closes the palette and opens the picker in create mode with name "Alpha", title "Choose the windows for “Alpha”", centered request on the current screen.
- S6.2 One card per catalog window, in catalog order; card has snapshot (when Screen Recording is on), app icon, title; title falls back to app name when empty.
- S6.3 Screen Recording permission off → card snapshot is nil and `showsAppIconInsteadOfSnapshot` is true.
- S6.4 Buttons Cancel and Create Room; Cancel closes the picker and saves nothing.

## FS7 — Card selection toggles
- S7.1 Clicking cards A, B gives badges 1, 2; clicking A again removes A's badge and B becomes 1.
- S7.2 Selected cards report `isSelected` (highlighted border).
- S7.3 Create Room enabled iff at least one card is selected.

## FS8 — Minimum size measurement
- S8.1 Measuring asks the fake to resize to 1×1, reads the settled size (the fake's configured minimum), then restores the original frame exactly; the recorded operations show resize(1×1), then set-frame(original).
- S8.2 Position is unchanged after measuring.

## FS9 — Create Room saves
- S9.1 Saved room: windows in badge order, layout Auto, no direct key, lastShown nil before showing... (note: FS16 shows the room right after save, so lastShown becomes set; check order & layout & key). Store file exists; reload contains the room.
- S9.2 Minimum size measured for each selected window before saving; saved windows carry the fake's minimum sizes.
- S9.3 Picker closes after saving.
- AT9.a Select B, A, C → order B, A, C; layout Auto; no key; minimum sizes present; reload from disk shows same order.

## FS10 — Re-finding windows (WindowMatcher)
- S10.1 Exact identity (bundle id + pid + windowID) match wins.
- S10.2 Same app, new pid/windowID, same title → found by title.
- S10.3 Same app, titles changed → first unmatched window of that app, each window used at most once across the room's saved windows.
- S10.4 App not running → not found.
- AT10.a Relaunched app: saved window found by title. Two saved windows with both titles changed are matched to the app's remaining windows in saved order, no window twice.

## FS11 — LayoutEngine frames
- S11.1 Gap 8 between frames and from area edges.
- S11.2 Focus single window fills the area (inset by gap).
- S11.3 Focus with n>1: main window left, two-thirds of usable width; others share the right third stacked top to bottom with equal heights.
- S11.4 Columns: equal widths, full height.
- S11.5 Grid: rows × columns as square as possible (cols = ceil(sqrt(n)), rows = ceil(n/cols)), filled left-to-right top-to-bottom, equal cells.
- S11.6 Stack: first frame = whole area; each next = previous moved +32 x, +32 y (downwards on screen) and shrunk by 32 in width and height.
- S11.7 fits(): true iff every frame ≥ window's minimum size; Stack always fits.
- S11.8 Frames are integral (whole points).

## FS12 — Auto and My Layout resolution
- S12.1 Auto → first of Focus, Columns, Grid that fits; else Stack.
- S12.2 My Layout fits iff every saved frame lies inside the visible area and ≥ minimum size; otherwise, or with no saved frames, Auto is resolved instead.
- AT12.a Three windows min width 400 on 1440×900 → Focus.
- AT12.b Three windows min width 1000 on 1440×900 → Stack; Focus/Columns/Grid each have a frame narrower than 1000.

## FS13 — Showing a room
- S13.1 ↵ on a room row (or `clickRow`) closes the palette and shows the room.
- S13.2 Windows not found are skipped.
- S13.3 Frames from the room's layout on the current screen; Auto/My Layout resolved; My Layout uses saved frames.
- S13.4 Each found window is unminimized, moved, raised; main raised last and focused; if main missing, first found window gets focus.
- S13.5 No window found → nothing moved, notification "None of the windows in “<name>” are open" recorded.
- AT13.a Focus room, three windows, 1440×900: window 1 at left two-thirds frame, 2 and 3 stacked in right third; window 2 was minimized and is unminimized; window 1 raised last with focus.
- AT13.b Room whose app quit → no moves, notification with the room's name.

## FS14 — Showing hides everything else
- S14.1 Apps with no found window in the room are hidden.
- S14.2 Other windows of apps that have a found window are minimized.
- S14.3 No window closed (fake window count unchanged).
- AT14.a Room A (X1, X2), app Y open, X3 open: show A → Y hidden, X3 minimized. Show B (X3, Y4) → Y unhidden, X3 and Y4 unminimized, X1 and X2 minimized. Window count unchanged.

## FS15 — Showing sets current room
- S15.1 After showing, `currentRoom` is the room, `lastShown` ≈ now, store on disk reflects it.
- S15.2 Status menu header reads the room name.

## FS16 — New room shown right after creation
- S16.1 After Create Room, the new room is the current room and its windows have been laid out (fake recorded moves).

## FS17 — Tab cycles layouts
- S17.1 Cycle order Auto, Focus, Columns, Grid, My Layout, Stack; non-fitting layouts skipped; My Layout skipped without frames; wraps around; ⇧⇥ goes backwards.
- S17.2 Change persisted immediately.
- S17.3 If the selected room is current, its windows move immediately to new frames.
- S17.4 Footer shows "Here: <resolved layout>" (Auto shows the resolved concrete layout) and hint "⇥ Layout".
- AT17.a Auto room, all layouts fit, no My Layout frames: ⇥ ×5 → Focus, Columns, Grid, Stack, Auto; then ⇧⇥ → Stack; each state persisted on disk.

## FS18 — Layout preview overlay
- S18.1 After opening the palette the preview is hidden (`isPreviewVisible == false`, `preview == nil`).
- S18.2 ⇥ (and ⇧⇥) with a room selected makes the preview visible: area = visible area of the current screen; one card per saved window of the selected room, in window order, keyed by window identity, at the frame LayoutEngine computes for the room's (new) layout; each card carries the application name, the window title, and an application icon; no place numbers.
- S18.3 Cycling again moves the cards to the frames of the next layout (animation duration constant 200 ms).
- S18.4 ↓ / ↑ switch the cards to the newly selected room (same visibility, new windows and frames).
- S18.5 Selecting the Create row hides the preview; closing the palette hides it; reopening starts hidden.
- S18.6 When the selected room is the current room, ⇥ moves its real windows and the preview stays visible with the new frames.
- S18.7 A room whose windows are saved but not open still gets cards (saved windows, no window-system lookups).

## FS19 — ⌃⌥ snapping keys
- S19.1 ⌃⌥← → left half (gap 8 from edges and middle); ⌃⌥→ right half; ⌃⌥↑ top half; ⌃⌥↓ bottom half; ⌃⌥↩ whole area.
- S19.2 Repeating ⌃⌥← while in left half → left third → left two-thirds → back to half (same for →).
- S19.3 Uses the focused window of the fake.

## FS20 — ⌘S tidy recognition
- S20.1 Selected room is current and frames within 24 pt per edge of Focus/Columns/Grid frames → layout set to that layout, windows moved to exact frames, persisted.
- S20.2 Selected room not current → ⌘S does nothing (no writes, no moves).
- S20.3 Footer hint "⌘S Remember mine".

## FS21 — ⌘S My Layout
- S21.1 No tidy match → frames snapped to a 16-pt grid; edges within 16 pt of each other get exactly an 8-pt gap; saved as My Layout frames; layout = My Layout; windows moved to snapped frames; persisted.

## FS22 — Context menu and row buttons
- S22.1 `contextMenuItems(for:)` = Edit Windows…, Rename…, Delete.
- S22.2 Selected row shows "↵" and ⓧ after the key/Current trailer; unselected rows do not.

## FS23 — Delete
- S23.1 ⓧ, Delete menu item, and ⌘⌫ each remove the room and persist.
- S23.2 Deleting the current room clears it.
- S23.3 No window operations recorded.
- S23.4 Selection moves to the row below, or the last row.
- AT23.a Delete current with ⌘⌫ → current nil, header "No room", fake operations empty. Deleting the last row selects the new last row.

## FS24 — Rename
- S24.1 Rename dialog title "Rename “<name>”", text prefilled, buttons Cancel and Rename, from context menu and from the status menu (current room).
- S24.2 Rename enabled iff trimmed text non-empty and no other room has the name (case-insensitive); otherwise message "A room with this name already exists".
- S24.3 Confirm sets name and persists; ↵ = Rename; Esc = Cancel.
- AT24.a Rename Design to "deep work" while Deep Work exists → disabled with message; rename to "Design 2" → persisted.

## FS25 — Edit Windows
- S25.1 Picker in edit mode: title "Edit the windows of “<name>”", button Save Room; found windows preselected in room order; not-found windows omitted.
- S25.2 Clicking a selected card removes it; clicking again appends at end.
- S25.3 Save Room replaces windows in badge order, re-measures minimum sizes, drops My Layout frames iff the window set changed (kept when the same set is reordered? "set" changed → reorder keeps frames), persists, closes.
- S25.4 If the room is current, it is shown again after saving.

## FS26 — ⌘1–9 direct keys
- S26.1 ⌘3 on selected room sets key 3 and persists; a room that had key 3 loses it; pressing the room's own key clears it.
- S26.2 Footer hint "⌘1–9 Key".
- AT26.a A key 3, then B key 3 → A none, B 3; ⌘3 on B → B none; each state on disk.

## FS27 — ⌃⌥1–9 shows the room
- S27.1 Hotkey n shows the room with key n (same effects as showing from the palette).
- S27.2 No room with that key → nothing happens (no operations, current unchanged).

## FS28 — Getting Started
- S28.1 Status menu Getting Started opens the window model: title "Getting Started", four steps with the exact text, closing line, Done closes.
- S28.2 First launch (flag unset in an injected UserDefaults suite) opens it automatically and sets the flag; second launch does not open it.


## FS29 — Footer key hints in one row, two groups
- S29.1 With a room selected, the left group is ["Here: <resolved layout>", "⇥ Layout", "⌘S Remember mine", "⌘1–9 Key"] in that order.
- S29.2 The right group is ["↵ Go", "esc Close"] and is rendered in a lighter color than the left group.
- S29.3 "Here: …" is omitted when no room is selected (empty list, or the Create row selected); the other left hints remain.
- S29.4 The tab hint starts with "⇥" and the view renders it as an arrow-to-bar symbol followed by "Layout".
- S29.5 `footerHints` still lists every hint, left group then right group.

## FS30 — Light appearance
- S30.1 `RoomsApp.appearanceName` is `.aqua` and `RoomsApp.appearance` resolves to a non-nil light appearance; it is applied to `NSApp.appearance` at launch so the palette, picker, Getting Started, and dialogs are light regardless of the system appearance.

## FS31 — Palette drawn per PaletteDesign
- S31.1 `PaletteDesign.panelWidth == 640`, `PaletteDesign.panelCornerRadius == 22`, `PaletteDesign.rowHeight == 64`, `PaletteDesign.selectionHex == "#3B76F6"`, `PaletteDesign.onSelectionHex == "#FFFFFF"`.
- S31.2 Selected row's trailing elements are [trailer, "↵", "ⓧ"] ("⌃⌥1" or "Current" first, omitted when none); unselected rows show only their trailer.
- S31.3 `PaletteDesign.sections == [.searchField, .divider, .list, .keyHints]`: nothing between the list and the key hints, even while the layout preview is visible.
