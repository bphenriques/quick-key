# Kit

What the core's surfaces and the plugins are built from; a plugin that needs something new adds it here first.

| Component | Use |
|---|---|
| `Label` | all text, coloured by `tone`: `normal`, `dim`, `primary`, `warning` or `alert`; bold when `strong`, the one to find first (a key, the clock, a heading) |
| `Tone` | the colour of each tone, `dim` being the normal colour at reduced alpha; a panel's background; a tone washed behind something (a highlight, a track) |
| `Metrics` | the font's character width and line height, for sizes given in characters or lines |
| `Icon` | a glyph or an image in the same square; `monochrome` draws an image in greys |
| `StatusLine` | icon, an optional title that never changes, text (bold when `strong`), and a detail on the right, glyphs before it drawn as icons (a mode, a submenu), then an optional `meter`; with a title the text is a value, right-aligned unless `packed` beside the title, and `valueTone` colours what reports |
| `KeyHint` | a key in its gutter |
| `KeyLegend` | keys a level takes beyond its rows, on one line in its body: each key as `KeyHint` shows it, then what it does |
| `Meter` | a thin level bar |
| `TextField` | text typed in, plain and wrapped, coloured by `tone`; a dim `placeholder` while empty, and `copyOnSelect` to copy what the mouse selects |
| `TextArea` | a `TextField` that grows to `maxLines`, then scrolls to the cursor; its keys reach `keyPressed` first |
| `Spinner` | a wait in one block cell, its `mood` saying whose turn it is: `working` spins, `attention` knocks; its own tempo, still when animations are off |
| `Divider` | a line between two groups of rows, in the theme's `border` |
| `ListItem` | a row with hover, click, right click and wheel, highlighted while `current` (a selected day, an event in focus); dims itself when disabled |
| `WheelSteps` | a pointer area that turns the wheel into one step per notch |
| `Surface`, `Pill` | a panel outlined in the theme's `border` and `borderWidth`; a capsule outlined the same, or in its `tone` for a state (recording) |
| `Panel` | a surface the keyboard opens, the menu or a plugin's: a card at the bottom centre, its `bar` floating over its `body`, one open at a time, dismissed by a click anywhere else; keys its body leaves reach `keyPressed` |
| `Tip` | names what the pointer rests on (an icon alone) above it, after a moment |
| `Swatch` | a dot, or a bar when stretched, in a colour that is data (a calendar's), dimmed by its tone like the rest |
| `OverlayWindow`, `DismissArea` | a popup above everything; the click-outside catcher under it, one per screen |
| `CornerPill` | a pill top right on every screen while `shown`, fading in and out; `slot` stacks it under the ones above, `hovered` and `clicked` for its pointer |
| `Transient` | shown for a moment on `show()`, held while `held`, ignoring startup's replayed state until `armed` |
| `Fade` | fades a surface in and out over `theme.animationDuration`; `loaded` holds a `LazyLoader` until it has faded out |
| `MenuKeys` | key names as entries declare them (`Ctrl+Left`), their hints, and keys for an app's own menu |
| `Glyphs` | the icon set, Material Design from Nerd Fonts, each an escape (`"\u{F05A9}"`) named after its entry; glyphs other programs own arrive in their feature's `glyphs` (`audio.glyphs`) |

`alert` is only for what needs attention: critical battery, recording, do-not-disturb, a failed sync or reply. Outlines stay calm in `border`; tint is for state.

