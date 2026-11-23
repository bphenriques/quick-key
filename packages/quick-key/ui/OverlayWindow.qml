import Quickshell
import Quickshell.Wayland
import qs

// Floats above everything, fullscreen windows included, reserving no screen space; beside another bar's when `besideBars`.
PanelWindow {
  // theme.edgeMargin, no more than a quarter of its screen, so a large one never pushes a surface off a small screen.
  readonly property real edgeMargin: screen ? Math.min(Config.theme.edgeMargin, screen.width / 4, screen.height / 4) : Config.theme.edgeMargin

  exclusionMode: Config.theme.besideBars ? ExclusionMode.Normal : ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
}
