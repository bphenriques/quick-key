# The starter menu with nothing of the machine's own in it (no audio device, network or battery), English dates, the preview's events and no keys hint, as the README's images.
(.menu.entries[] | select(.key == "m")) as $music
| (.menu.bar.right[] | objects | select(.key == "q")) as $session
| .clock = { locale: "en_GB", format: "%a %-d %b  %H:%M" }
| .calendar.file = $events
| .menu.keysHint = false
| .menu.entries = [
    $music,
    { key: "l", desc: "Lock", icon: "󰌾", cmd: "loginctl lock-session" },
    { key: "s", desc: "Screenshot", icon: "󰹑", cmd: "grim" },
    { key: "n", desc: "Night light", icon: "󰖔", cmd: "true" }
  ]
| .menu.bar.right = [
    { key: "i", desc: "Keep awake", action: "keepAwake" },
    { key: "k", desc: "Keyboard layout", status: "keyboardLayout", action: "keyboardLayout" },
    $session
  ]
