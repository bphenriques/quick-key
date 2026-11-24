# docs/src/recipes.md#the-weather, its glyphs filled in.
.plugins.weather = {
  type: "command",
  read: "curl -sf 'https://wttr.in/Lisbon?format=%x+%t' | jq -Rc 'split(\" \") | {value: .[0], text: .[1]}'",
  glyph: "󰖐",
  show: { "o": { glyph: "󰖙" }, "m": { glyph: "󰖕" }, "/": { glyph: "󰖗" }, "//": { glyph: "󰖖" }, "*": { glyph: "󰖘" } }
}
| .menu.header.center = ["weather"]
