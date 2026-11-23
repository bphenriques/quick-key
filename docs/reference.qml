import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.builtins
import qs.ui

// The docs' reference as Markdown, written to $OUT: the settings and names as the running shell declares them, their comments from the source; docs.nix runs it from the shell's root.
ShellRoot {
  id: root

  // The source online, so a default too long for a table links to its line.
  readonly property string source: Quickshell.env("SOURCE")
  property bool done: false

  // The shipped plugins and theme presets, by folder: QML lists no directory otherwise.
  FolderListModel {
    id: plugins
    folder: "file://" + Quickshell.shellPath("plugins")
    showFiles: false
    onStatusChanged: root.generate()
  }

  FolderListModel {
    id: themes
    folder: "file://" + Quickshell.shellPath("themes")
    nameFilters: ["*.json"]
    onStatusChanged: root.generate()
  }

  Component {
    id: reader
    FileView {
      blockAllReads: true
      printErrors: false
    }
  }

  FileView {
    id: out
    path: Quickshell.env("OUT")
    printErrors: false
    onSaved: Qt.quit()
    onSaveFailed: Qt.exit(1)
  }

  function read(path) {
    const file = reader.createObject(root, { path: Quickshell.shellPath(path) });
    const text = file.text();
    file.destroy();
    return text;
  }

  // What only the source says of each declaration, by its path through the objects holding it: its comment, else with `carry` that of the sibling just above; its type, its value as written, a comment after it, and its line.
  function declarations(file, carry, from) {
    const found = {};
    const open = [];
    const lines = read(file).split("\n");
    let [comment, last] = ["", null];
    for (let index = from ? lines.findIndex(line => line.includes(from)) : 0; index < lines.length; index++) {
      const line = lines[index];
      const indent = line.search(/\S/);
      if (indent < 0) {
        last = null;
        continue;
      }
      while (open.length && open[open.length - 1].indent >= indent) open.pop();
      const note = line.match(/^\s*\/\/ (.*)$/);
      if (note) {
        comment = note[1];
        continue;
      }
      const match = line.match(/^\s*(?:readonly )?(?:property (\S+) (\w+)(?:: (.*))?|"?([\w-]+)"?: (.*))$/);
      if (!match) {
        [comment, last] = ["", null];
        continue;
      }
      const name = match[2] ?? match[4];
      const [value, after] = (match[3] ?? match[5] ?? "").split(/\s+\/\/ /);
      const own = comment || (carry && last?.indent === indent ? last.comment : "");
      found[open.map(parent => parent.name).concat(name).join(".")] = { comment: own, type: match[1] ?? "", value: value.replace(/,$/, ""), after: after ?? "", line: index + 1, file };
      [comment, last] = ["", { indent, comment: own }];
      if (/[{[(]$/.test(value)) open.push({ indent, name });
    }
    return found;
  }

  function code(text) {
    const tick = String(text).includes("`") ? "``" : "`";
    return text === "" ? "" : tick + text + tick;
  }

  // A comment as prose, a pointer into the docs a link.
  function prose(comment) {
    return comment.replace(/docs\/src\/([\w-]+\.md(#[\w-]+)?)/g, "[$1]($1)");
  }

  // Rows as a Markdown table, a column empty in every row left out.
  function table(head, rows) {
    const used = head.map((_, column) => column === 0 || rows.some(row => row[column]));
    const line = cells => "| " + cells.filter((_, column) => used[column]).map(cell => String(cell ?? "").replace(/\|/g, "\\|")).join(" | ") + " |";
    return [line(head), line(head.map(() => "---"))].concat(rows.map(line)).join("\n") + "\n";
  }

  // A default as shown: another setting or a glyph it follows, else its value as JSON; one too long for a table, or holding glyphs a browser's font lacks, left to its line in the source.
  function shown(value, declared) {
    const setting = declared.value.match(/^(?:adapter|Config|root)\.(\w+\.\w+)$/);
    if (setting) return "as " + code(setting[1]);
    const glyph = declared.value.match(/^Glyphs\.(\w+)$/);
    if (glyph) return "glyph " + code(glyph[1]);
    if (value === null || value === undefined || value === "") return "";
    const json = JSON.stringify(value);
    return json.length > 60 || /[-\uDB80-\uDBFF]/.test(json) ? "[in the source](" + source + declared.file + "#L" + declared.line + ")" : code(json);
  }

  function type(value, declared, path) {
    if (declared.type === "int" || Validation.wholes.includes(path)) return "integer";
    return { real: "number", string: "string", bool: "boolean" }[declared.type] ?? (value == null ? "any" : Config.kind(value));
  }

  // What a setting takes beyond its kind, as Validation checks it.
  function allowed(value, path) {
    if (path in Validation.choices) return Validation.choices[path].map(choice => code(JSON.stringify(choice))).join(", ");
    if (path.startsWith("theme.") && Object.keys(Config.colors).includes(path.slice(6))) return "`#rgb`, `#rrggbb` or `#aarrggbb`";
    if (typeof value !== "number") return "";
    const [least, most] = Validation.range(path);
    return most === undefined || most === Infinity ? least + " or more" : least + " to " + most;
  }

  // Rows in a row that differ only by their key share one.
  function merged(rows) {
    const found = [];
    for (const row of rows) {
      const previous = found[found.length - 1];
      if (previous && previous.slice(1).join("\t") === row.slice(1).join("\t")) previous[0] += ", " + row[0];
      else found.push(row.slice());
    }
    return found;
  }

  // Each setting under a group of the config, its own groups' flattened to dotted paths, in the order declared.
  function leaves(group, kinds, prefix) {
    return Object.keys(kinds).reduce((found, key) => found.concat(typeof kinds[key] === "object" ? leaves(group[key], kinds[key], prefix + key + ".") : [{ path: prefix + key, value: group[key] }]), []);
  }

  function settings() {
    const declared = declarations("Config.qml", true, "id: adapter");
    const byLine = (a, b) => declared[a.path].line - declared[b.path].line;
    const groups = Object.keys(Config.declaredKinds).map(path => ({ path })).sort(byLine).map(group => group.path);
    let text = "## Settings\n\nEvery key of `config.json` (`programs.quick-key.settings` with Nix), as the shell declares it. A command given values gets them as `$1`, `$2`.\n\n";
    for (const group of groups) {
      const kinds = Config.declaredKinds[group];
      text += "### " + group + "\n\n";
      if (typeof kinds !== "object") {
        text += prose(declared[group].comment) + "\n\n";
        if (group === "glyphs") text += glyphs();
        continue;
      }
      const rows = leaves(Config[group], kinds, group + ".").sort(byLine).map(({ path, value }) => {
        const parent = path.replace(/\.[^.]*$/, "");
        return [code(path), type(value, declared[path], path), shown(value, declared[path]), allowed(value, path), prose(declared[path].comment || declared[parent]?.comment || "")];
      });
      text += table(["Setting", "Type", "Default", "Allowed", "Description"], merged(rows)) + "\n";
      if (group === "theme") text += presets();
    }
    const renamed = Object.keys(Config.renamed).map(path => [code(path), Config.renamed[path]]);
    if (renamed.length) text += "### Renamed and removed\n\nA config still setting an old key fails its check, saying what to write instead, or that it is gone.\n\n" + table(["Old key", "Instead"], renamed) + "\n";
    return text;
  }

  function presets() {
    const names = Array.from({ length: themes.count }, (_, index) => themes.get(index, "fileBaseName"));
    const palettes = names.map(name => JSON.parse(read("themes/" + name + ".json")));
    const colours = Object.keys(Config.colors).filter(colour => palettes.some(palette => palette[colour]));
    const rows = names.map((name, index) => [code(name)].concat(colours.map(colour => code(palettes[index][colour] ?? ""))));
    return "The presets `theme.name` takes, beside your own:\n\n" + table(["Preset"].concat(colours), rows) + "\n";
  }

  function glyphs() {
    const declared = declarations("ui/Glyphs.qml", false);
    // Its own properties, not those a Singleton has (children) nor its functions.
    const names = Object.keys(Glyphs).filter(name => name in declared).sort((a, b) => declared[a].line - declared[b].line);
    const rows = names.map(name => {
      const [value, at] = [Glyphs[name], declared[name]];
      const kind = Config.kind(value);
      // A list's Nerd Fonts names may sit above it, a map's after each of its keys.
      const font = kind === "map" ? Object.keys(value).map(key => code(key) + " " + (declared[name + "." + key]?.after ?? "")).join(", ") : at.after || (kind === "list" ? at.comment : "");
      return [code(name), kind === "string" ? "glyph" : kind === "list" ? "list of glyphs" : "map of glyphs", font, font === at.comment ? "" : at.comment];
    });
    return table(["Glyph", "Takes", "Default (Nerd Fonts)", "Description"], rows) + "\n";
  }

  // A built-in table's names, with what its source says of each and the columns given: a table where any has a value, else a line of names.
  function names(title, head, builtin, file, columns) {
    const declared = declarations(file, false);
    const rows = Object.keys(builtin).map(name => [code(name)].concat(columns.map(([, of]) => of(builtin[name])), prose(declared["builtin." + name]?.comment ?? "")));
    const text = "### " + title + "\n\n";
    if (rows.some(row => row.slice(1).some(cell => cell))) return text + table([head].concat(columns.map(([head]) => head), "Description"), rows) + "\n";
    return text + rows.map(row => row[0]).join(", ") + "\n\n";
  }

  function entries() {
    const declared = declarations("Validation.qml", false);
    const tables = [["status", "statuses", Statuses], ["list", "lists", Lists], ["state", "states", States]];
    const rows = Object.keys(Validation.fields).map(field => {
      const rule = Validation.fields[field];
      const named = rule.names && tables.find(([, , table]) => Object.keys(table.builtin).join() === Object.keys(rule.names).join());
      const takes = [].concat(rule.kind).join(" or ") + (named ? ": a [" + named[0] + "](#" + named[1] + ") or a plugin" : "");
      const where = [rule.level ? "a level (`submenu`, `list` or `view`)" : "", rule.bar ? "a bar" : "", rule.needs ? "with " + rule.needs.map(code).join(" or ") : "", rule.excludes ? "without " + rule.excludes.map(code).join(" or ") : ""].filter(part => part).join(", ");
      return [code(field), takes, where || "any", prose(declared["fields." + field].comment)];
    });
    return "## Menu entries\n\nWhat an entry in `menu.entries`, a `submenu` or a bar takes, and the built-in names it can use ([Menu](menu.md)).\n\n### Fields\n\n" + table(["Field", "Takes", "On", "Description"], rows) + "\n"
      + names("Statuses", "Status", Statuses.builtin, "builtins/Statuses.qml", [["Fields", status => status.names.map(name => code("{" + name + "}")).join(", ")], ["Format", status => code(status.format ?? "")]])
      + names("Actions", "Action", Actions.builtin, "builtins/Actions.qml", [["Keys", action => action.pair ? "a pair" : ""], ["Lit by", action => code(action.state ?? "")]])
      + names("Lists", "List", Lists.builtin, "builtins/Lists.qml", [])
      + names("States", "State", States.builtin, "builtins/States.qml", [])
      + names("Views", "View", Views.builtin, "builtins/Views.qml", []);
  }

  // A plugin's settings, in its file's order: what it declares, and the common ones it gives a default of its own.
  function pluginSettings(object, base) {
    const declared = declarations(object === base ? "PluginSettings.qml" : "plugins/" + object.name + "/Settings.qml", true);
    const common = declarations("PluginSettings.qml", true);
    const keys = Object.keys(object.settings).filter(key => Config.settable(object.settings, key))
      .filter(key => object === base || !(key in base.settings) || JSON.stringify(object.settings[key]) !== JSON.stringify(base.settings[key]));
    const rows = keys.sort((a, b) => declared[a].line - declared[b].line).map(key => {
      const at = Object.assign({}, common[key], declared[key], { type: declared[key].type || common[key]?.type, comment: declared[key].comment || common[key]?.comment || "" });
      return [code(key), type(object.settings[key], at, ""), shown(object.settings[key], at), prose(at.comment)];
    });
    return rows.length ? table(["Setting", "Type", "Default", "Description"], merged(rows)) + "\n" : "";
  }

  function pluginsReference() {
    const make = (name, path) => ({ name, settings: Qt.createComponent(Quickshell.shellPath(path)).createObject(null) });
    const base = make("", "PluginSettings.qml");
    let text = "## Plugin settings\n\nEvery plugin takes these under `plugins.<name>`, beside its `type`, then its own ([Plugins](plugins.md)).\n\n### Every plugin\n\n" + pluginSettings(base, base);
    for (let index = 0; index < plugins.count; index++) {
      const name = plugins.get(index, "fileName");
      const own = pluginSettings(make(name, "plugins/" + name + "/Settings.qml"), base);
      if (own) text += "### " + name + "\n\n" + own;
    }
    return text;
  }

  function generate() {
    if (done || plugins.status !== FolderListModel.Ready || themes.status !== FolderListModel.Ready) return;
    done = true;
    try {
      out.setText("# Reference\n\n" + settings() + entries() + pluginsReference());
    } catch (error) {
      console.error("reference:", error, error.stack);
      Qt.exit(1);
    }
  }
}
