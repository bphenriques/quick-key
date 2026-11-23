import QtQuick
import QtTest
import "stack.js" as Stack

// What a notification's card shows, for how long and in what order, on plain cards.
TestCase {
  name: "stack"

  function card(fields) {
    return Object.assign({ appName: "App", summary: "", body: "", urgency: 1, hints: {}, appIcon: "", expireTimeout: -1, came: 0, applied: { actions: [], values: {} } }, fields);
  }

  // As the settings name groups: none here but `code`.
  function groupNames(pattern) {
    return pattern.includes("(?<code>") ? ["code"] : [];
  }

  function test_rules() {
    const rules = [
      { match: { category: "^filed$" }, hide: true },
      { match: { app: "^Bank$" }, urgency: "critical", actions: [{ key: "c", desc: "Copy {code}" }, { key: "o", desc: "Open" }] },
      { match: { body: "(?<code>\\d{6})" }, actions: [{ key: "c", desc: "Call" }] },
      { match: { urgency: "^low$" }, timeout: 1 }
    ];
    compare(Stack.rules(card({ hints: { category: "filed" } }), rules, groupNames).hide, true);
    compare(Stack.rules(card({ hints: { category: "other" } }), rules, groupNames).hide, undefined);
    const bank = Stack.rules(card({ appName: "Bank", body: "Your code is 482913." }), rules, groupNames);
    compare(bank.urgency, "critical");
    compare(bank.values.code, "482913");
    // A later action on a key taken before replaces it.
    compare(bank.actions.map(action => action.desc), ["Open", "Call"]);
    compare(Stack.rules(card({ urgency: 0 }), rules, groupNames).timeout, 1);
  }

  // A rule's seconds, within what a timer holds and a millisecond at least, else never for a critical one, else the sender's milliseconds, else the urgency's seconds.
  function test_timeout() {
    const timeouts = { low: 1, normal: 30 };
    const ruled = applied => card({ applied: Object.assign({ actions: [], values: {} }, applied) });
    compare(Stack.timeout(ruled({ timeout: 0.3 }), timeouts), 300);
    compare(Stack.timeout(ruled({ timeout: 0 }), timeouts), 0);
    compare(Stack.timeout(ruled({ timeout: 0.0001 }), timeouts), 1);
    compare(Stack.timeout(ruled({ timeout: 1e10 }), timeouts), 2147483647);
    compare(Stack.timeout(ruled({ urgency: "critical" }), timeouts), 0);
    compare(Stack.timeout(card({ urgency: 2, expireTimeout: 300 }), timeouts), 0);
    compare(Stack.timeout(card({ expireTimeout: 5000 }), timeouts), 5000);
    compare(Stack.timeout(card({ urgency: 0 }), timeouts), 1000);
    compare(Stack.timeout(card({}), timeouts), 30000);
  }

  // Not when the title says it as a whole word, or its icon shows it; a name a rule sets always.
  function test_appShown() {
    compare(Stack.appShown(card({ appName: "Go" }), "Good news", false), "Go");
    compare(Stack.appShown(card({ appName: "Go" }), "Go: built!", false), "");
    compare(Stack.appShown(card({ appName: "Spotify" }), "A song", true), "");
    compare(Stack.appShown(card({ appName: "firefox", applied: { app: "Firefox", actions: [], values: {} } }), "Firefox", true), "Firefox");
    compare(Stack.appShown(card({ applied: { app: "", actions: [], values: {} } }), "Hello", false), "");
  }

  // notify-send -i sends image-path, niri its screenshot as the app icon: a file by path or URL, a name stays a name.
  function test_iconFile() {
    compare(Stack.iconFile(card({ hints: { "image-path": "/tmp/Other shot.png" } })), "/tmp/Other shot.png");
    compare(Stack.iconFile(card({ appIcon: "file:///tmp/My%20Shot.png" })), "/tmp/My Shot.png");
    compare(Stack.iconFile(card({ hints: { image_path: "file://localhost/tmp/a.png" } })), "/tmp/a.png");
    compare(Stack.iconFile(card({ appIcon: "file:///tmp/100%.png" })), "/tmp/100%.png");
    const named = card({ hints: { "image-path": "dialog-information" }, appIcon: "app" });
    compare(Stack.iconFile(named), "");
    compare(Stack.icon(named), "dialog-information");
  }

  // By tag from the same app, a bare true being none; else by what it says.
  function test_twin() {
    const volume = value => card({ summary: "Volume " + value, hints: { "x-dunst-stack-tag": "volume" } });
    verify(Stack.twin(volume(10), volume(20)));
    verify(!Stack.twin(volume(10), card({ appName: "Other", summary: "Volume 20", hints: { "x-dunst-stack-tag": "volume" } })));
    verify(Stack.twin(card({ summary: "Same", body: "said" }), card({ summary: "Same", body: "said" })));
    verify(!Stack.twin(card({ summary: "Same", body: "said" }), card({ summary: "Same", body: "other" })));
    compare(Stack.tag(card({ hints: { "x-canonical-private-synchronous": true } })), "");
  }

  // Critical first, then newest; held still, as they were, newcomers after them by when they came.
  function test_order() {
    const [a, b, c, d] = [1, 2, 3, 4].map(came => card({ came, summary: String(came) }));
    c.urgency = 2;
    compare(Stack.atRest([a, b, c, d]).map(entry => entry.summary), ["3", "4", "2", "1"]);
    const e = card({ came: 6, summary: "6" });
    const f = card({ came: 5, summary: "5" });
    compare(Stack.heldOrder([a, c, d, e, f], [d, b, a]).map(entry => entry.summary), ["4", "1", "3", "5", "6"]);
  }

  // Past keep, the oldest close first, critical ones last, never one spared.
  function test_evicted() {
    const [a, b, c, d, e] = [1, 2, 3, 4, 5].map(came => card({ came, summary: String(came) }));
    a.urgency = 2;
    compare(Stack.evicted([a, b, c, d, e], 3, [b]).map(entry => entry.summary), ["3", "4"]);
    compare(Stack.evicted([a, c, d], 3, []), []);
    compare(Stack.evicted([a, b], 1, [b]).map(entry => entry.summary), ["1"]);
  }

  // The pick moves to the card in its place, the last when it was the last, none when none shows.
  function test_successor() {
    const [a, b, c] = ["a", "b", "c"].map(summary => card({ summary }));
    compare(Stack.successor(b, [a, b, c], [a, c]), c);
    compare(Stack.successor(c, [a, b, c], [a, b]), b);
    compare(Stack.successor(a, [b, c], [b, c]), b);
    compare(Stack.successor(a, [a], []), null);
  }
}
