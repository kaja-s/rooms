# Layout preview overlay design

Exact values for the ghost window cards drawn on the screen while cycling layouts. Points unless stated.

## Tokens

| Token | Value |
|---|---|
| overlayFill | transparent |
| cardFill | #F2F2F4 at 96% |
| cardBorder | #4A8AF4, 1.5 pt, inside the radius |
| cardRadius | 10 |
| cardShadow | none |
| titleBarHeight | 28 |
| dot | 6 pt circle, #C7C7CC, three dots starting at x 12, 6 apart |
| appName | 12 semibold, #1C1C1E, 10 after the dots |
| windowTitle | "— <window title>", 12 regular, #6E6E73, 6 after the app name; omitted when the title is empty |
| appIcon | 64, centered in the card |
| motion | frame changes animate over 200 ms, ease in and out |

## Rules

- One card per window, at exactly the frame the layout gives it, in AppKit screen coordinates.
- Cards carry no place numbers and no other text.
- The overlay covers the visible area of the current screen, ignores mouse events, and sits above every window except the palette.
