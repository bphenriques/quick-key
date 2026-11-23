.pragma library

// Key names and labels, pure, so a unit test reads them without a shell (tests/unit); MenuKeys hands them on.

// The names an entry key stands for: a single name or a list of them.
function names(key) {
  return typeof key === "string" ? [key] : Array.from(key);
}

// Whether an entry key matches a key name.
function matches(key, name) {
  return names(key).includes(name);
}

// A key Emacs-style: C- Ctrl, M- Alt, s- Super, Shift as the capital (S- otherwise), arrows as symbols; a pair shares its prefix.
function label(key, paired = false) {
  const parts = (paired ? names(key) : names(key).slice(0, 1)).map(shortName);
  const shared = parts.every(part => part.prefix === parts[0].prefix);
  return shared ? parts[0].prefix + parts.map(part => part.key).join("") : parts.map(part => part.prefix + part.key).join("");
}

function shortName(name) {
  const symbols = { Up: "↑", Down: "↓", Left: "←", Right: "→", space: "SPC", Space: "SPC", Tab: "TAB", Backtab: "S-TAB", Return: "RET", BackSpace: "DEL", Escape: "ESC" };
  const [, chord, base] = name.match(/^((?:(?:Ctrl|Alt|Mod|Super|Shift)\+)*)(.*)$/);
  const modifiers = chord.split("+");
  const shift = modifiers.includes("Shift");
  const letter = /^[A-Za-z]$/.test(base);
  // A letter's case is the key's, as the shell names keys (Ctrl+X is Ctrl with Shift held); a compositor's binding (Mod+N) is lower-case unless it names Shift.
  const compositor = modifiers.includes("Mod") || modifiers.includes("Super");
  const key = letter && shift ? base.toUpperCase() : letter && compositor ? base.toLowerCase() : symbols[base] ?? base;
  const prefix = (modifiers.includes("Ctrl") ? "C-" : "") + (modifiers.includes("Alt") ? "M-" : "")
    + (modifiers.includes("Mod") || modifiers.includes("Super") ? "s-" : "") + (shift && !letter ? "S-" : "");
  return { prefix: prefix, key: key };
}

// A key gutter for keys up to `chars` long: a character more past a letter, as a row's spacing alone reads as no gap between words.
function gutter(chars) {
  return chars > 1 ? chars + 1 : chars;
}

// Whether text matches a pattern where * stands for anything.
function glob(pattern, text) {
  const escaped = pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*");
  return new RegExp("^" + escaped + "$").test(text);
}

// One key per label (an app's own menu, a card's actions): its first letter not taken yet (`taken` already is), else one of `fallback`; "" when none is free.
function assign(labels, taken = [], fallback = "0123456789") {
  const used = new Set(taken);
  return labels.map(label => {
    const letters = String(label).toLowerCase().replace(/[^a-z]/g, "") + fallback;
    const key = Array.from(letters).find(letter => !used.has(letter)) ?? "";
    if (key) used.add(key);
    return key;
  });
}
