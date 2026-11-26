import QtQuick
import QtTest
import "statuses.js" as Statuses

// What a status shows under a format, and whether a bar draws an item: what its view shows and its cursor stops on alike.
TestCase {
  name: "statuses"

  readonly property var blank: ({ glyph: "", text: "", detail: "", fields: {} })

  function test_formatted() {
    compare(Statuses.formatted("{title} · {when}", { title: "Lunch", when: "13:00" }), "Lunch · 13:00");
    compare(Statuses.formatted("{none} x", {}), "x");
    compare(Statuses.value({ format: "{a}|{b}" }, { a: "A", b: "B" }, ""), { text: "A", detail: "B" });
  }

  function test_shown() {
    // An item showing no status draws: its icon, its label.
    verify(Statuses.shown({ desc: "Tray" }, blank));
    // A status with nothing to show stays out, unless the entry gives it an icon.
    verify(!Statuses.shown({ status: "battery" }, blank));
    verify(Statuses.shown({ status: "battery", icon: "x" }, blank));
    verify(Statuses.shown({ status: "clock" }, Object.assign({}, blank, { glyph: "g" })));
    verify(Statuses.shown({ status: "clock" }, Object.assign({}, blank, { text: "12:00" })));
    // A format decides what it shows: fields left empty draw nothing.
    const next = Object.assign({}, blank, { text: "Lunch", fields: { title: "", when: "" } });
    verify(!Statuses.shown({ status: "next", format: "{title}|{when}" }, next));
    verify(Statuses.shown({ status: "next", format: "{title}|{when}" }, Object.assign({}, next, { fields: { when: "13:00" } })));
  }
}
