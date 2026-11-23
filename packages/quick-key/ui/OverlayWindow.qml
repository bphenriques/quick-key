import Quickshell
import Quickshell.Wayland
import qs

// Floats above everything, fullscreen windows included, reserving no screen space; beside another bar's when `besideBars`.
PanelWindow {
  exclusionMode: Config.theme.besideBars ? ExclusionMode.Normal : ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
}
