import QtQuick
import qs
import qs.ui

// The wallpaper last set, by name: its state's text (watch, read or file) is the wallpaper's path or name.
Plugin {
  glyph: Glyphs.wallpaper
  text: (state.text ?? "").replace(/^.*\//, "").replace(/\.[^.]+$/, "")
}
