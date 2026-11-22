import QtQuick
import QtTest
import "keys.js" as Keys

// The key helpers, pure: no shell, no waiting.
TestCase {
  name: "keys"

  function test_label() {
    compare(Keys.label("Ctrl+x"), "C-x");
    compare(Keys.label("Ctrl+Shift+Return"), "C-S-RET");
    compare(Keys.label("Ctrl+Shift+x"), "C-X");
    compare(Keys.label(["Left", "Right"], true), "←→");
    compare(Keys.label(["Ctrl+a", "b"], true), "C-ab");
    compare(Keys.label("Mod+n"), "s-n");
  }

  function test_assign() {
    compare(Keys.assign(["Open", "Off", "Other"], ["x"]), ["o", "f", "t"]);
    compare(Keys.assign(["Xylophone"], ["x"]), ["y"]);
    compare(Keys.assign(["!!"], [], ""), [""]);
  }

  function test_glob() {
    verify(Keys.glob("Firefox*", "Firefox Nightly"));
    verify(!Keys.glob("a.b", "aXb"));
  }

  function test_gutter() {
    compare(Keys.gutter(1), 1);
    compare(Keys.gutter(3), 4);
  }
}
