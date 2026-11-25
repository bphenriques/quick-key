# docs/src/recipes.md#a-bar-as-islands, over the weather and uptime recipes.
.plugins.uptime = {
  type: "command",
  read: "awk '{ printf \"up %dd %dh\\n\", $1 / 86400, $1 % 86400 / 3600 }' /proc/uptime",
  glyph: "󰘚"
}
| .plugins.weather = { type: "command", read: "curl -sf 'https://wttr.in/Lisbon?format=%t'", glyph: "󰖕" }
| .menu.bar.center = ["weather", "uptime"]
| .menu.splitBar = true
