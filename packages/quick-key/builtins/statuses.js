.pragma library

// A format with each {field} replaced; a field without a value leaves nothing.
function formatted(format, fields) {
  return format.replace(/\{(\w+)\}/g, (_, name) => fields[name] ?? "").trim();
}

// A status's value over its fields, { text, detail, glyphs }: an entry's format over the status's own, `|` before the detail; with neither, its value().
function value(status, fields, format) {
  const shape = format || status.format;
  if (shape == null) return status.value(fields);
  const [text, detail] = shape.split("|");
  return { text: formatted(text, fields), detail: formatted(detail ?? "", fields) };
}

// Whether a bar draws an item: one showing a status, while it has a glyph, or a text or detail under the item's format. `shape`: the status's (Statuses.of).
function shown(item, shape) {
  if (!item.status) return true;
  const shows = item.format ? value({}, shape.fields, item.format) : shape;
  return !!(item.icon || shape.glyph || shows.text || shows.detail);
}
