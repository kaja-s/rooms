# Palette visual design

Exact values for drawing the ⌥Space palette. Points unless stated. Colors are sRGB hex with an optional opacity.

## Tokens

| Token | Value |
|---|---|
| panelWidth | 640 |
| panelRadius | 22 |
| panelFill | #FAFAFC at 98% |
| panelBorder | #000000 at 8%, 1 pt, inside the radius |
| panelShadow | the system window shadow of the panel, refreshed whenever the panel resizes |
| horizontalInset | 24 |
| textPrimary | #1C1C1E |
| textSecondary | #6E6E73 |
| textTertiary | #AEAEB2 |
| divider | #E5E5EA |
| selection | #3B76F6 |
| onSelection | #FFFFFF |
| onSelectionMuted | #FFFFFF at 85% |
| iconSlotWidth | 100 |

## Elements

| Element | Size | Font | Color | Spacing |
|---|---|---|---|---|
| Search row | height 72 | — | — | horizontalInset left and right |
| Search icon | SF Symbol `door.left.hand.open`, 22 | regular | textSecondary | 12 to the field |
| Search field | fills the row | 28 regular | textPrimary; placeholder "Go to a room" in the system placeholder color | — |
| Divider | 1 pt | — | divider | inset horizontalInset; 8 above the list |
| List | — | — | — | inset 12 on every side; 4 between rows |
| Row | fixed height 64, radius 12 | — | see states | horizontal padding 14 |
| Icon cluster | up to 4 icons of 22, radius 6, each overlapping the previous by 6 | — | app icons | fixed slot iconSlotWidth, left aligned |
| Room name | — | 17 medium | textPrimary | 2 above the subtitle |
| Subtitle "<layout> · <n> windows" | — | 14 regular | textSecondary | — |
| Trailer ("⌃⌥n" or "Current") | — | 14 regular | textSecondary | right aligned; 14 before ↵ |
| Return glyph "↵" | — | 14 regular | inherits | 14 before ⓧ |
| Delete button ⓧ | 20 | SF Symbol `xmark.circle.fill` | see states | — |
| Create row | height 64 | 17 medium | textPrimary; SF Symbol `plus.circle` 22 textSecondary in the icon slot | as a row |
| Empty state text | block height 64 | 15 regular | textSecondary | centered in the block |
| Footer | height 44 | 14 regular | left group textSecondary, right group textTertiary | horizontalInset; 16 between hints |
| Tab hint | SF Symbol `arrow.right.to.line` 11 medium + "Layout" | 14 regular | inherits | 4 between symbol and text |

## States

| State | Row fill | Name | Subtitle | Trailer | ↵ | ⓧ |
|---|---|---|---|---|---|---|
| Unselected | none | textPrimary | textSecondary | textSecondary | hidden | hidden |
| Selected | selection, radius 12 | onSelection | onSelectionMuted | onSelectionMuted | onSelection | white circle, selection-colored × |
| Current (unselected) | none | textPrimary | textSecondary | "Current" textSecondary | hidden | hidden |
| Create row (selected) | selection | onSelection | — | — | onSelection | hidden |

## Rules

- Nothing is drawn between the list and the footer.
- The panel is opaque (no translucent material) and does not change with the system appearance.
- The panel height is the sum of its content; it never scrolls for 9 rooms or fewer.
- Panel height = search row 72 + divider 1 + 8 + list top inset 12 + list content + list bottom inset 12 + footer 44, that is 149 + list content.
- List content for n rows (the Create row counts as a row) = 64 × n + 4 × (n − 1); for the empty state it is the empty state block, 64.
- The panel window is exactly the panel height; the rounded panelRadius shape is fully inside it, so all four corners are visible.
