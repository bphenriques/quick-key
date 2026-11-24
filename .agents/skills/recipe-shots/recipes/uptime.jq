# docs/src/recipes.md#text-of-your-own-in-the-bar, its glyph filled in.
.plugins.uptime = {
  type: "command",
  read: "awk '{ printf \"up %dd %dh\\n\", $1 / 86400, $1 % 86400 / 3600 }' /proc/uptime",
  glyph: "󰘚"
}
| .menu.header.center = ["uptime"]
