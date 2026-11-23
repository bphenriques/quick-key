# Notifications

> **Experimental.** Its settings and keys may change between releases, outside what a stable release promises. A notification server is more critical than a menu: keep dunst or mako close by if a lost notification would cost you.

A notification server in the shell's look, in place of dunst or mako. Quickshell speaks the protocol; the plugin decides what shows, for how long, and where. Only one daemon can hold the bus, so turn off `services.dunst` or `services.mako` (the module requires it) and remove their packages: D-Bus starts any daemon whose service file it finds, which can take the bus before the shell does. Another daemon holding it shows as the plugin's error.

The plugin's status is a bell with the count, struck and lit while paused, and a click on it summons the cards. Put it in a slot of the bar, such as `menu.header.right`: `{ key = "n"; desc = "Notifications"; status = "notifications"; }`, beside the starter's ([Extend the starter](recipes.md#extend-the-starter)).

Cards stack in a corner of the focused screen, newest by the corner, critical ones first. A card shows:

- its app's icon, the summary in bold, and the app on its right where nothing else names it (not when the title says it or its icon shows it, so a song's cover keeps it), with when it came once it has waited a minute;
- the body in two lines, as plain text: the server tells senders it takes no markup;
- progress (`value`) as a meter, and a picture (album art, a screenshot) on its right;
- its sender's actions below.

The same notification again, with no tag (same app, summary and body), renews its card rather than adding one, counted on its right (`×2`): it comes to the front, its time and its rule's `run` starting again, as dunst stacks duplicates.

A click opens a card: its app comes to the front (the one window whose app id is its desktop entry or name, when only one is open), and its default action runs, else it is dismissed. `✕` or a right click dismisses it.

A card shows for its sender's time, else its urgency's `timeout`; a critical one stays until dismissed. Time stops while the pointer is on any card, which also holds the stack still, and after `idle` seconds without input; it starts again in full. One sent again, by its id or its stack tag (`x-dunst-stack-tag`, as volume tools send), replaces its card in its place, its rules and its time starting again. One re-sent by its id with nothing changed restarts nothing: Quickshell tells the shell only of changes.

`limit` cards show at once, `+N` counting the rest. While paused, or while a fullscreen window has focus, cards wait, and their time starts once they show; a critical one shows anyway. A struck bell by the corner counts those waiting, except over a fullscreen window. Past `keep` notifications, the oldest close, critical ones only once none other is left to close, and never one on screen while the cards hold still. Pause and the `history` last closed survive a reload and a restart; the cards do not survive a restart (a deploy), as the sender still has them.

```nix
plugins.notifications = {
  corner = "top-right";
  rules = [
    { match = { app = "^niri$"; summary = "Screenshot captured"; }; hide = true; }
    { match.app = "^Alfredo$"; timeout = 0; ignorePause = true; }
    { match.body = "(?<code>\\b\\d{6}\\b)"; actions = [ { key = "c"; desc = "Copy {code}"; cmd = ''wl-copy "$NOTIFICATION_CODE"''; } ]; }
  ];
};
```

## Rules

Rules apply in order, later ones winning. A rule applies when each regular expression in its `match` is found in its field: `app`, `summary`, `body`, `category`, `urgency` or `desktopEntry`. Anchor one with `^…$`. They are JavaScript's, with no inline flags: `[Ss]lack` matches either case. A rule with no `match` applies to all, so `{ run = "env | grep ^NOTIFICATION_ >> /tmp/notifications"; }` logs what each tool sends. A rule can set:

- `app`: the app its card names, shown even where its icon would name it; `""` for none, as for `notify-send`'s own name (`match.app = "^notify-send$"`). Its commands still get the sender's as `NOTIFICATION_APP`.
- `icon`: the card's icon, by its name in the icon theme, in place of its sender's.
- `hide`: drops it, as it arrives or once a replacement matches. No card shows, `C-r` has nothing to bring back, and no `run` runs.
- `silent`: no card: it goes straight to those closed, to bring back or read in the list, its `run` still running (dunst's `skip_display`).
- `timeout`: the seconds it shows; 0, never.
- `urgency` (`low`, `normal`, `critical`): how it shows and lasts.
- `ignorePause`: shows it while paused; a fullscreen window still holds it, as only a critical one shows over one.
- `actions`: its own, each `{ key, desc, cmd, closes, icon }`, `key` a lowercase letter you choose, any but `x`, `icon` a glyph before its label. A sender's own actions show icons when it names them (the protocol's `action-icons`). They come after its reply and before its sender's, whose letters come from their labels. Actions of every matching rule add up, one on a letter an earlier rule took replacing it. Running one dismisses its card; `closes = false` keeps it.
- `default`: what opening it runs, in place of its sender's.
- `run`: a command run as it arrives, not when it is replaced or kept over a reload.

A command gets the notification in its environment, never in its text, as dunst's scripts get `DUNST_*`: `NOTIFICATION_APP`, `NOTIFICATION_SUMMARY`, `NOTIFICATION_BODY`, `NOTIFICATION_URGENCY`, `NOTIFICATION_ID` and `NOTIFICATION_ICON` (a file's path, as a screenshot or album art comes, else an icon name). Each named group of its `match` comes too, upper-cased (`(?<code>\d{6})` as `NOTIFICATION_CODE`), and a `desc` shows it by name (`{code}`). Commands run on the service's `PATH`, so with Nix what they call goes in `programs.quick-key.extraPackages`. The rules are checked as the configuration builds.

