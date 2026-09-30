# Notification visual design

Exact values for drawing a notification of Rooms, such as "Open <application>, then open “<room name>” again". Points unless stated. Colors are sRGB hex with an optional opacity. The tokens match `palette-design.md`, so a notification looks like part of the ⌥Space palette.

## Tokens

| Token | Value |
|---|---|
| fill | #FAFAFC at 98% (the palette's panelFill) |
| border | #000000 at 8%, 1 pt, inside the radius |
| radius | 16 |
| shadow | the system window shadow of the panel |
| textPrimary | #1C1C1E |
| textSecondary | #6E6E73 |
| accent | #3B76F6 (the palette's selection color) |
| maxWidth | 520 |
| minWidth | 280 |

## Layout

One row, vertically centered, padding 14 top and bottom, 16 left, 20 right.

| Element | Size | Font | Color | Spacing |
|---|---|---|---|---|
| Icon cluster | app icons of the missing applications, up to 4, each 28, radius 7, each overlapping the previous by 8 | — | app icons | 12 to the text |
| Fallback icon (no app icon, or a message without applications) | SF Symbol `exclamationmark.circle.fill`, 24 | regular | accent | 12 to the text |
| Message | wraps to at most 2 lines within maxWidth | 15 medium | textPrimary | — |
| Hint "Rooms" | above the message | 12 regular | textSecondary | 2 above the message |

## Placement and timing

- Horizontally centered on the visible area of the screen the mouse pointer is on, with its top edge 12 below the top of that visible area.
- Fades in over 150 ms, stays 4 seconds, and fades out over 200 ms. A new notification replaces the one showing and restarts the 4 seconds.

## Rules

- The panel is opaque (no translucent material) and uses the light appearance regardless of the system appearance.
- It is drawn above every other window: normal and floating windows, the ⌥Space palette, the window picker, the layout preview overlay, and full-screen applications, on every Space.
- It never takes keyboard focus, and clicks pass through it.
