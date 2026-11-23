import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The music status over mpv on a session bus of its own, its title an XML document as some radio streams send, split by music.titleMatch.
ShellRoot {
  Process {
    running: true
    command: ["mpv", "--no-config", "--really-quiet", "--ao=null", "--vo=null", "--loop=inf", "--force-media-title=<?xml version=\"1.0\"?><RDS><DB_LEAD_ARTIST_NAME> The Artist </DB_LEAD_ARTIST_NAME><DB_SONG_NAME>The Song</DB_SONG_NAME></RDS>", "av://lavfi:anullsrc"]
  }

  Suite {
    cases: [
      {
        name: "a title music.titleMatch matches gives its song and its artist, in either order",
        until: () => Music.title === "The Song" && Music.artist === "The Artist",
        timeout: 20000
      }
    ]
  }
}
