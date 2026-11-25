# docs/src/recipes.md#a-focus-timer, its glyph filled in.
.plugins.focus = {
  type: "command",
  file: "focus",
  glyph: "󰔛",
  activate: "for m in $(seq 25 -1 1); do echo \"$m min\" > \"$XDG_RUNTIME_DIR/focus\"; sleep 60; done; : > \"$XDG_RUNTIME_DIR/focus\"; notify-send 'Focus is over'"
}
| .menu.bar.center = [{ key: "f", desc: "Focus", status: "focus" }]
