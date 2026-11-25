import QtQuick
import QtTest
import "places.js" as Places

// Where a Stack puts its islands, pure: an input, a body and a bar on a screen 1000 tall, 35 from its edges, 4 apart.
TestCase {
  name: "places"

  function place(heights, shown, cut) {
    return Places.of(heights, shown, cut, 1000, 35, 4);
  }

  function test_fits() {
    const places = place([30, 200, 40], [true, true, true], 1);
    compare(places[2], { y: 925, height: 40 });
    compare(places[1], { y: 721, height: 200 });
    compare(places[0], { y: 687, height: 30 });
  }

  function test_hidden() {
    const places = place([30, 200, 40], [false, true, true], 1);
    compare(places[1], { y: 721, height: 200 });
    compare(places[0].height, 0);
  }

  // Too tall, the body gives up what the input above it needs, which stays within the margin.
  function test_cut() {
    const places = place([30, 2000, 40], [true, true, true], 1);
    compare(places[1].height, 852);
    compare(places[0].y, 35);
  }
}
