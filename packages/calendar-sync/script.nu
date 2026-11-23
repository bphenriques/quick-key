# Syncs the calendars in a YAML file (calendars.yaml) into quick-key's events file (docs/src/calendar.md), via vdirsyncer and khal, and their tasks into its tasks file (docs/src/tasks.md), via todoman.

# ISO throughout, so khal's output is read without parsing dates.
const KHAL_LOCALE = "[locale]
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
timeformat = %H:%M
datetimeformat = %Y-%m-%dT%H:%M
longdatetimeformat = %Y-%m-%dT%H:%M"

def is-record [value]: nothing -> bool {
  ($value | describe) =~ '^record'
}

def is-string [value]: nothing -> bool {
  ($value | describe) == "string"
}

def valid-auth [auth]: nothing -> bool {
  (is-record $auth) and (is-string $auth.username?) and ((is-string $auth.password?) != (is-string $auth.passwordFile?))
}

def read-calendars [file: path]: nothing -> list {
  let name = $file | path basename
  let calendars = if ($file | path exists) { open --raw $file | from yaml | default [] } else { [] }
  if not (($calendars | describe) =~ '^(list|table)') {
    error make --unspanned { msg: $"($name): expected a list of calendars" }
  }
  # Each problem by entry and field, never the value: an address or a password is secret.
  let problems = $calendars | enumerate | each {|it|
    let c = if (is-record $it.item) { $it.item } else { {} }
    let auth = $c.basicAuth?
    [
      (if not ((is-string $c.name?) and $c.name =~ '^[A-Za-z0-9_-]+$') { "name must be letters, digits, - or _" })
      (if not (is-string $c.url?) { "url is missing" })
      (if not ((is-string $c.color?) and $c.color =~ '^#[0-9a-fA-F]{6}$') { "color must be quoted \"#rrggbb\"" })
      (if not ($auth == null or (valid-auth $auth)) { "basicAuth needs a username, and a password or a passwordFile" })
      (if not ($c.tasks? in [null true false]) { "tasks must be true or false" })
    ] | compact | each {|problem| $"entry ($it.index + 1): ($problem)" }
  } | flatten
  let repeated = $calendars | each {|c| if (is-record $c) { $c.name? } } | compact | uniq --repeated
  let problems = $problems | append ($repeated | each {|name| $"name '($name)' is used twice" })
  if ($problems | is-not-empty) {
    error make --unspanned { msg: ($problems | prepend $"($name):" | str join "\n  ") }
  }
  $calendars
}

# The remote's login, if any; a passwordFile is read at each sync, so it can be a secret managed elsewhere.
def vdirsyncer-auth [auth]: nothing -> string {
  if $auth == null { return "" }
  let password = if $auth.password? != null {
    $"password = ($auth.password | to json --raw)"
  } else {
    $"password.fetch = ([command cat ($auth.passwordFile | path expand)] | to json --raw)"
  }
  $"\nusername = ($auth.username | to json --raw)\n($password)"
}

# A calendar of tasks syncs both ways, so a tick here reaches its server, the server winning a conflict; the rest are only read.
def vdirsyncer-config [calendars: list, state: path]: nothing -> string {
  $calendars | each {|c| $"
[pair ($c.name)]
a = \"($c.name)_remote\"
b = \"($c.name)_local\"
collections = null(if $c.tasks? == true { (char nl) + 'conflict_resolution = "a wins"' } else { '' })

[storage ($c.name)_remote]
type = \"(if $c.tasks? == true { 'caldav' } else { 'http' })\"
url = ($c.url | to json --raw)(vdirsyncer-auth $c.basicAuth?)

[storage ($c.name)_local]
type = \"filesystem\"
path = ($state | path join vdirs $c.name | to json --raw)
fileext = \".ics\""
  } | prepend $"[general]\nstatus_path = ($state | path join status | to json --raw)" | str join "\n"
}

