import QtQuick
import QtQuick.Window
import qs

// A panel: the theme's background, outlined in its border colour.
Rectangle {
  color: Tone.surface()
  border.color: Config.colors.border
  border.width: Config.theme.borderWidth / Screen.devicePixelRatio
  radius: Config.theme.radius
}