There is no sound of its own (a rule's `run` can play one: `run = "pw-play /path/to/sound.oga";`), per-output placement or per-rule colour.

## Keys

Cards never take the keys on their own, so a notification never takes your typing. `summon` gives them the keys where they are, the newest picked, until you let go. Bind it to a compositor key; in niri's config:

```kdl
binds {
    Mod+N { spawn "qs" "-c" "quick-key" "ipc" "call" "notifications" "action" "summon"; }
}
```

With Nix, the same through `exec.ipc`: `Mod+N { spawn-sh "${config.programs.quick-key.exec.ipc} notifications action summon"; }`.

The plugin's `shortcut` only labels that key. Their keys show where they act, and nothing moves. Summoned, waiting cards show too, `limit` at a time, the arrows scrolling past them. The bar under the cards holds the keys the state changes and counts the cards not shown (`+2`). `?` lists the rest.

- A digit picks a card by its place among all, so it holds still, scrolling it into view. `↑↓` move the pick, scrolling past the last one.
- The picked card's letters run its actions. The keys stay, so one summon can clear several.
- `RET` opens it and lets go. `x` dismisses it, the pick moving on.
- `C-X` clears all. `C-r` brings back the last closed, of the `history` kept, unless its sender marked it transient; it stays until dismissed, then goes back among them. `C-p` pauses or resumes.
- `ESC`, or a click beside the cards, lets go.

A key path runs as typing it would: `notifications press "2 x"`. The plugin's actions, for a binding (`notifications action <name>`) or an entry, are `summon`, `invoke` (opens the newest card), `dismiss` (the newest), `clear`, `restore` and `pause`.

As a list, `{ key = "N"; desc = "Notifications"; icon = "<glyph>"; list = "notifications"; }` shows the cards in their order, then those closed struck through, newest first, each by its time, or its day if not today, a critical one by its glyph: a digit opens a card, or brings a closed one back, and its own menu dismisses it.

## Replies

A sender that takes a reply (the protocol's `inline-reply` action) gets one first among its card's actions, on `TAB`. The prompt takes the actions' place, one line that scrolls, so the card keeps its height, and holds the keys until you leave it:

- `RET` sends it. The reply closes the card and lets go, unless its sender keeps it (`resident`): then the keys stay.
- `C-S-RET` sends it and lets go.
- `ESC` clears it; empty, `ESC` goes back to the card's keys.
- A card keeps its own unsent reply until it goes, and its time holds while it has one.
- A card that closes while you type ends the reply, your text going to the clipboard, so none is lost. The bar says so, and the keys do nothing until `ESC`, so the rest of what you type goes nowhere.