def khal-config [calendars: list, state: path]: nothing -> string {
  $calendars
  | each {|c| $"[[($c.name)]]\npath = ($state | path join vdirs $c.name)\ncolor = \"($c.color)\"\nreadonly = True" }
  | prepend "[calendars]"
  | append $"[sqlite]\npath = ($state | path join khal.db)"
  | append $KHAL_LOCALE
  | str join "\n"
}

# The first and last day the events cover, which the file says so the shell can tell a day without events from one past them.
def synced-range []: nothing -> record {
  { from: ((date now) - 62day | format date "%F"), to: ((date now) + 365day | format date "%F") }
}

# Each occurrence once: khal lists an event per day it spans, and --once would drop a repeating event's later occurrences.
def events [config: path, synced: record]: nothing -> list {
  # A day past the last, whether khal's end is a day it lists or not.
  let end = ($synced.to | into datetime) + 1day | format date "%F"
  let fields = [uid title start-date start-time end-date end-time all-day location calendar-color cancelled]
  ^khal -c $config list ...($fields | each {|f| [--json $f] } | flatten) $synced.from $end
  | lines
  | each { from json }
  | flatten
  # A cancelled meeting is not one to go to.
  | where cancelled == ""
  | uniq-by uid start-date start-time
  | each {|e|
    let all_day = $e.all-day == "True"
    let event = {
      uid: $e.uid
      title: $e.title
      start: (if $all_day { $e.start-date } else { $"($e.start-date)T($e.start-time)" })
      end: (if $all_day { $e.end-date } else { $"($e.end-date)T($e.end-time)" })
      allDay: $all_day
      color: $e.calendar-color
    }
    if ($e.location | is-empty) { $event } else { $event | insert location $e.location }
  }
}

def todoman-config [state: path]: nothing -> path {
  $state | path join todoman.py
}

# Only the calendars of tasks, linked into a folder of their own: todoman reads every calendar its glob finds.
def write-todoman-config [calendars: list, relative: path] {
  # Whole, as the links and todoman both read it from elsewhere.
  let state = $relative | path expand
  let lists = $state | path join tasks
  rm -rf $lists
  mkdir $lists
  for c in $calendars { ^ln -s ($state | path join vdirs $c.name) ($lists | path join $c.name) }
  [
    $"path = ($lists | path join '*' | to json --raw)"
    $"cache_path = ($state | path join todoman.db | to json --raw)"
    $"default_list = ($calendars | first | get name | to json --raw)"
    'date_format = "%Y-%m-%d"'
    'time_format = "%H:%M"'
    # A task added here has no due date, where todoman's default is a day later.
    'default_due = 0'
  ] | str join "\n" | save -f (todoman-config $state)
}

# todoman gives seconds since the epoch, a day's own as midnight; coreutils, as nushell's local time keeps today's offset all year.
def local-time [seconds: int]: nothing -> string {
  let time = ^date --date $"@($seconds)" "+%Y-%m-%dT%H:%M"
  if ($time | str ends-with "T00:00") { $time | str substring 0..9 } else { $time }
}

# Open tasks, and those done in the last 14 days, so a tick stays to be undone and the done ones can be shown.
def shown [state: path]: nothing -> list {
  let since = (date now) - 14day | format date "%Y-%m-%d"
  ^todo --config (todoman-config $state) --porcelain list --status ANY
  | from json
  | where {|t| not $t.completed or ($t.completed_at != null and (local-time $t.completed_at) >= $since) }
}

def write-tasks [calendars: list, state: path, --synced, --error: string] {
  let colors = $calendars | reduce --fold {} {|c, colors| $colors | insert $c.name $c.color }
  let tasks = shown $state | each {|t| {
    id: ($t.id | into string)
    title: $t.summary
    due: (if $t.due == null { null } else { local-time $t.due })
    done: $t.completed
    completed: (if $t.completed_at == null { null } else { local-time $t.completed_at })
    list: $t.list
    priority: ($t.priority | default 0)
    color: ($colors | get --optional $t.list | default "")
  } }
  let file = $state | path join tasks.json
  # `updated` is when the lists last synced and `error` the last sync's, so a tick or a failed sync never makes stale tasks look fresh.
  let previous = try { open $file } catch { {} }
  let updated = if $synced { date now | format date "%Y-%m-%dT%H:%M" } else { $previous.updated? }
  let error = if $synced { $error } else { $error | default $previous.error? }
  let content = { updated: $updated, error: $error, tasks: $tasks }
  # One line, as quick-key reads a plugin's file.
  $content | reject ...($content | columns | where {|c| ($content | get $c) == null }) | to json --raw | save -f $"($file).tmp"
  mv -f $"($file).tmp" $file
}

