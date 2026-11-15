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
    "sinkMuted"
    "sourceMuted"
    "keepAwake"
  ];
  actions = [
    "sinkVolume"
    "sinkMute"
    "sourceVolume"
    "sourceMute"
    "brightness"
    "wifi"
    "bluetooth"
    "playPause"
    "track"
    "repeat"
    "shuffle"
    "keepAwake"
    "keyboardLayout"
  ];
  # Actions run per key of a pair (Down and Up), so their entries need two keys.
  pairs = [
    "sinkVolume"
    "sourceVolume"
    "brightness"
    "track"
  ];
  headerItems = [
    "clock"
    "keepAwake"
    "keyboardLayout"
    "battery"
  ];
}
