# Rooms

A macOS menu bar app that saves a project's windows as a named **room** and brings them back, laid out, from a ⌥Space palette.

Open the windows a project needs, press ⌥Space, give them a name, and from then on one keystroke hides everything else and lays that project's windows out on your screen.

## The experiment

This project started from [Rooms by Sara (@saragordic)](https://github.com/saragordic/rooms), an open-source macOS app. I wanted to see whether I could use **regenerative software** to recreate it and then add my own twist, without writing any code myself.

I don't know Swift. So instead of editing code, I described the app in a natural-language spec that I can read and review: [`rooms.plain`](rooms.plain), written in [***plain](https://codeplain.ai). I rendered that spec into a working Swift app with **\*codeplain**. Every change to the app, whether a bug fix, a design tweak, or a new feature, was made in the spec first and then rendered again. The generated code in `plain_module/` and `dist/` is never edited by hand.

### Key lessons

- **Coding agents are amazing at writing specs.** I used Claude Code with Fable 5 as the model. It interviewed me, turned vague requests ("the rooms are cropped", "only Focus and Stack work") into precise, testable specs, and traced each bug in the running app back to the part of the spec that caused it.
- **I understand everything the app does, even outside my comfort zone.** Despite Swift, AppKit, and the macOS Accessibility API being far outside what I know, I reviewed every spec. Because the specs are plain English, with exact messages, sizes, and acceptance tests, I can explain every behavior of the app without reading a line of Swift.

## Features

### Rooms and the ⌥Space palette
- **Menu bar app** with no Dock icon. The menu shows the current room and offers Show Palette, Edit Windows…, Rename…, Getting Started, and Quit Rooms.
- **⌥Space anywhere** opens the palette on the screen the mouse pointer is on. Esc, ⌥Space again, or a click outside closes it.
- **Room list**, most recently shown first, then rooms never shown in the order they were created. Each row shows the app icons, the room name, its layout, and its window count.
- **Type to filter** rooms by name. When the text isn't an existing room, a **Create “…”** row lets you make one.
- **Create a room:** pick windows in the **window picker**, a grid of live window snapshots. The order you click them sets each window's place, and window 1 is the main window.
- **⌘S saves the windows on screen as a new room** named "Room 1", "Room 2", and so on. Its layout matches how the windows are already arranged, and nothing moves.
- **Edit, rename, delete:** right-click a room for Edit Windows…, Rename…, and Delete. You can also delete with the ⓧ on the selected row or ⌘⌫.

### Showing a room
- **↵ or a click** shows the room. Its windows are unminimized, moved into the room's layout, and raised, and the main window gets keyboard focus.
- **Everything else steps aside.** Other apps are hidden, and other windows of the room's own apps are minimized. Nothing is ever closed.
- **Missing windows are explained, not skipped.** If a room's app is closed, Rooms says "Open A, then open “R” again". If a window is on another desktop, it says "A is on another desktop. Move it to this one, then open “R” again".
- **Full-screen windows** are taken out of full screen automatically before the room is laid out.

### Layouts
- **Auto:** picks the first of Focus, Columns, or Grid that fits the windows, and Stack as a last resort.
- **Focus:** the main window takes the left two thirds, and the others share the right third.
- **Columns:** all windows side by side at equal widths.
- **Grid:** equal cells, as square as the window count allows.
- **Stack:** windows cascaded so every title bar peeks out.
- **⇥ / ⇧⇥** in the palette cycles through every layout. A full-screen **preview overlay** shows where each window will land, and cards glide to their new positions.
- **Adapts to apps that won't shrink.** A window that can't get smaller than its minimum size keeps that size, and the others share the rest of the screen. If the windows still don't fit, they overlap evenly but stay on screen. A notification tells you what was adjusted.
- **Minimum sizes are measured** when a room is saved, waiting for each app to finish resizing. **They're also learned:** if a window refuses to get as small as asked, the size it kept becomes its minimum and the layout is adjusted around it right away.

### Keyboard shortcuts
| Shortcut | Where | What it does |
|---|---|---|
| ⌥Space | anywhere | Toggle the palette |
| ↑ ↓ | palette | Move the selection |
| ↵ | palette | Show the selected room, or create one |
| ⇥ / ⇧⇥ | palette | Next or previous layout, with preview |
| ⌘S | palette | Save the windows on screen as a new room |
| ⌘1–9 | palette | Give the selected room that number; the room that had it swaps with it |
| ⌘⌫ | palette | Delete the selected room |
| ⌃⌥1–9 | anywhere | Jump straight into room 1–9 |
| ⌃⌥← / ⌃⌥→ | anywhere | Snap the focused window to the left or right half; press again for a third, then two thirds |
| ⌃⌥↑ / ⌃⌥↓ | anywhere | Snap to the top or bottom half |
| ⌃⌥↩ | anywhere | Fill the screen |

Rooms are **numbered 1–9 automatically** in the order they were created, so ⌃⌥1–9 works right away. Deleting a room hands its number to the next room without one.

### Design
- A light, opaque palette 640 pt wide with 22 pt rounded corners and 64 pt rows. It grows with its content and never scrolls for 9 rooms or fewer.
- Key hints in the footer: "Here: <layout>", "⇥ Layout", "⌘S New room", "⌘1–9 Key", and "↵ Go" and "esc Close" on the right.
- Notifications use the same design as the palette. They show the icons of the apps involved and sit above every window, desktop, and full-screen app.
- Always the light appearance, whatever the system setting.
- The exact design values live in [`resources/`](resources): the palette, the layout preview, and the notification designs.

### Getting Started
A short guide opens on first launch, and any time from the menu bar. It walks through creating your first room and switching layouts.

## Running it

Requirements: macOS 14 or newer and the Swift toolchain (Xcode or the command-line tools).

```sh
cd dist
swift run Rooms
```

On first use, macOS asks for two permissions:
- **Accessibility** (required), to list, move, and hide windows. Rooms offers to open the right System Settings pane.
- **Screen Recording** (optional), for window snapshots in the picker. Without it, the picker shows app icons instead.

## How the project is organized

| Path | What it is |
|---|---|
| [`rooms.plain`](rooms.plain) | **The source of truth.** The whole app as a natural-language spec: concepts, implementation and test requirements, functional specs, and acceptance tests. |
| [`resources/`](resources) | Design documents the spec links to (palette, layout preview, notification). |
| `plain_module/code/` | Swift code rendered from the spec. Never edited by hand. |
| `plain_module/tests/` | Conformance tests rendered from the spec, one folder per functional spec. |
| `dist/` | Copy of the rendered code to build and run. |
| [`test_scripts/`](test_scripts) | Scripts that prepare the environment and run the unit and conformance tests. |
| [`config.yaml`](config.yaml) | Renderer configuration. |

To change the app, change `rooms.plain` and render it again. The tests run against the fake window system, so they never touch your real windows:

```sh
./test_scripts/run_unittests_swift.sh plain_module/code
./test_scripts/prepare_environment_swift.sh plain_module/code
./test_scripts/run_conformance_tests_swift.sh plain_module/code plain_module/tests/<suite>
```

## Credits

- Original idea and app: [saragordic/rooms](https://github.com/saragordic/rooms).
- Spec language and rendering: [***plain / *codeplain](https://codeplain.ai).
- Specs written with Claude Code.
