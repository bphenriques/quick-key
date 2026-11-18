# Kit

What the core's surfaces and the plugins are built from; a plugin that needs something new adds it here first.

| Component | Use |
|---|---|
| `Label` | all text, coloured by `tone`: `normal`, `dim`, `primary`, `warning` or `alert` |
| `Tone` | the colour of each tone, `dim` being the normal colour at reduced alpha; a panel's background; a tone washed behind something (a highlight, a track) |
| `Metrics` | the font's character width and line height, for sizes given in characters or lines |
| `Icon` | a glyph or an image in the same square; `monochrome` draws an image in greys |
| `StatusLine` | icon, an optional title that never changes, text, and a detail on the right, glyphs before it drawn as icons (a mode, a submenu), then an optional `meter`; with a title the text is a value, right-aligned unless `packed` beside the title, and `valueTone` colours what reports |
| `KeyHint` | a key in its gutter |
| `KeyLegend` | keys a level takes beyond its rows, on one line in its body: each key as `KeyHint` shows it, then what it does |
| `Meter` | a thin level bar |
| `TextField` | text typed in, plain and wrapped, coloured by `tone`; a dim `placeholder` while empty, and `copyOnSelect` to copy what the mouse selects |
| `TextArea` | a `TextField` that grows to `maxLines`, then scrolls to the cursor; its keys reach `keyPressed` first |
| `Spinner` | a wait in one block cell, its `mood` saying whose turn it is: `working` spins, `attention` knocks; its own tempo, still when animations are off |
| `Divider` | a line between two groups of rows |
| `ListItem` | a row with hover, click, right click and wheel, highlighted while `current` (a selected day, an event in focus); dims itself when disabled |
| `WheelSteps` | a pointer area that turns the wheel into one step per notch |
| `Surface`, `Pill` | a panel outlined in the theme's `border` and `borderWidth`; a capsule outlined in its tone |
| `Swatch` | a dot, or a bar when stretched, in a colour that is data (a calendar's), dimmed by its tone like the rest |
| `Shadow` | a shadow like niri's default, for a surface inside a larger window, drawn only outside it so its background blur shows through |
| `OverlayWindow`, `DismissArea` | a popup above everything; the click-outside catcher under it |
| `CornerPill` | a pill top right on every screen while `shown`, fading in and out; `slot` stacks it under the ones above, `hovered` and `clicked` for its pointer |
| `Transient` | shown for a moment on `show()`, held while `held`, ignoring startup's replayed state until `armed` |
| `Fade` | fades a surface in and out over `theme.animationDuration`; `loaded` holds a `LazyLoader` until it has faded out |
| `MenuKeys` | key names as entries declare them (`Ctrl+Left`), their hints, and keys for an app's own menu |
| `Glyphs` | the icon set, Material Design from Nerd Fonts, each an escape (`"\u{F05A9}"`) named after its entry; glyphs other programs own arrive in their feature's `glyphs` (`audio.glyphs`) |

`alert` is only for what needs attention: critical battery, recording, do-not-disturb, a failed calendar sync.

