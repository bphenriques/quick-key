# The shell's built-in names, one list per table in packages/quick-key/builtins/; the qml test holds the two equal.
{
  statuses = [
    "sink"
    "source"
    "brightness"
    "music"
    "network"
    "bluetooth"
    "tray"
    "calendar"
    "battery"
    "keyboardLayout"
    "keepAwake"
  ];
  lists = [
    "tray"
    "bluetooth"
    "wifi"
    "sinks"
    "sources"
  ];
  states = [
    "wifi"
    "bluetooth"
    "repeat"
    "shuffle"
    "sink-muted"
    "source-muted"
    "keep-awake"
  ];
  actions = [
    "sink-volume"
    "sink-mute"
    "source-volume"
    "source-mute"
    "wifi"
    "bluetooth"
    "play-pause"
    "track"
    "repeat"
    "shuffle"
    "keep-awake"
    "keyboard-layout"
  ];
  # Actions run per key of a pair (Down and Up), so their entries need two keys.
  pairs = [
    "sink-volume"
    "source-volume"
    "track"
  ];
  headerItems = [
    "clock"
    "keepAwake"
    "keyboardLayout"
    "battery"
  ];
}