# vdirsyncer's first error line, its addresses left out: one can be secret.
def reason [stderr: string]: nothing -> string {
  let errors = $stderr | lines | where {|line| $line =~ '(?i)error' }
  if ($errors | is-empty) { return "could not sync" }
  $errors | first | str replace --all --regex 'https?://\S+' '<address>' | str replace --regex '^.*?error:\s*' '' | str trim
}

# Replaced whole, so the shell never reads half a file.
def write-events [file: path, content: record] {
  $content | to json | save -f $"($file).tmp"
  mv -f $"($file).tmp" $file
}

def main [calendars_file: path, events_file: path] {
  # It holds the calendars' addresses and logins.
  let state = $events_file | path dirname
  mkdir $state
  ^chmod 700 $state
  let previous = if ($events_file | path exists) { try { open $events_file } catch { {} } } else { {} }
  let kept = { updated: ($previous.updated? | default (date now | format date "%Y-%m-%dT%H:%M")), synced: $previous.synced?, events: ($previous.events? | default []) }

  let calendars = try { read-calendars $calendars_file } catch {|e|
    write-events $events_file ($kept | insert error $e.msg)
    error make --unspanned { msg: $e.msg }
  }
  if ($calendars | is-empty) {
    print $"No calendars in ($calendars_file), so no events."
    rm -rf ($state | path join tasks) ($state | path join tasks.json)
    rm -f $events_file
    return
  }
  write-events $events_file ($kept | insert syncing true)

  for c in $calendars { mkdir ($state | path join vdirs $c.name) }
  let vdirsyncer = $state | path join vdirsyncer.conf
  let khal = $state | path join khal.conf
  vdirsyncer-config $calendars $state | save -f $vdirsyncer
  khal-config $calendars $state | save -f $khal

  # One at a time, so a failure names its calendar and keeps its last events; discover is a no-op once the pairs are known.
  let discovered = ^vdirsyncer -c $vdirsyncer discover | complete
  let failures = if $discovered.exit_code != 0 {
    $calendars | each {|c| { name: $c.name, reason: (reason $discovered.stderr) } }
  } else {
    $calendars | each {|c|
      let run = ^vdirsyncer -c $vdirsyncer sync $c.name | complete
      if $run.exit_code != 0 { { name: $c.name, reason: (reason $run.stderr) } }
    } | compact
  }
  let read = try { let synced = synced-range; { synced: $synced, events: (events $khal $synced) } } catch { $kept }
  let now = date now | format date "%Y-%m-%dT%H:%M"

  let lists = $calendars | where {|c| $c.tasks? == true }
  if ($lists | is-empty) {
    rm -rf ($state | path join tasks) ($state | path join tasks.json)
  } else {
    let failed = $failures | where name in $lists.name
    # Only a sync that fetched a list makes the tasks newer, as the events.
    let synced = if ($failed | length) < ($lists | length) { [--synced] } else { [] }
    locked $events_file tasks $calendars_file $events_file ...$synced ...(if ($failed | is-empty) { [] } else { [--error (failure $failed)] })
  }

  if ($failures | is-empty) {
    write-events $events_file { updated: $now, synced: $read.synced, events: $read.events }
  } else {
    let error = failure $failures
    # Only a sync that fetched something makes the events newer.
    let updated = if ($failures | length) == ($calendars | length) { $kept.updated } else { $now }
    write-events $events_file { updated: $updated, synced: $read.synced, events: $read.events, error: $error }
    exit 1
  }
}

