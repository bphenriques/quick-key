.pragma library

// The tray's items but those `hide` names by id (an entry's `hide`), so a unit test reads it without a tray.
function shown(items, hide) {
  return items.filter(item => !hide.includes(item.id));
}
