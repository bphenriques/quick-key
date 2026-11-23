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
| a listed item (a task, a device) | `ListItem` |
| keys: one, a legend, a list | `KeyHint`, `KeyLegend`, `KeyList` |
| text to type or send | `TextField`, `TextArea`, `Prompt` |
| a conversation | `Exchange`, `Bubble` and `Markdown` in it; an answer's Markdown read through `Markup` |
| a surface, an outline | `Panel`, `Surface`, `Pill`, `Divider` |
| a card that comes and goes (a notification) | `Card` |

| Component | Use |
|---|---|
| `Label` | all text, coloured by `tone`: `normal`, `dim`, `primary`, `warning` or `alert`; bold when `strong`, the one to find first (a heading, the clock, the item in use); a `title` (the clock, a card's summary) at `theme.titleScale` |
| `Tone` | the colour of each tone, `dim` being the normal colour at reduced alpha; a panel's background; a tone washed behind something (a highlight, a track) |
| `Metrics` | the font's character width (`cell`) and line height (`line`), and a title's line (`titleLine`), for sizes given in characters or lines |
| `Icon` | a glyph or an image in the same square; `recolour` draws an image as drawn, in greys, or as its shape in its tone's colour (`tint`, a symbolic icon only; any other goes grey) |
| `StatusLine` | icon, an optional title that never changes, text (bold when `strong`), and a detail on the right, glyphs before it drawn as icons (a mode, a submenu), a `swatch` dot after it, then an optional `meter`; with a title the text is a value, right-aligned unless `packed` beside the title, and `valueTone` colours what reports; its text names a state (`off`, `muted`) only when there is no value |
| `Words` | the words the surfaces share, one per meaning: the one ellipsis, a conversation's phases as its answer and prompt say them, what a key does in a legend, `allowQuestion` |
| `KeyHint` | a key in its gutter |
| `KeyLegend` | keys a level takes beyond its rows, on one line on its bar after a content level's actions: only those the state changes, each while it applies (the fixed ones are `?`'s); each key as `KeyHint` shows it, then what it does in a lowercase word or two (`today`, `terminal...`) |
| `KeyList` | keys and what each does, a row each across the menu's columns, as `?` lists them; a click is `picked` |
| `Meter` | a thin level bar |
| `TextField` | text typed in, plain and wrapped, coloured by `tone`, with a dim `placeholder` while empty |
| `Markdown` | an agent's answer rendered from its Markdown (`markdown`) by `Markup` a piece at a time, so a stream redraws only its last; a selection, within a piece, is copied and reported (`selected`), and `kept` shows it again as its piece is rebuilt |
| `Markup` | what the kit reads in an agent's Markdown, in one place: its `plain` lines (compact), its pieces (`split`, whole blocks gathered to a size), each one's `html` for `Markdown`, its closing `options`, and whether it `hasTable`. The html is rich text of the kit's own making: the text escaped, an image or a link shown by its text, so nothing is fetched and no HTML runs. A table's header is bold over one divider, code sits on a faint wash, a quote dim behind a rule, a heading bold at the body size (as the calendar's month), prose at `theme.lineHeight` |
| `Thumbnail` | a picture by its file path, four lines tall and as wide as its shape, so a screenshot gets no bands |
| `TextArea` | a `TextField` that grows to `maxLines`, then scrolls to the cursor; its keys reach `keyPressed` first |
| `Prompt` | a line of text to send: a column as wide as its `key`'s name, holding the key dim while it waits (`TAB` for a level's input), else a glyph on the column's left edge, and a spinner in their place while `busy` (what it sends to takes no text); then a `TextArea`. A click while waiting reaches `tapped`. `keys` is a legend on its right (`picked`), `detail` a dim value after it |
| `Exchange` | one turn of a conversation: the `question` a `Bubble` on the right, the answer (`text`, Markdown) plain on the left, drawn by its `phase` and `kind` (`Phase`). Working shows a spinner and `activity` until the answer streams in, then a spinner where its copy button goes until done. Blocked shows a question's `options` as digit keys while `picking`, or a permission in warning. Error is in alert, the question faded; idle, once stopped. `context` is the answer it follows, dim over the question, and `steps` dim lines over the answer (an approval you gave). With `lines` it is compact, cut there, `overflows` saying what it cannot hold; else it all shows as `Markdown`, with a copy button (`copyable`) and options as rows (`picked`). `next` is what Return does after it, for the prompt under it (`Words.next`); `kept` and `selected` pass its answer's selection through |
| `Bubble` | a message in a conversation, yours (`mine`) on the right in the theme's `bubble` colour with `bubbleText`, the other's plain on the left, never glyphs, its text on the keys' edge, as wide as its content up to `maximumWidth`, or all of it when `full` (text cut at a line count cannot size it); `faded` for one that did not go through |
| `Spinner` | a wait in one cell, the braille dots terminals turn at their own tempo, still when animations are off |
| `Phase` | work as Rex's Program Status Protocol names it, one vocabulary for every surface: `idle`, `working`, `blocked` on you (with a `kind`), `done`, `error`; `of` reads one a source gave, `tone` draws it (blocked warns, error alerts, done is lit) |
| `Divider` | a line between two parts of one content (the calendar's month and agenda), in the theme's `border`; never between content and its actions |
| `ListItem` | a row with hover, click, right click and wheel, highlighted while `current` (a selected day, an event in focus); dims itself when disabled |
| `WheelSteps` | a pointer area that turns the wheel into one step per notch |
| `Surface`, `Pill` | a panel outlined in the theme's `border` and `borderWidth`; a capsule outlined the same, or in its `tone` for a state (recording) |
| `PlacedRegion` | a blur or input region over an item at a place its holder gives, for an item that what holds it moves (a card in a sliding stack, an island on the bar); empty while the item hides |
| `Card` | a surface that comes and goes on its own. An app's `icon` at a glyph's size (recoloured by `recolour`), its column kept so every card's text starts in one place; a picture on its right, square, three lines tall and cropped to fill (a `Thumbnail` keeps its shape), decoded off the GUI thread; its `title` bold on one line, `aside` (what it is from) on its right; a `body` of two lines; a `meter` with its `meterText`; its `actions` (`{ desc, run }`) below on its `actionSide`, wrapping rather than cut. `tone` alert outlines it, marks it with a glyph and colours its meter. A click is `activated`; a right click or its ✕, shown under the pointer, is `dismissed`. While `keysShown` its `key` shows in a gutter, and while also `current` its actions' keys and `closeKey` in the ✕'s place, washed and outlined in primary; their room is kept at rest, so showing them moves nothing. `footer` takes the actions' place while set (a reply's `Prompt`) |
| `Panel` | a surface the keyboard opens, the menu or a plugin's: at the screen's edge (`menu.edge`, `menu.align`), its `bar` against it (with the top level's right slot on its right when `statuses`), its `body` over it and its `input` over the body (`inputOver`, a level's island) or between the body and the bar (with the keys while `inputFocused`), one open at a time, dismissed by a click anywhere else; keys its body leaves reach `keyPressed` |
| `Panels` | the surfaces the keyboard opens as one stack of their owners: the top one shows, `open` covers or brings one back, `back` shows what it covered, `close` hides them all; and the top level's right slot a plugin's panel's bar repeats |
| `Tip` | names what the pointer rests on (an icon alone) above it, after a moment |
| `Swatch` | a dot, or a bar when stretched, in a colour that is data (a calendar's), dimmed by its tone like the rest |
| `OverlayWindow`, `DismissArea` | a popup above everything; the click-outside catcher under it, one per screen |
| `CornerPill` | a pill on the right of every screen, in the corner away from the menu's edge, while `shown`, fading in and out, stacked under the pills already showing; `hovered` and `clicked` for its pointer |
| `CornerPills` | the corner pills on screen, in the order they showed, which is the order they stack in, each as tall as it draws, and the stack's `height` for what sits under it |
| `Transient` | shown for a moment on `show()`, held while `held`, ignoring startup's replayed state until `armed` |
| `Fade` | fades a surface in and out over `theme.animationDuration`, its `distance` how far a surface travels when `theme.motion` slides it in from its edge; `loaded` holds a `LazyLoader` until it has faded out; the menu appears and closes at once, since its background blur cannot fade with it and a fade-out would hold the keyboard |
| `MenuKeys` | key names as entries declare them (`Ctrl+Left`), their hints, the gutter a key column takes (`gutter`, a character past a letter), and keys for an app's own menu, keeping letters from the labels its app supplies |
| `Glyphs` | the icon set, Material Design from Nerd Fonts, each an escape (`"\u{F05A9}"`) named after its entry; `glyphs` in the config overrides any by that name (`wifi`, `audioDevices`, `batteryLevels`) |
| `Clock` | a date or a time said in `clock.locale`: `time`, `day`, `when`, `recent`, a day's `heading` and a month's `monthHeading` in sentence case, `stale` past `minutes`, the `parse`d and `format`ted forms |

`alert` is only for what needs attention: critical battery, recording, a failed sync or reply; a state you chose (keep awake, do-not-disturb) is `primary`. Tone goes to what reports, never to a label beside it. Outlines stay calm in `border`; tint is for state. Wrapped prose is spaced at `theme.lineHeight`; rows keep their own padding.