def failure [failures: list]: nothing -> string {
  $failures | group-by reason | items {|reason, failed| $"($failed.name | str join ', '): ($reason)" } | str join "; "
}

def task-lists [calendars_file: path]: nothing -> list {
  read-calendars $calendars_file | where {|c| $c.tasks? == true }
}

# This script's subcommand, under the state's lock: a tick and a sync's rewrite of the tasks file never interleave, and neither waits on the network.
def locked [events_file: path, ...args] {
  ^flock ($events_file | path dirname | path join lock) nu $env.CURRENT_FILE ...$args
}

# Writes the tasks file from what is already synced, without syncing: `--synced` after a sync that fetched the lists, `--error` after one that failed.
def "main tasks" [calendars_file: path, events_file: path, --synced, --error: string] {
  let state = $events_file | path dirname
  let lists = task-lists $calendars_file
  write-todoman-config $lists $state
  write-tasks $lists $state --synced=$synced --error=$error
}

# Ticks a task off by its id and title in the tasks file, and writes that file again; the next sync takes it to its server.
def "main done" [calendars_file: path, events_file: path, id: int, title: string] {
  locked $events_file tick done $calendars_file $events_file $id $title
}

def "main reopen" [calendars_file: path, events_file: path, id: int, title: string] {
  locked $events_file tick reopen $calendars_file $events_file $id $title
}

# What done and reopen run under the lock. todoman numbers tasks anew as their files change, an id landing on another alike, so only the one task shown with that title, open for done and done for reopen, is acted on.
def "main tick" [how: string, calendars_file: path, events_file: path, id: int, title: string] {
  let state = $events_file | path dirname
  let config = todoman-config $state
  let alike = shown $state | where {|t| $t.summary == $title and $t.completed == ($how == "reopen") }
  if $id not-in $alike.id { error make --unspanned { msg: "tasks changed, try again" } }
  if ($alike | length) > 1 { error make --unspanned { msg: $"two tasks are called ($title): tick it in your calendar app" } }
  if $how == "done" and $alike.0.recurring {
    # todoman makes a repeating task's next one.
    let run = ^todo --config $config done $id | complete
    if $run.exit_code != 0 { error make { msg: ($run.stderr | str trim) } }
  } else {
    # Edited in place, as todoman writes a task anew from its cache, losing what it does not read: the lines a tick sets go with those they fold onto (RFC 5545), only a task's in a CalDAV file (RFC 4791), and come back after BEGIN:VTODO in its line endings.
    let file = ^todo --config $config path $id | str trim
    let set = if $how == "done" { [STATUS:COMPLETED $"COMPLETED:(date now | date to-timezone UTC | format date '%Y%m%dT%H%M%SZ')" PERCENT-COMPLETE:100] } else { [STATUS:NEEDS-ACTION] }
    open --raw $file
    | str replace --all --regex '(?m)^(STATUS|COMPLETED|PERCENT-COMPLETE)[:;].*\n([ \t].*\n)*' ''
    | str replace --regex '(?m)^BEGIN:VTODO(\r?)\n' ($set | prepend BEGIN:VTODO | each { $in + '${1}' + "\n" } | str join)
    | save -f $"($file).tmp"
    mv -f $"($file).tmp" $file
  }
  write-tasks (task-lists $calendars_file) $state
}

# Adds a task to the first list by its title, and writes the tasks file again; the next sync takes it to its server.
def "main add" [calendars_file: path, events_file: path, title: string] {
  locked $events_file create $calendars_file $events_file $title
}

# What add runs under the lock; todoman's default list is the first.
def "main create" [calendars_file: path, events_file: path, title: string] {
  let state = $events_file | path dirname
  let run = ^todo --config (todoman-config $state) new -- $title | complete
  if $run.exit_code != 0 { error make { msg: ($run.stderr | str trim) } }
  write-tasks (task-lists $calendars_file) $state
}
