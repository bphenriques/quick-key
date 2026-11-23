pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

// The player Config.music.player names over MPRIS, else the one playing, else the last that played, else any. Playback position is left out: MPRIS only updates it when polled.
Singleton {
  readonly property bool present: internal.player !== null
  readonly property bool playing: internal.player?.isPlaying ?? false
  readonly property string title: internal.split?.[1]?.trim() ?? internal.title
  readonly property string artist: internal.split?.[2]?.trim() ?? internal.track?.trackArtist ?? ""
  readonly property bool repeat: (internal.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
  readonly property bool shuffle: internal.player?.shuffle ?? false
  // What the player takes: one that cannot ignores the call, so its action dims instead.
  readonly property bool canPlay: internal.player?.canTogglePlaying ?? false
  readonly property bool canSkip: !!(internal.player?.canGoNext || internal.player?.canGoPrevious)
  readonly property bool canRepeat: internal.player?.loopSupported ?? false
  readonly property bool canShuffle: internal.player?.shuffleSupported ?? false

  function togglePlaying() {
    internal.player?.togglePlaying();
  }

  function skip(forward) {
    if (forward) internal.player?.next();
    else internal.player?.previous();
  }

  function toggleRepeat() {
    if (internal.player) internal.player.loopState = repeat ? MprisLoopState.None : MprisLoopState.Playlist;
  }

  function toggleShuffle() {
    if (internal.player) internal.player.shuffle = !shuffle;
  }

  QtObject {
    id: internal

    readonly property var players: Mpris.players.values
    readonly property var playing: players.find(player => player.isPlaying) ?? null
    // The player that played last, so a pause then play resumes it rather than another.
    property var last: null
    onPlayingChanged: if (playing) last = playing
    readonly property var player: Config.music.player
      ? players.find(player => player.identity === Config.music.player) ?? null
      : playing ?? (players.includes(last) ? last : players[0] ?? null)
    // A stopped player keeps its last track.
    readonly property var track: player?.playbackState === MprisPlaybackState.Stopped ? null : player
    readonly property string title: track?.trackTitle ?? ""
    // Groups by position, as Qt's JavaScript never names them.
    readonly property var split: Config.music.titleMatch ? title.match(new RegExp(Config.music.titleMatch)) : null
  }
}
