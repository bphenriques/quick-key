import qs

// A plugin made of commands, under any name (`type = "command"`); see docs/src/plugins.md.
Plugin {
  id: root

  // Read again once it is done, so the item now in use lights.
  function select(id) {
    call(settings.select, [id], () => refresh());
  }

  function run(id, key) {
    call(settings.run, [id, key], () => refresh());
  }
}
