# Kit

What the core's surfaces and the plugins are built from; a plugin that needs something new adds it here first. Reach for it before writing anything that draws: most of what reads as inconsistent (two words for one state, a gap that differs, a second spinner) is something drawn beside the kit.

| Need | Take |
|---|---|
| text, a word for a state or a key | `Label`, its words from `Words` |
| a colour, dimming | a `tone` (`Tone`) |
| a size in characters or lines | `Metrics` |
| a glyph, an image or a wait | `Icon` |
| a row to click | `ListItem`, `StatusLine` in it |
| a listed item (a task, a device) | `ListItem` |
| keys: one, a legend, a list | `KeyHint`, `KeyLegend`, `KeyList` |
| arrows over rows, a list or a grid | `Cursor` |
| text to type or send | `TextArea`, `Prompt` |
| a conversation (`qs.ui.conversation`) | a `Thread` of `Exchange`s, `Bubble` and `Markdown` in each; an answer's Markdown read through `Markup` |
| a surface the keyboard opens | a `Stack` of `Island`s |
| an outline | `Surface`, `Pill`, `Divider` |

A `Stack` places its islands against the screen's edge; each `Island` is one surface, whose rows `Cursor` moves over.

| Component | Use |
|---|---|
| `Label` | all text, coloured by `tone`: `normal`, `dim`, `primary`, `warning` or `alert`; bold when `strong`, the one to find first (a heading, the clock, the item in use) |
| `Tone` | the colour of each tone, `dim` being the normal colour at reduced alpha; a panel's background; a tone washed behind something (a highlight, a track) |
| `Metrics` | the font's character width (`cell`) and line height (`line`), for sizes given in characters or lines; the kit's fixed sizes (a row's padding, the gap between columns, a meter, the pop-up's level) |
| `Icon` | a glyph or an image in the same square; `recolour` draws an image as drawn, in greys, or as its shape in its tone's colour (`tint`, a symbolic icon only; any other goes grey); `busy` puts a wait in its place, the braille dots terminals turn at their own tempo, still when animations are off |
| `StatusLine` | icon, an optional title that never changes, text (bold when `strong`), and a detail on the right, glyphs before it drawn as icons (a mode, a submenu), a `swatch` dot after it, then an optional `meter`; with a title the text is a value, right-aligned unless `packed` beside the title, and `valueTone` colours what reports; its text names a state (`off`, `muted`) only when there is no value |
| `Words` | the words the surfaces share, one per meaning: the one ellipsis, a conversation's phases as its answer and prompt say them, what a key does in a legend |
| `KeyHint` | a key in its gutter, never narrower than the key, dim unless `live` (where what it sits on has the keys) |
| `KeyLegend` | keys a level takes beyond its rows, on one line on its bar after a content level's actions: only those the state changes, each while it applies (the fixed ones are `?`'s, unless a `legend` names them); each key as `KeyHint` shows it, then what it does in a lowercase word or two (`today`, `terminal...`) |
| `KeyList` | keys and what each does, a row each |
| `Cursor` | the row the arrows are on, by id, over rows laid out row-major in `columns`: `↓↑` a row and `←→` one, only those `free` names (what its owner leaves free), the first from `from` (the item in use), else onto the first row or the last, stopping at the edges; `key` moves it, `point` puts it on a row or none, and its owner says what `RET` runs; pure, in `cursor.js` |
| `Meter` | a thin level bar |
| `Markdown` | an agent's answer rendered from its Markdown (`markdown`) by `Markup` a piece at a time, so a stream redraws only its last; a selection, within a piece, is copied and reported (`selected`), and `kept` shows it again as its piece is rebuilt |
| `Markup` | what the kit reads in an agent's Markdown, in one place: its `plain` lines (compact), its pieces (`split`, whole blocks gathered to a size), each one's `html` for `Markdown`, and whether it `hasTable`. The html is rich text of the kit's own making: the text escaped, an image or a link shown by its text, so nothing is fetched and no HTML runs. A table's header is bold over one divider, code sits on a faint wash, a quote dim behind a rule, a heading bold at the body size (as the calendar's month), prose at `theme.lineHeight` |
| `TextArea` | text typed in, plain and wrapped, with a dim `placeholder` while empty, growing to `maxLines`, then scrolling to the cursor; its keys reach `keyPressed` first |
| `Prompt` | a line of text to send: a column as wide as its `key`'s name, holding the key dim while it waits (`TAB` for a level's input), else a glyph on the column's left edge, and a spinner in their place while `busy` (what it sends to takes no text); then a `TextArea`. Return sends its text (`sent`), in the background with Ctrl+Shift, unless `sends` is off (a filter). A click while waiting reaches `tapped`. `keys` is a legend on its right (`picked`), `detail` a dim value after it |
| `Exchange` | one turn of a conversation: the `question` a `Bubble` on the right, the answer (`text`, Markdown) plain on the left, drawn by its `phase` (`Phase`) and `kind`. Working shows a spinner and `activity` until the answer streams in, then a spinner where its copy button goes until done. Blocked shows a permission in warning, in plain text: its title is the agent's command. Error is in alert, the question faded; idle, once stopped. `steps` are dim lines over the answer (an approval you gave). With `lines` it is compact, cut there, `overflows` saying what it cannot hold; else it all shows as `Markdown`, with a copy button (`copyable`). `kept` and `selected` pass its answer's selection through |
| `Bubble` | a message in a conversation, yours (`mine`) on the right in the theme's `bubble` colour with `bubbleText`, the other's plain on the left, never glyphs, its text on the keys' edge, as wide as its content up to `maximumWidth`, or all of it when `full` (text cut at a line count cannot size it); `faded` for one that did not go through |
| `Thread` | a conversation's turns, its `delegate` each, built only where they show and laid out from the newest up, so it rests at its end; what scrolled away above fades out; `page` scrolls most of a view up or down; empty, it says `emptyText` in `emptyTone` |
| `Phase` | work as Rex's Program Status Protocol names it, one vocabulary for every surface: `idle`, `working`, `blocked` on you, `done`, `error`; `of` reads one a source gave, `tone` draws it (blocked warns, error alerts, done is lit) |
| `Divider` | a line between two parts of one content (the calendar's month and agenda), in the theme's `border`; never between content and its actions |
| `ListItem` | a row with hover, click, right click and wheel, highlighted while `current` (a selected day, an event in focus); dims itself when disabled |
| `WheelSteps` | a pointer area that turns the wheel into one step per notch |
| `Surface`, `Pill` | a panel outlined in the theme's `border` and `borderWidth`; a capsule outlined the same, or in its `tone` for a state (recording) |
| `PlacedRegion` | a blur or input region over an item at a place its holder gives, for an item that what holds it moves (a part of a split island); empty while the item hides |
| `Stack` | a surface the keyboard opens, the menu or a plugin's: its `islands` listed top to bottom, the last against the screen's bottom edge, centred and as wide as `width` lets the screen (`room`); the island marked `cut` gives up what the screen cannot hold past the others (pure, in `places.js`). One open at a time, dismissed by a click anywhere else; the island `focus` names has the keys, and keys it leaves reach `keyPressed` |
| `Island` | one surface of a `Stack`, hidden unless `shown`: its `content`, as wide as its `width` (else the `Stack`'s), `padding` above and below, the theme's padding plus `inset` on its sides (a row's, so key columns line up), between `minimumHeight` and `maximumHeight` tall (past it, cut as the screen cuts it), and while `holdKey` stays set the tallest it has been, its content against the screen's edge when shorter; when `split`, a surface behind each item its content lists in `parts` instead (a bar as islands); a click on it reaches `clicked`, a right click `secondaryClicked` |
| `Panels` | the surfaces the keyboard opens as one stack of their owners: the top one shows, `open` covers or brings one back, `back` shows what it covered, `close` hides them all; and the top level's right slot a plugin's panel's bar repeats |
| `Tip` | names what the pointer rests on (an icon alone), or shows text cut to fit whole, above it, after a moment |
| `Swatch` | a dot, or a bar when stretched, in a colour that is data (a calendar's), dimmed by its tone like the rest |
| `OverlayWindow`, `DismissArea` | a popup above everything, `edgeMargin` from its screen's edge (`theme.edgeMargin`, no more than a quarter of the screen); the click-outside catcher under it, one per screen |
| `CornerPill` | a pill in the top-right corner of every screen while `shown`, fading in and out, stacked under the pills already showing; `hovered` and `clicked` for its pointer |
| `CornerPills` | the corner pills on screen, in the order they showed, which is the order they stack in, each as tall as it draws |
| `Transient` | shown for a moment on `show()`, held while `held`, ignoring startup's replayed state until `armed` |
| `Fade` | fades a surface in and out over `theme.animationDuration`; `loaded` holds a `LazyLoader` until it has faded out; the menu appears and closes at once, since its background blur cannot fade with it and a fade-out would hold the keyboard |
| `MenuKeys` | key names as entries declare them (`Ctrl+Left`), their hints, the gutter a key column takes (`gutter`, a character past a letter), and keys for an app's own menu, keeping letters from the labels its app supplies |
| `Glyphs` | the icon set, Material Design from Nerd Fonts, each an escape (`"\u{F05A9}"`) named after its entry; `glyphs` in the config overrides any by that name (`wifi`, `audioDevices`, `batteryLevels`) |
| `Clock` | a date or a time said in `clock.locale`: `time`, `day`, `when`, `recent`, a day's `heading` and a month's `monthHeading` in sentence case, `stale` past `minutes`, a day `moved` by years, months and days, the files' `dayKey` and `minuteKey` and their `parse`; pure, in `clock.js`, from a given now |

`alert` is only for what needs attention: critical battery, recording, a failed sync or reply; a state you chose (keep awake, do-not-disturb) is `primary`. Tone goes to what reports, never to a label beside it. Outlines stay calm in `border`; tint is for state. Wrapped prose is spaced at `theme.lineHeight`; rows keep their own padding.

