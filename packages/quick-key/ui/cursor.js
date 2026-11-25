.pragma library

// Where an arrow in `free` takes a cursor over `count` rows laid out row-major in `columns`, by index; -1 for any other key.
// From none (`at` -1) ↓→ land on the first row and ↑← on the last; an edge holds it, so ↓ stays put above a short last row.
function next(count, columns, at, name, free) {
  const by = { Down: columns, Up: -columns, Right: 1, Left: -1 }[name];
  if (!by || !Array.from(free).includes(name) || count === 0) return -1;
  if (at < 0) return by > 0 ? 0 : count - 1;
  return at + by >= 0 && at + by < count ? at + by : at;
}
