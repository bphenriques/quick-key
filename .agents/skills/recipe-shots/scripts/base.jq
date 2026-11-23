# The starter menu with nothing of the machine's own in it (no audio device, network or battery), English dates and the preview's events.
(.menu.entries[] | select(.key == "m")) as $music
| (.menu.header.right[] | objects | select(.key == "q")) as $session
| .clock = { locale: "en_GB", format: "%a %-d %b  %H:%M" }
| .calendar.file = $events
| .menu.entries = [
    $music,
    { key: "l", desc: "Lock", icon: "󰌾", cmd: "loginctl lock-session" },
    { key: "s", desc: "Screenshot", icon: "󰹑", cmd: "grim" },
    { key: "n", desc: "Night light", icon: "󰖔", cmd: "true" }
  ]
| .menu.header.right = [
    { key: "i", desc: "Keep awake", action: "keepAwake" },
    { key: "k", desc: "Keyboard layout", status: "keyboardLayout", action: "keyboardLayout" },
    $session
  ]
