import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.widgets
import qs.widgets.menu

ShellRoot {
  // Singletons are created on first use: Config must load before any surface needs it, Tray must host before apps register, Power must have UPower's answer before the menu first opens, Calendar reminds with the menu closed, plugins load, and CornerPills exists before a reload tears a plugin's pill down, which would otherwise make it in no generation.
  Component.onCompleted: {
    Config.theme;
    Tray.items;
    Power.present;
    Calendar.enabled;
    Validation.problems;
    Plugins.get;
    CornerPills.order;
  }

  Menu {}

  Osd {}

  KeepAwakeInhibitor {}
}
