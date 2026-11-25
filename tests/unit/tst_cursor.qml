import QtQuick
import QtTest
import "cursor.js" as Steps

// Where an arrow takes a cursor, pure: five rows in two columns, the last row short.
TestCase {
  name: "cursor"

  readonly property var all: ["Up", "Down", "Left", "Right"]

  function step(at, name, free = all) {
    return Steps.next(5, 2, at, name, free);
  }

  function test_first() {
    compare(step(-1, "Down"), 0);
    compare(step(-1, "Right"), 0);
    compare(step(-1, "Up"), 4);
    compare(step(-1, "Left"), 4);
  }

  function test_grid() {
    compare(step(0, "Down"), 2);
    compare(step(2, "Right"), 3);
    compare(step(3, "Up"), 1);
    // Row-major, by one past a row's end.
    compare(step(1, "Right"), 2);
    compare(step(2, "Left"), 1);
  }

  function test_edges() {
    compare(step(0, "Up"), 0);
    compare(step(0, "Left"), 0);
    compare(step(4, "Right"), 4);
    compare(step(4, "Down"), 4);
    // Above the short last row, ↓ stays put.
    compare(step(3, "Down"), 3);
  }

  function test_list() {
    compare(Steps.next(3, 1, 1, "Down", ["Up", "Down"]), 2);
    compare(Steps.next(3, 1, 2, "Down", ["Up", "Down"]), 2);
    compare(Steps.next(3, 1, 0, "Up", ["Up", "Down"]), 0);
  }

  // Past the first or last row by ↑↓, where the island beside may take it; never by ←→, nor from none.
  function test_edge() {
    verify(Steps.atEdge(5, 2, 0, "Up"));
    verify(Steps.atEdge(5, 2, 1, "Up"));
    verify(!Steps.atEdge(5, 2, 2, "Up"));
    verify(Steps.atEdge(5, 2, 4, "Down"));
    // Above the short last row, nothing lies below.
    verify(Steps.atEdge(5, 2, 3, "Down"));
    verify(!Steps.atEdge(5, 2, 2, "Down"));
    verify(!Steps.atEdge(5, 2, 0, "Left"));
    verify(!Steps.atEdge(5, 2, -1, "Up"));
    verify(Steps.atEdge(2, 1, 1, "Down"));
  }

  function test_taken() {
    compare(step(0, "Right", ["Up", "Down"]), -1);
    compare(step(0, "Return"), -1);
    compare(step(0, "constructor"), -1);
    compare(Steps.next(0, 2, -1, "Down", all), -1);
  }
}
