import QtQuick
import QtTest
import "tray.js" as Tray

// An entry's `hide` leaves out the tray items it names by id, keeping the rest in order.
TestCase {
  name: "tray"

  readonly property var items: [{ id: "blueman" }, { id: "nm-applet" }, { id: "udiskie" }]

  function test_hide() {
    compare(Tray.shown(items, ["blueman"]).map(item => item.id), ["nm-applet", "udiskie"]);
    compare(Tray.shown(items, ["blueman", "udiskie"]).map(item => item.id), ["nm-applet"]);
    compare(Tray.shown(items, []).length, 3);
    compare(Tray.shown(items, ["blue*", "Blueman"]).length, 3);
  }
}
