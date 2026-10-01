# Rooms, Regenerated

A macOS menu bar app that saves a project's windows as a named **room** and restores them in a layout from a ⌥Space palette. It reimplements [Rooms by Sara Gordić](https://github.com/saragordic/rooms). The Swift code is generated from [`rooms.plain`](rooms.plain), a [***plain](https://plainlang.org/) specification that was written and edited only by working with a coding agent.

Open the windows a project needs, press ⌥Space, give them a name, and from then on one keystroke hides everything else and lays that project's windows out on your screen.

<video src="docs/demo.mp4" controls muted width="100%"></video>

[Watch the demo](docs/demo.mp4) (44 s)

## The experiment

This project started from [Rooms by Sara Gordić](https://github.com/saragordic/rooms), an open-source macOS app. I wanted to see whether I could use **regenerative software** to recreate it and then add my own twist, without writing any code myself.

I don't know Swift. So instead of editing code, I described the app's behavior in [`rooms.plain`](rooms.plain), a specification written in [***plain](https://plainlang.org/) that I can read and review. I wrote and updated the specification with [plain-forge](https://github.com/plainlang/plain-forge) and generated the Swift code from it with [pyro](https://github.com/plainlang/pyro), both open-source tools. Every change, whether a bug fix, a design tweak, or a new feature, was made in `rooms.plain` and the code was then regenerated. Nothing in `plain_module/` or `dist/` is edited by hand.

### Key lessons

- **The agent wrote the specification and I only reviewed it.** I used Claude Code with Opus 5.5 and the plain-forge skills. It turned vague bug reports like "the rooms are cropped" and "only Focus and Stack work" into precise, testable requirements, and traced each bug in the running app back to the requirement that caused it.
- **I can explain every behavior without reading Swift.** I don't know Swift, AppKit, or the macOS Accessibility API. The specification states exact messages, sizes, and acceptance tests in plain English, so reviewing it was enough.
- **Write the key requirements in detail before the interview.** I did that, then told the agent to take its recommended defaults instead of asking me questions. The plain-forge q&a took about 25 minutes until the first MVP.
- **Hand over designs as Markdown.** I made a simple design in Figma, had the agent convert it into a `.md` file, and refined it with a few front-end design skills. The results are in [`resources/`](resources).
- **About 20 regenerations and one afternoon got the app to its current state.** After the first full generation, regenerations were fast enough that I tested other parts of the app while the agent fixed a bug.
- **It was fun :)**

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

This repository holds the specification, not the generated code. Regenerate the app from [`rooms.plain`](rooms.plain) with [pyro](https://github.com/plainlang/pyro) first. Pyro writes the Swift package to `plain_module/code/` and copies it to `dist/`. Then run:

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
| `plain_module/code/` | Swift code regenerated from `rooms.plain`. Never edited by hand, and not committed. |
| `plain_module/tests/` | Conformance tests regenerated from `rooms.plain`, one folder per functional spec. Not committed. |
| `dist/` | Copy of the regenerated code to build and run. Not committed. |
| [`docs/`](docs) | The demo video. |
| [`test_scripts/`](test_scripts) | Scripts that prepare the environment and run the unit and conformance tests. |
| [`config.yaml`](config.yaml) | Pyro configuration. |

To change the app, change `rooms.plain` and regenerate it. The tests run against the fake window system, so they never touch your real windows:

```sh
./test_scripts/run_unittests_swift.sh plain_module/code
./test_scripts/prepare_environment_swift.sh plain_module/code
./test_scripts/run_conformance_tests_swift.sh plain_module/code plain_module/tests/<suite>
```

## Credits

- Original idea and app: [Sara Gordić, saragordic/rooms](https://github.com/saragordic/rooms), MIT License.
- Specification language: [***plain](https://plainlang.org/).
- Specification written with Claude Code and [plain-forge](https://github.com/plainlang/plain-forge) (open source).
- Code generated with [pyro](https://github.com/plainlang/pyro) (open source).

## License

[MIT](LICENSE). The original Rooms is © 2026 Sara Gordić, also under the MIT License.
