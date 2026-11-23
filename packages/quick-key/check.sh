# The design rules a text search can hold (AGENTS.md), run on every build from the shell's root.
failed=0
fail() {
  printf '%s\n' "$1" >&2
  failed=1
}

# Rule 12: a plugin is a folder holding all of it, its file rooted at Plugin and every setting it reads in its Settings.qml.
for file in plugins/*.qml; do
  [ -e "$file" ] && fail "$file: a plugin is a folder, plugins/<name>/"
done
for dir in plugins/*/; do
  name=$(basename "$dir")
  grep -qs '^Plugin {' "$dir${name^}.qml" || fail "$dir: no ${name^}.qml rooted at Plugin"
  grep -qsE '^\s*(CornerPill|OverlayWindow|PanelWindow|LazyLoader|Variants|Rectangle|Row|Column|Item|Image|Label|Icon) \{' "$dir${name^}.qml" && fail "$dir${name^}.qml: draws; its views go in their own files (views)"
  grep -qs '^PluginSettings {' "${dir}Settings.qml" || fail "$dir: no Settings.qml rooted at PluginSettings"
  grep -qsE 'property [a-z]+ type\b' "${dir}Settings.qml" && fail "$dir: a setting named type, which names the plugin's implementation"
  for key in $(grep -rhoE '\bsettings\.[a-zA-Z]+' "$dir" | sed 's/^settings\.//' | sort -u); do
    grep -qsE "property [a-z]+ $key\b" "${dir}Settings.qml" PluginSettings.qml || fail "$dir: reads settings.$key, which Settings.qml does not declare"
  done
done

# Plugins and the built-in tables sit under the surfaces, never reaching into them.
for file in $(grep -rl '^import qs\.widgets' --include='*.qml' plugins builtins); do
  fail "$file: imports the core's surfaces"
done

# Compositor: only Compositor and plugins reach a backend.
for file in $(grep -rlE '\bNiri\.' --include='*.qml' . | grep -vE '^\./(services/Compositor\.qml|services/compositor/|plugins/)'); do
  fail "$file: reaches niri past Compositor"
done

# One-way data flow: a view never writes a model's or a plugin's state; it calls the model's functions.
for file in $(grep -rlE '\b(menu|model|plugin)\.[A-Za-z_.]+\s*=[^=]' --include='*.qml' widgets plugins | grep -vE 'Model\.qml$'); do
  fail "$file: a view writes its model's state"
done

# Rule 9: text renders through Label.
for file in $(grep -rlE '^\s*Text \{' --include='*.qml' . | grep -v '^\./ui/Label\.qml$'); do
  fail "$file: Text outside Label"
done

# Rule 11: glyphs go through Icon, never into text or a detail.
for file in $(grep -rlE '(text|detail|fallbackDetail): .*Glyphs\.' --include='*.qml' . | grep -v '^\./ui/Icon\.qml$'); do
  fail "$file: a glyph drawn as text"
done

# Rule 11: a widget never picks a theme colour itself; tones and the kit do.
for file in $(grep -rlE 'Config\.(theme|colors)\.(primary|foreground|background|alert|warning)\b' --include='*.qml' . | grep -vE '^\./(Config\.qml|ui/)'); do
  fail "$file: picks a theme colour itself"
done

# Rule 11: emphasis is Label's strong.
for file in $(grep -rlE 'font\.bold:' --include='*.qml' . | grep -v '^\./ui/Label\.qml$'); do
  fail "$file: sets bold itself; Label's strong does"
done

# Rule 11: sizes in characters or lines come from Metrics.
for file in $(grep -rlE '^\s*(TextMetrics|FontMetrics) \{' --include='*.qml' . | grep -v '^\./ui/Metrics\.qml$'); do
  fail "$file: measures the font itself"
done

# Rule 11: colours come from the theme.
for file in $(grep -rlE '"#[0-9a-fA-F]{6,8}"' --include='*.qml' . | grep -vE '^\./(Config\.qml|ui/)'); do
  fail "$file: a colour outside the theme"
done

# Rule 11: a date or a time is said through Clock alone, so every surface says it alike.
for file in $(grep -rlE 'Clock\.format\(|toLocale(Date|Time)String|dayName\(|monthName\(|Qt\.format(Date|Time)' --include='*.qml' . | grep -v '^\./services/Clock\.qml$'); do
  fail "$file: says a date or a time past Clock"
done

# Rule 6: one ellipsis, Words'.
for file in $(grep -rl '…' --include='*.qml' .); do
  fail "$file: an ellipsis other than Words.ellipsis"
done

# Rule 6: a word the surfaces share is Words', declared there.
for key in $(grep -rhoE '\bWords\.[a-zA-Z]+' --include='*.qml' . | sed 's/^Words\.//' | sort -u); do
  grep -qsE "(property|function) [a-z]+ $key\b|^  function $key\b" ui/Words.qml || fail "Words.$key, which ui/Words.qml does not declare"
done

# Rule 11: a glyph is Glyphs', declared there (a comment naming ui/Glyphs.qml is not a use).
for key in $(grep -rhoE '\bGlyphs\.[a-zA-Z]+' --include='*.qml' . | sed 's/^Glyphs\.//' | grep -vx qml | sort -u); do
  grep -qsE "(property [a-z]+|function) $key\b" ui/Glyphs.qml || fail "Glyphs.$key, which ui/Glyphs.qml does not declare"
done

# Rule 11: a legend's words come from Words.
for file in $(grep -rlE 'what: "' --include='*.qml' . | grep -v '^\./ui/Words\.qml$'); do
  fail "$file: a legend word outside Words"
done

# Rule 2: commands come from the config, run with sh -c, never named in QML.
for file in $(grep -rlE '(execDetached\(|command: |command = )\[ *"[^s"]|"sh", "-c", "' --include='*.qml' .); do
  fail "$file: runs a command named in QML"
done

# Rule 1: a built-in (status, list, state, action, header item) is one entry in its table in builtins/; widgets never test its name.
for file in $(grep -rlE 'case "|\b(list|status|state|modelData)\)? ?[!=]== "' --include='*.qml' widgets); do
  fail "$file: names a built-in outside its table"
done

# Qt 6.12's JavaScript: an optional call (`f?.()`) crashes the QML compiler at load, arrays have no flatMap, and Object no fromEntries.
for file in $(grep -rlE '\?\.\(|\.flatMap\(|Object\.fromEntries\(' --include='*.qml' --include='*.js' .); do
  fail "$file: an optional call, flatMap or Object.fromEntries, which Qt's JavaScript cannot run"
done

# QML takes escape for a global, so a method by that name fails the whole file at load.
for file in $(grep -rlE 'function (escape|unescape)\(' --include='*.qml' .); do
  fail "$file: a method named escape, which QML rejects"
done

# Plugins: Plugin holds the one source and IPC target; none declares its own.
for file in $(grep -rlE '^\s*(CommandState|CommandWatcher|CommandReader|FileView|IpcHandler) \{' --include='*.qml' plugins); do
  fail "$file: declares a source or IPC target past Plugin"
done

exit "$failed"
