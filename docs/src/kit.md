# Kit

What the core's surfaces and the plugins are built from; a plugin that needs something new adds it here first. Reach for it before writing anything that draws: most of what reads as inconsistent (two words for one state, a gap that differs, a second spinner) is something drawn beside the kit.

| Need | Take |
|---|---|
| text, a word for a state or a key | `Label`, its words from `Words` |
| a colour, dimming | a `tone` (`Tone`) |
| a size in characters or lines | `Metrics` |
| a glyph or an image | `Icon` |
| a wait | `Spinner` |
| a row to click | `ListItem`, `StatusLine` in it |
| keys: one, a legend, a list | `KeyHint`, `KeyLegend`, `KeyList` |
| text to type or send | `TextField`, `TextArea`, `Prompt` |
| a conversation | `Exchange`, `Bubble` and `Markdown` in it; an answer's Markdown read through `Markup` |
| a surface, an outline | `Panel`, `Surface`, `Pill`, `Divider` |

| Component | Use |
|---|---|
| `Label` | all text, coloured by `tone`: `normal`, `dim`, `primary`, `warning` or `alert`; bold when `strong`, the one to find first (a key, the clock, a heading) |
| `Tone` | the colour of each tone, `dim` being the normal colour at reduced alpha; a panel's background; a tone washed behind something (a highlight, a track) |
| `Metrics` | the font's character width (`cell`) and line height (`line`), for sizes given in characters or lines |
| `Icon` | a glyph or an image in the same square; `monochrome` draws an image in greys |
| `StatusLine` | icon, an optional title that never changes, text (bold when `strong`), and a detail on the right, glyphs before it drawn as icons (a mode, a submenu), then an optional `meter`; with a title the text is a value, right-aligned unless `packed` beside the title, and `valueTone` colours what reports |
| `Words` | the words the surfaces share, one per meaning: the one ellipsis, a conversation's phases as its answer and prompt say them, what a key does in a legend, `allowQuestion` |
| `KeyHint` | a key in its gutter |
| `KeyLegend` | keys a level takes beyond its rows, on one line in its body: only those the state changes, each while it applies (the fixed ones are `?`'s); each key as `KeyHint` shows it, then what it does in a lowercase word or two (`today`, `terminal...`) |
| `KeyList` | keys and what each does, a row each across the menu's columns, as `?` lists them; a click is `picked` |
| `Meter` | a thin level bar |
| `TextField` | text typed in, plain and wrapped, coloured by `tone`; a dim `placeholder` while empty, and `copyOnSelect` to copy what the mouse selects |
| `Markdown` | an agent's answer rendered from its Markdown (`markdown`): tables, lists, emphasis, code, selectable and copied on selection; an image or a link shows its text (links are rows of their own) and `<` itself, so nothing is fetched and no HTML runs |
| `Markup` | what the kit reads in an agent's Markdown, in one place: its `plain` lines (compact), its `safe` form (`Markdown`), its closing `options` and whether it `hasTable` |
| `TextArea` | a `TextField` that grows to `maxLines`, then scrolls to the cursor; its keys reach `keyPressed` first |
| `Prompt` | a line of text to send: its `key` dim while it waits (`TAB` for a level's input), else a glyph, in one column as wide as the key's name, a spinner in their place while `busy` (what it sends to takes no text), then a `TextArea`; a click while waiting reaches `tapped`; its glyph on the column's left edge, where keys start; `keys` a legend on its right (`picked`) |
| `Exchange` | one turn of a conversation, the `question` a `Bubble` on the right and the answer plain on the left, its `text` Markdown, drawn by its `phase` (working with a spinner and `activity` until the answer streams in, answered, choosing with `options` as digit keys while `picking`, waiting, failed in alert with the question faded, stopped); `context` the answer it follows, dim over the question; `steps` dim lines over the answer; with `lines` it is compact, the answer cut there and `overflows` saying what it cannot hold, else it all shows as `Markdown`, with a copy button (`copyable`) and options as rows (`picked`); `next` is what Return does after it, for the prompt under it |
| `Bubble` | a message in a conversation, yours (`mine`) on the right in the theme's `bubble` colour with `bubbleText`, the other's plain on the left, its text on the keys' edge, as wide as its content up to `maximumWidth`, or all of it when `full` (text cut at a line count cannot size it); `faded` for one that did not go through |
| `Spinner` | a wait in one cell, its `mood` saying whose turn it is: `working` turns the braille dots terminals use, `attention` knocks; its own tempo, still when animations are off |
| `Divider` | a line between two groups of rows, in the theme's `border` |
| `ListItem` | a row with hover, click, right click and wheel, highlighted while `current` (a selected day, an event in focus); dims itself when disabled |
| `WheelSteps` | a pointer area that turns the wheel into one step per notch |
| `Surface`, `Pill` | a panel outlined in the theme's `border` and `borderWidth`; a capsule outlined the same, or in its `tone` for a state (recording) |
| `Panel` | a surface the keyboard opens, the menu or a plugin's: a card at the bottom centre, its `bar` floating over its `body` and its `input` under it (with the keys while `inputFocused`), one open at a time, dismissed by a click anywhere else; keys its body leaves reach `keyPressed` |
| `Tip` | names what the pointer rests on (an icon alone) above it, after a moment |
| `Swatch` | a dot, or a bar when stretched, in a colour that is data (a calendar's), dimmed by its tone like the rest |
| `OverlayWindow`, `DismissArea` | a popup above everything; the click-outside catcher under it, one per screen |
| `CornerPill` | a pill top right on every screen while `shown`, fading in and out; `slot` stacks it under the ones above, `hovered` and `clicked` for its pointer |
| `Transient` | shown for a moment on `show()`, held while `held`, ignoring startup's replayed state until `armed` |
| `Fade` | fades a surface in and out over `theme.animationDuration`; `loaded` holds a `LazyLoader` until it has faded out |
| `MenuKeys` | key names as entries declare them (`Ctrl+Left`), their hints, the gutter a key column takes (`gutter`, a character past a letter), and keys for an app's own menu |
| `Glyphs` | the icon set, Material Design from Nerd Fonts, each an escape (`"\u{F05A9}"`) named after its entry; `glyphs` in the config overrides any by that name (`wifi`, `audioDevices`, `batteryLevels`) |

`alert` is only for what needs attention: critical battery, recording, a failed sync or reply; a state you chose (keep awake, do-not-disturb) is `primary`. Outlines stay calm in `border`; tint is for state.

